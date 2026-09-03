// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceOracleAdapter} from "./interfaces/IPriceOracleAdapter.sol";
import {IPancakeV2Pair} from "./interfaces/IPancakeV2Pair.sol";

/// @notice Permissionless Pancake V2 cumulative-price oracle with liquidity,
/// observation-window, staleness, and reference-price-deviation protections.
contract PancakeV2TwapOracleAdapter is IPriceOracleAdapter {
    error ZeroAddress();
    error InvalidConfiguration();
    error UnsupportedToken(address token);
    error InsufficientLiquidity(uint256 reserve0, uint256 reserve1);
    error ObservationWindowNotElapsed(uint256 elapsed, uint256 required);
    error TwapPriceDeviation(uint256 twapPrice, uint256 referencePrice);

    uint256 public constant Q112 = 2 ** 112;
    uint16 public constant BPS_DENOMINATOR = 10_000;

    IPancakeV2Pair public immutable pair;
    IERC20Metadata public immutable asset;
    IERC20Metadata public immutable quote;
    IPriceOracleAdapter public immutable referenceOracle;
    bool public immutable assetIsToken0;
    uint32 public immutable minObservationWindow;
    uint32 public immutable maxStaleness;
    uint112 public immutable minReserve0;
    uint112 public immutable minReserve1;
    uint16 public immutable maxDeviationBps;

    uint256 public observationCumulative;
    uint32 public observationTimestamp;
    uint256 public priceE18;
    uint256 public updatedAt;

    event ObservationRecorded(uint256 cumulativePrice, uint32 timestamp);
    event TwapUpdated(uint256 priceE18, uint256 updatedAt, uint256 elapsed);

    constructor(
        IPancakeV2Pair pair_,
        IERC20Metadata asset_,
        IERC20Metadata quote_,
        IPriceOracleAdapter referenceOracle_,
        uint32 minObservationWindow_,
        uint32 maxStaleness_,
        uint112 minReserve0_,
        uint112 minReserve1_,
        uint16 maxDeviationBps_
    ) {
        if (
            address(pair_) == address(0) || address(asset_) == address(0) || address(quote_) == address(0)
                || address(referenceOracle_) == address(0)
        ) revert ZeroAddress();
        if (
            minObservationWindow_ == 0 || maxStaleness_ < minObservationWindow_ || minReserve0_ == 0 || minReserve1_ == 0
                || maxDeviationBps_ >= BPS_DENOMINATOR
        ) revert InvalidConfiguration();
        bool isToken0 = pair_.token0() == address(asset_) && pair_.token1() == address(quote_);
        bool isToken1 = pair_.token1() == address(asset_) && pair_.token0() == address(quote_);
        if (!isToken0 && !isToken1) revert InvalidConfiguration();
        pair = pair_;
        asset = asset_;
        quote = quote_;
        referenceOracle = referenceOracle_;
        assetIsToken0 = isToken0;
        minObservationWindow = minObservationWindow_;
        maxStaleness = maxStaleness_;
        minReserve0 = minReserve0_;
        minReserve1 = minReserve1_;
        maxDeviationBps = maxDeviationBps_;
    }

    function update() external returns (uint256 nextPriceE18) {
        (uint256 cumulative, uint32 timestamp, uint112 reserve0, uint112 reserve1) = _currentCumulativePrice();
        if (reserve0 < minReserve0 || reserve1 < minReserve1) revert InsufficientLiquidity(reserve0, reserve1);
        if (observationTimestamp == 0) {
            observationCumulative = cumulative;
            observationTimestamp = timestamp;
            emit ObservationRecorded(cumulative, timestamp);
            return 0;
        }
        uint32 elapsed = timestamp - observationTimestamp;
        if (elapsed < minObservationWindow) revert ObservationWindowNotElapsed(elapsed, minObservationWindow);
        uint256 averagePriceX112 = (cumulative - observationCumulative) / elapsed;
        uint256 quoteAmount = averagePriceX112 * (10 ** asset.decimals()) / Q112;
        nextPriceE18 = quoteAmount * _referencePrice(address(quote)) / (10 ** quote.decimals());
        uint256 referencePrice = _referencePrice(address(asset));
        uint256 deviation = nextPriceE18 > referencePrice ? nextPriceE18 - referencePrice : referencePrice - nextPriceE18;
        if (deviation * BPS_DENOMINATOR > referencePrice * maxDeviationBps) {
            revert TwapPriceDeviation(nextPriceE18, referencePrice);
        }
        observationCumulative = cumulative;
        observationTimestamp = timestamp;
        priceE18 = nextPriceE18;
        updatedAt = block.timestamp;
        emit TwapUpdated(nextPriceE18, updatedAt, elapsed);
    }

    function getPrice(address token) external view returns (uint256, uint256) {
        if (token != address(asset)) revert UnsupportedToken(token);
        return (priceE18, updatedAt);
    }

    function isPriceValid(address token) external view returns (bool) {
        return token == address(asset) && priceE18 != 0 && updatedAt != 0 && block.timestamp - updatedAt <= maxStaleness;
    }

    function _referencePrice(address token) private view returns (uint256 value) {
        if (!referenceOracle.isPriceValid(token)) revert UnsupportedToken(token);
        (value,) = referenceOracle.getPrice(token);
        if (value == 0) revert UnsupportedToken(token);
    }

    function _currentCumulativePrice() private view returns (uint256 cumulative, uint32 timestamp, uint112 reserve0, uint112 reserve1) {
        uint32 pairTimestamp;
        (reserve0, reserve1, pairTimestamp) = pair.getReserves();
        timestamp = uint32(block.timestamp);
        cumulative = assetIsToken0 ? pair.price0CumulativeLast() : pair.price1CumulativeLast();
        if (pairTimestamp != timestamp && reserve0 != 0 && reserve1 != 0) {
            uint32 elapsed = timestamp - pairTimestamp;
            uint256 currentPriceX112 = assetIsToken0 ? uint256(reserve1) * Q112 / reserve0 : uint256(reserve0) * Q112 / reserve1;
            cumulative += currentPriceX112 * elapsed;
        }
    }
}

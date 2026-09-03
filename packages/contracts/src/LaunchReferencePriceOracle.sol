// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPriceOracleAdapter } from "./interfaces/IPriceOracleAdapter.sol";

/// @notice Timelocked initial-price adapter for assets without a mature external oracle.
contract LaunchReferencePriceOracle is Ownable2Step, IPriceOracleAdapter {
    error ZeroAddress();
    error InvalidPriceWindow();
    error ActivationNotReady(uint64 activationTime, uint256 currentTime);
    error NoPendingPrice(address asset);
    error NoActivePrice(address asset);

    struct ReferencePrice {
        address quote;
        uint192 priceE18;
        uint64 activationTime;
        uint64 expiryTime;
        uint16 maxDeviationBps;
    }

    uint64 public immutable minimumDelay;
    mapping(address => ReferencePrice) public pendingPrice;
    mapping(address => ReferencePrice) public activePrice;

    event ReferencePriceProposed(
        address indexed asset,
        address indexed quote,
        uint256 priceE18,
        uint64 activationTime,
        uint64 expiryTime,
        uint16 maxDeviationBps
    );
    event ReferencePriceActivated(
        address indexed asset, address indexed quote, uint256 priceE18, uint64 expiryTime
    );

    constructor(uint64 minimumDelay_, address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        minimumDelay = minimumDelay_;
    }

    function proposePrice(
        address asset,
        address quote,
        uint256 priceE18,
        uint64 activationTime,
        uint64 expiryTime,
        uint16 maxDeviationBps
    ) external onlyOwner {
        if (asset == address(0) || quote == address(0)) revert ZeroAddress();
        if (
            priceE18 == 0 || priceE18 > type(uint192).max
                || activationTime < block.timestamp + minimumDelay || expiryTime <= activationTime
                || maxDeviationBps > 10_000
        ) revert InvalidPriceWindow();
        pendingPrice[asset] =
            ReferencePrice(quote, uint192(priceE18), activationTime, expiryTime, maxDeviationBps);
        emit ReferencePriceProposed(
            asset, quote, priceE18, activationTime, expiryTime, maxDeviationBps
        );
    }

    function activatePrice(address asset) external {
        ReferencePrice memory price = pendingPrice[asset];
        if (price.activationTime == 0) revert NoPendingPrice(asset);
        if (block.timestamp < price.activationTime) {
            revert ActivationNotReady(price.activationTime, block.timestamp);
        }
        activePrice[asset] = price;
        delete pendingPrice[asset];
        emit ReferencePriceActivated(asset, price.quote, price.priceE18, price.expiryTime);
    }

    function getPrice(address token) external view returns (uint256 priceE18, uint256 updatedAt) {
        ReferencePrice memory price = activePrice[token];
        if (price.activationTime == 0 || block.timestamp > price.expiryTime) {
            revert NoActivePrice(token);
        }
        return (price.priceE18, price.activationTime);
    }

    function isPriceValid(address token) external view returns (bool) {
        ReferencePrice memory price = activePrice[token];
        return price.activationTime != 0 && block.timestamp >= price.activationTime
            && block.timestamp <= price.expiryTime;
    }
}

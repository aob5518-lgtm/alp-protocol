// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AssetRegistry} from "./AssetRegistry.sol";
import {IPriceOracleAdapter} from "./interfaces/IPriceOracleAdapter.sol";
import {ICompensationStrategy} from "./interfaces/ICompensationStrategy.sol";
import {IPartnerAssetVault} from "./interfaces/IPartnerAssetVault.sol";
import {IGlobalComputeEngine} from "./interfaces/IGlobalComputeEngine.sol";
import {ITierEngine} from "./interfaces/ITierEngine.sol";
import {IDifferentialRewardEngine} from "./interfaces/IDifferentialRewardEngine.sol";
import {ILiquidityManager} from "./interfaces/ILiquidityManager.sol";
import {SponsorRegistry} from "./SponsorRegistry.sol";
import {ReferralRewardEngine} from "./ReferralRewardEngine.sol";

/// @notice Immutable per-asset pool. The compensation method and compute weight cannot change after deployment.
contract LaunchPool is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidAddress();
    error AssetUnavailable(uint256 assetId);
    error PoolNotLive(uint64 launchTime);
    error InvalidPositionValue();
    error OraclePriceInvalid();
    error PartnerTokenSlippage(uint256 required, uint256 maximum);
    error InvalidWeight();

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant HALF_BPS = 5_000;
    uint256 public constant WAD = 1e18;

    enum PositionStatus { ACTIVE, PAUSED, CLOSED }

    struct Position {
        address user;
        uint256 partnerTokenAmount;
        uint256 partnerTokenValueUSDT;
        uint256 usdtAmount;
        uint256 totalValueUSDT;
        uint256 baseCompute;
        uint256 timeCompensationFactor;
        uint256 effectiveCompute;
        uint64 createdAt;
        uint64 createdEpoch;
        PositionStatus status;
    }

    AssetRegistry public immutable registry;
    uint256 public immutable assetId;
    IERC20Metadata public immutable partnerToken;
    IERC20Metadata public immutable usdt;
    IPriceOracleAdapter public immutable oracle;
    IPartnerAssetVault public immutable vault;
    IGlobalComputeEngine public immutable computeEngine;
    ICompensationStrategy public immutable compensationStrategy;
    SponsorRegistry public immutable sponsorRegistry;
    ReferralRewardEngine public immutable referralRewardEngine;
    ITierEngine public immutable tierEngine;
    IDifferentialRewardEngine public immutable differentialRewardEngine;
    address public immutable rewardTreasury;
    ILiquidityManager public immutable liquidityManager;
    uint64 public immutable launchTime;
    uint64 public immutable launchEpoch;
    uint256 public immutable computeWeightE18;
    uint8 public immutable partnerTokenDecimals;
    uint8 public immutable usdtDecimals;

    uint256 public nextPositionId = 1;
    uint256 public activePositionCount;
    mapping(uint256 => Position) public positions;

    event PositionCreated(
        uint256 indexed positionId,
        uint256 indexed globalPositionId,
        address indexed user,
        uint256 partnerTokenAmount,
        uint256 usdtAmount,
        uint256 totalValueUSDT,
        uint256 effectiveCompute,
        uint256 timeCompensationFactor
    );
    event PoolPaused(address indexed by);
    event PoolUnpaused(address indexed by);

    constructor(
        address initialOwner,
        AssetRegistry registry_,
        uint256 assetId_,
        IERC20Metadata usdt_,
        IGlobalComputeEngine computeEngine_,
        ICompensationStrategy compensationStrategy_,
        SponsorRegistry sponsorRegistry_,
        ReferralRewardEngine referralRewardEngine_,
        ITierEngine tierEngine_,
        IDifferentialRewardEngine differentialRewardEngine_,
        address rewardTreasury_,
        ILiquidityManager liquidityManager_,
        uint256 computeWeightE18_
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) || address(registry_) == address(0) || address(usdt_) == address(0)
                || address(computeEngine_) == address(0) || address(compensationStrategy_) == address(0)
                || address(sponsorRegistry_) == address(0) || address(referralRewardEngine_) == address(0)
                || address(tierEngine_) == address(0)
                || address(differentialRewardEngine_) == address(0)
                || rewardTreasury_ == address(0) || address(liquidityManager_) == address(0)
        ) revert InvalidAddress();
        if (computeWeightE18_ == 0 || computeWeightE18_ > 10 * WAD) revert InvalidWeight();
        AssetRegistry.AssetConfig memory assetConfig = registry_.asset(assetId_);
        if (assetConfig.launchStatus != AssetRegistry.LaunchStatus.ACTIVE) revert AssetUnavailable(assetId_);
        registry = registry_;
        assetId = assetId_;
        partnerToken = IERC20Metadata(assetConfig.token);
        oracle = IPriceOracleAdapter(assetConfig.oracle);
        vault = IPartnerAssetVault(assetConfig.vault);
        usdt = usdt_;
        computeEngine = computeEngine_;
        compensationStrategy = compensationStrategy_;
        sponsorRegistry = sponsorRegistry_;
        referralRewardEngine = referralRewardEngine_;
        tierEngine = tierEngine_;
        differentialRewardEngine = differentialRewardEngine_;
        rewardTreasury = rewardTreasury_;
        liquidityManager = liquidityManager_;
        launchTime = assetConfig.launchTime;
        launchEpoch = uint64(block.timestamp / 1 days);
        computeWeightE18 = computeWeightE18_;
        partnerTokenDecimals = partnerToken.decimals();
        usdtDecimals = usdt_.decimals();
    }

    function quote(uint256 totalValueUSDT) public view returns (uint256 partnerAmount, uint256 usdtAmount, uint256 priceE18) {
        if (totalValueUSDT == 0) revert InvalidPositionValue();
        (priceE18,) = oracle.getPrice(address(partnerToken));
        if (priceE18 == 0 || !oracle.isPriceValid(address(partnerToken))) revert OraclePriceInvalid();
        uint256 halfValue = totalValueUSDT * HALF_BPS / BPS_DENOMINATOR;
        partnerAmount = halfValue * (10 ** partnerTokenDecimals) / priceE18;
        usdtAmount = halfValue * (10 ** usdtDecimals) / WAD;
    }

    /// @param totalValueUSDT USD value in 1e18 units.
    /// @param maxPartnerTokenAmount Maximum partner asset amount accepted after an oracle update.
    function createPosition(uint256 totalValueUSDT, uint256 maxPartnerTokenAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 positionId)
    {
        if (block.timestamp < launchTime) revert PoolNotLive(launchTime);
        if (!registry.canCreatePosition(assetId)) revert AssetUnavailable(assetId);
        (uint256 partnerAmount, uint256 usdtAmount,) = quote(totalValueUSDT);
        if (partnerAmount > maxPartnerTokenAmount) revert PartnerTokenSlippage(partnerAmount, maxPartnerTokenAmount);
        uint256 rewardTreasuryAmount = usdtAmount * HALF_BPS / BPS_DENOMINATOR;
        uint256 liquidityAmount = usdtAmount - rewardTreasuryAmount;
        uint256 elapsedDays = (block.timestamp - launchTime) / 1 days;
        uint256 factorE18 = compensationStrategy.factor(elapsedDays);
        uint256 effectiveCompute = totalValueUSDT * factorE18 / WAD * computeWeightE18 / WAD;
        if (effectiveCompute == 0) revert InvalidPositionValue();

        positionId = nextPositionId++;
        uint256 globalPositionId = globalPositionKey(positionId);
        vault.deposit(msg.sender, partnerAmount, assetId, globalPositionId);
        IERC20(address(usdt)).safeTransferFrom(msg.sender, rewardTreasury, rewardTreasuryAmount);
        IERC20(address(usdt)).safeTransferFrom(msg.sender, address(liquidityManager), liquidityAmount);
        liquidityManager.receiveLiquidityAllocation(assetId, liquidityAmount);
        positions[positionId] = Position({
            user: msg.sender,
            partnerTokenAmount: partnerAmount,
            partnerTokenValueUSDT: totalValueUSDT * HALF_BPS / BPS_DENOMINATOR,
            usdtAmount: usdtAmount,
            totalValueUSDT: totalValueUSDT,
            baseCompute: totalValueUSDT,
            timeCompensationFactor: factorE18,
            effectiveCompute: effectiveCompute,
            createdAt: uint64(block.timestamp),
            createdEpoch: uint64(block.timestamp / 1 days),
            status: PositionStatus.ACTIVE
        });
        activePositionCount++;
        computeEngine.addPosition(globalPositionId, msg.sender, effectiveCompute);
        sponsorRegistry.activateContributor(msg.sender);
        referralRewardEngine.distribute(globalPositionId, msg.sender, usdtAmount);
        tierEngine.recordPosition(msg.sender, usdtAmount, totalValueUSDT);
        differentialRewardEngine.distribute(globalPositionId, msg.sender, usdtAmount);
        emit PositionCreated(
            positionId, globalPositionId, msg.sender, partnerAmount, usdtAmount, totalValueUSDT, effectiveCompute, factorE18
        );
    }

    function globalPositionKey(uint256 positionId) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(address(this), positionId)));
    }

    function pause() external onlyOwner {
        _pause();
        emit PoolPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit PoolUnpaused(msg.sender);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ILiquidityALPSource } from "./interfaces/ILiquidityALPSource.sol";
import { IPancakeV2Router } from "./interfaces/IPancakeV2Router.sol";
import { PermanentLiquidityLocker } from "./PermanentLiquidityLocker.sol";
import { IProtocolController } from "./interfaces/IProtocolController.sol";
import { IPancakeV2Pair } from "./interfaces/IPancakeV2Pair.sol";

/// @notice Adds ALP/USDT liquidity using pre-existing ALP and permanently locks LP.
/// @dev It contains no minting, no LP withdrawal, and no arbitrary treasury withdrawal.
contract LiquidityManager is AccessControl {
    using SafeERC20 for IERC20;

    uint16 public constant BPS_DENOMINATOR = 10_000;

    error ZeroAddress();
    error InvalidAmount();
    error RouterNotConfigured();
    error PairNotConfigured();
    error ReserveDeviation();

    bytes32 public constant LIQUIDITY_OPERATOR_ROLE = keccak256("LIQUIDITY_OPERATOR_ROLE");
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    bytes32 public constant POOL_FACTORY_ROLE = keccak256("POOL_FACTORY_ROLE");

    IERC20 public immutable alp;
    IERC20 public immutable usdt;
    ILiquidityALPSource public immutable liquidityALPSource;
    IPancakeV2Router public router;
    PermanentLiquidityLocker public immutable locker;
    IProtocolController public immutable protocolController;
    address public mainPair;
    uint16 public maxReserveDeviationBps = 500;
    uint256 public maxAlpPerSettlement = 10_000_000 ether;
    uint256 public maxUsdtPerSettlement = 1_000_000 ether;
    uint256 public minimumLiquidityBatch = 10_000 ether;
    uint64 public maxPendingDuration = 7 days;

    mapping(uint256 => uint256) public pendingUsdtByAsset;
    mapping(uint256 => uint64) public pendingSinceByAsset;

    event RouterConfigured(address indexed router);
    event MainPairConfigured(address indexed pair);
    event LiquidityAllocationReceived(
        uint256 indexed assetId, uint256 amount, uint256 pendingAmount
    );
    event LiquiditySettled(
        uint256 indexed assetId,
        uint256 requestedUsdt,
        uint256 usedUsdt,
        uint256 providedAlp,
        uint256 usedAlp,
        uint256 returnedAlp,
        uint256 lpAmount,
        address indexed pair
    );

    constructor(
        IERC20 alp_,
        IERC20 usdt_,
        ILiquidityALPSource liquidityALPSource_,
        PermanentLiquidityLocker locker_,
        IProtocolController protocolController_,
        address admin
    ) {
        if (
            address(alp_) == address(0) || address(usdt_) == address(0)
                || address(liquidityALPSource_) == address(0) || address(locker_) == address(0)
                || admin == address(0) || address(protocolController_) == address(0)
        ) revert ZeroAddress();
        alp = alp_;
        usdt = usdt_;
        liquidityALPSource = liquidityALPSource_;
        locker = locker_;
        protocolController = protocolController_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function configureRouter(IPancakeV2Router router_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(router_) == address(0)) revert ZeroAddress();
        router = router_;
        emit RouterConfigured(address(router_));
    }

    function configureMainPair(address pair) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (pair == address(0)) revert ZeroAddress();
        if (mainPair != address(0)) revert PairNotConfigured();
        mainPair = pair;
        emit MainPairConfigured(pair);
    }

    function registerPool(address pool) external onlyRole(POOL_FACTORY_ROLE) {
        if (pool == address(0)) revert ZeroAddress();
        _grantRole(POOL_ROLE, pool);
    }

    function receiveLiquidityAllocation(uint256 assetId, uint256 amount)
        external
        onlyRole(POOL_ROLE)
    {
        if (amount == 0) revert InvalidAmount();
        pendingUsdtByAsset[assetId] += amount;
        if (pendingSinceByAsset[assetId] == 0) {
            pendingSinceByAsset[assetId] = uint64(block.timestamp);
        }
        emit LiquidityAllocationReceived(assetId, amount, pendingUsdtByAsset[assetId]);
    }

    function configureSettlementLimits(
        uint16 maxReserveDeviationBps_,
        uint256 maxAlpPerSettlement_,
        uint256 maxUsdtPerSettlement_,
        uint256 minimumLiquidityBatch_,
        uint64 maxPendingDuration_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            maxReserveDeviationBps_ > BPS_DENOMINATOR || maxAlpPerSettlement_ == 0
                || maxUsdtPerSettlement_ == 0 || maxPendingDuration_ == 0
        ) revert InvalidAmount();
        maxReserveDeviationBps = maxReserveDeviationBps_;
        maxAlpPerSettlement = maxAlpPerSettlement_;
        maxUsdtPerSettlement = maxUsdtPerSettlement_;
        minimumLiquidityBatch = minimumLiquidityBatch_;
        maxPendingDuration = maxPendingDuration_;
    }

    function settleLiquidity(
        uint256 assetId,
        uint256 usdtAmount,
        uint256 minAlpAmount,
        uint256 minUsdtAmount,
        uint256 deadline
    ) external returns (uint256 usedAlp, uint256 usedUsdt, uint256 lpAmount) {
        protocolController.requireOperational();
        if (address(router) == address(0)) revert RouterNotConfigured();
        if (mainPair == address(0)) revert PairNotConfigured();
        bool keeperAllowed = pendingUsdtByAsset[assetId] >= minimumLiquidityBatch
            || (pendingSinceByAsset[assetId] != 0
                && block.timestamp >= pendingSinceByAsset[assetId] + maxPendingDuration);
        if (!hasRole(LIQUIDITY_OPERATOR_ROLE, msg.sender) && !keeperAllowed) {
            revert AccessControlUnauthorizedAccount(msg.sender, LIQUIDITY_OPERATOR_ROLE);
        }
        if (
            usdtAmount == 0 || usdtAmount > pendingUsdtByAsset[assetId]
                || usdtAmount > maxUsdtPerSettlement
        ) {
            revert InvalidAmount();
        }
        (uint256 reserveAlp, uint256 reserveUsdt) = _reserves();
        uint256 alpAmount = usdtAmount * reserveAlp / reserveUsdt;
        if (alpAmount == 0 || alpAmount > maxAlpPerSettlement) revert ReserveDeviation();
        bytes32 operation =
            keccak256(abi.encodePacked("LIQUIDITY", assetId, block.number, alpAmount, usdtAmount));
        liquidityALPSource.provideLiquidityALP(address(this), alpAmount, operation);
        alp.forceApprove(address(router), alpAmount);
        usdt.forceApprove(address(router), usdtAmount);
        (usedAlp, usedUsdt, lpAmount) = router.addLiquidity(
            address(alp),
            address(usdt),
            alpAmount,
            usdtAmount,
            minAlpAmount,
            minUsdtAmount,
            address(locker),
            deadline
        );
        alp.forceApprove(address(router), 0);
        usdt.forceApprove(address(router), 0);
        pendingUsdtByAsset[assetId] -= usedUsdt;
        if (pendingUsdtByAsset[assetId] == 0) pendingSinceByAsset[assetId] = 0;
        uint256 returnedAlp = alpAmount - usedAlp;
        if (returnedAlp != 0) {
            alp.forceApprove(address(liquidityALPSource), returnedAlp);
            liquidityALPSource.returnUnusedLiquidityALP(returnedAlp);
            alp.forceApprove(address(liquidityALPSource), 0);
        }
        locker.recordLock(mainPair, lpAmount, operation);
        emit LiquiditySettled(
            assetId, usdtAmount, usedUsdt, alpAmount, usedAlp, returnedAlp, lpAmount, mainPair
        );
    }

    function _reserves() private view returns (uint256 reserveAlp, uint256 reserveUsdt) {
        IPancakeV2Pair pair = IPancakeV2Pair(mainPair);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        if (pair.token0() == address(alp) && pair.token1() == address(usdt)) {
            return (reserve0, reserve1);
        }
        if (pair.token1() == address(alp) && pair.token0() == address(usdt)) {
            return (reserve1, reserve0);
        }
        revert PairNotConfigured();
    }
}

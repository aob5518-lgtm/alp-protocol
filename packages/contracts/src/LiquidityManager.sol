// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ILiquidityALPSource} from "./interfaces/ILiquidityALPSource.sol";
import {IPancakeV2Router} from "./interfaces/IPancakeV2Router.sol";
import {PermanentLiquidityLocker} from "./PermanentLiquidityLocker.sol";
import {IProtocolController} from "./interfaces/IProtocolController.sol";

/// @notice Adds ALP/USDT liquidity using pre-existing ALP and permanently locks LP.
/// @dev It contains no minting, no LP withdrawal, and no arbitrary treasury withdrawal.
contract LiquidityManager is AccessControl {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error InvalidAmount();
    error RouterNotConfigured();
    error PairNotConfigured();

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

    mapping(uint256 => uint256) public pendingUsdtByAsset;

    event RouterConfigured(address indexed router);
    event MainPairConfigured(address indexed pair);
    event LiquidityAllocationReceived(uint256 indexed assetId, uint256 amount, uint256 pendingAmount);
    event LiquidityAdded(
        uint256 indexed assetId,
        uint256 alpAmount,
        uint256 usdtAmount,
        uint256 lpAmount,
        address indexed pair,
        uint256 txEpoch
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
            address(alp_) == address(0) || address(usdt_) == address(0) || address(liquidityALPSource_) == address(0)
                || address(locker_) == address(0) || admin == address(0)
                || address(protocolController_) == address(0)
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

    function receiveLiquidityAllocation(uint256 assetId, uint256 amount) external onlyRole(POOL_ROLE) {
        if (amount == 0) revert InvalidAmount();
        pendingUsdtByAsset[assetId] += amount;
        emit LiquidityAllocationReceived(assetId, amount, pendingUsdtByAsset[assetId]);
    }

    function addLiquidity(
        uint256 assetId,
        uint256 alpAmount,
        uint256 usdtAmount,
        uint256 minAlpAmount,
        uint256 minUsdtAmount,
        uint256 deadline
    ) external onlyRole(LIQUIDITY_OPERATOR_ROLE) returns (uint256 usedAlp, uint256 usedUsdt, uint256 lpAmount) {
        protocolController.requireOperational();
        if (address(router) == address(0)) revert RouterNotConfigured();
        if (mainPair == address(0)) revert PairNotConfigured();
        if (alpAmount == 0 || usdtAmount == 0 || usdtAmount > pendingUsdtByAsset[assetId]) revert InvalidAmount();
        bytes32 operation = keccak256(abi.encodePacked("LIQUIDITY", assetId, block.number, alpAmount, usdtAmount));
        liquidityALPSource.provideLiquidityALP(address(this), alpAmount, operation);
        alp.forceApprove(address(router), alpAmount);
        usdt.forceApprove(address(router), usdtAmount);
        (usedAlp, usedUsdt, lpAmount) = router.addLiquidity(
            address(alp), address(usdt), alpAmount, usdtAmount, minAlpAmount, minUsdtAmount, address(locker), deadline
        );
        alp.forceApprove(address(router), 0);
        usdt.forceApprove(address(router), 0);
        pendingUsdtByAsset[assetId] -= usedUsdt;
        locker.recordLock(mainPair, lpAmount, operation);
        emit LiquidityAdded(assetId, usedAlp, usedUsdt, lpAmount, mainPair, block.timestamp / 1 days);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Records LP deposited directly by the router. It intentionally exposes no
/// transfer, approval, rescue, or withdrawal capability.
contract PermanentLiquidityLocker is AccessControl {
    error ZeroAddress();
    error ExecutorMustBeContract(address executor);

    bytes32 public constant LIQUIDITY_EXECUTOR_ROLE = keccak256("LIQUIDITY_EXECUTOR_ROLE");
    mapping(address => uint256) public lockedLiquidity;

    event LiquidityPermanentlyLocked(
        address indexed pair, uint256 amount, bytes32 indexed operation
    );
    event LiquidityExecutorSet(address indexed executor, bool allowed);

    constructor(address liquidityManager_, address admin) {
        if (liquidityManager_ == address(0) || admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(LIQUIDITY_EXECUTOR_ROLE, liquidityManager_);
    }

    /// @notice Registers the manager and the one-time bootstrapper as the only components
    /// that may attest LP tokens sent directly to this non-withdrawable locker.
    function setLiquidityExecutor(address executor, bool allowed)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (executor == address(0)) revert ZeroAddress();
        if (allowed && executor.code.length == 0) revert ExecutorMustBeContract(executor);
        if (allowed) _grantRole(LIQUIDITY_EXECUTOR_ROLE, executor);
        else _revokeRole(LIQUIDITY_EXECUTOR_ROLE, executor);
        emit LiquidityExecutorSet(executor, allowed);
    }

    function recordLock(address pair, uint256 amount, bytes32 operation)
        external
        onlyRole(LIQUIDITY_EXECUTOR_ROLE)
    {
        if (pair == address(0)) revert ZeroAddress();
        lockedLiquidity[pair] += amount;
        emit LiquidityPermanentlyLocked(pair, amount, operation);
    }
}

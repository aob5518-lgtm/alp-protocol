// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Records LP deposited directly by the router. It intentionally exposes no
/// transfer, approval, rescue, or withdrawal capability.
contract PermanentLiquidityLocker is AccessControl {
    error ZeroAddress();
    error OnlyLiquidityManager(address caller);

    address public immutable liquidityManager;
    mapping(address => uint256) public lockedLiquidity;

    event LiquidityPermanentlyLocked(address indexed pair, uint256 amount, bytes32 indexed operation);

    constructor(address liquidityManager_, address admin) {
        if (liquidityManager_ == address(0) || admin == address(0)) revert ZeroAddress();
        liquidityManager = liquidityManager_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function recordLock(address pair, uint256 amount, bytes32 operation) external {
        if (msg.sender != liquidityManager) revert OnlyLiquidityManager(msg.sender);
        if (pair == address(0)) revert ZeroAddress();
        lockedLiquidity[pair] += amount;
        emit LiquidityPermanentlyLocked(pair, amount, operation);
    }
}

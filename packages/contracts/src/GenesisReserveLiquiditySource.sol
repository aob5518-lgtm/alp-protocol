// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {GenesisReserve} from "./GenesisReserve.sol";
import {ILiquidityALPSource} from "./interfaces/ILiquidityALPSource.sol";

/// @notice Default testnet ALP source. It moves pre-minted ALP from GenesisReserve
/// only to the configured LiquidityManager.
contract GenesisReserveLiquiditySource is AccessControl, ILiquidityALPSource {
    error ZeroAddress();
    error OnlyLiquidityManager(address caller);
    error LiquidityManagerAlreadyConfigured();

    GenesisReserve public immutable genesisReserve;
    address public liquidityManager;

    event LiquidityManagerConfigured(address indexed manager);
    event LiquidityALPProvided(address indexed recipient, uint256 amount, bytes32 indexed operation);

    constructor(GenesisReserve genesisReserve_, address admin) {
        if (address(genesisReserve_) == address(0) || admin == address(0)) revert ZeroAddress();
        genesisReserve = genesisReserve_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function configureLiquidityManager(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (manager == address(0)) revert ZeroAddress();
        if (liquidityManager != address(0)) revert LiquidityManagerAlreadyConfigured();
        liquidityManager = manager;
        emit LiquidityManagerConfigured(manager);
    }

    function provideLiquidityALP(address recipient, uint256 amount, bytes32 operation) external {
        if (msg.sender != liquidityManager) revert OnlyLiquidityManager(msg.sender);
        if (recipient != liquidityManager) revert OnlyLiquidityManager(recipient);
        genesisReserve.releaseToProtocol(recipient, amount, operation);
        emit LiquidityALPProvided(recipient, amount, operation);
    }
}

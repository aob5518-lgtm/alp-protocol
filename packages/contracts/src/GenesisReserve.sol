// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IGenesisReserveToken is IERC20 {
    function burnFromGenesisReserve(uint256 amount) external;
}

/// @notice Custodies the fixed genesis supply and releases it only to registered
/// protocol contracts. It deliberately has no arbitrary transfer or withdrawal API.
contract GenesisReserve is AccessControl {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error TokenAlreadyConfigured();
    error OnlyProtocolModule(address caller);
    error ModuleMustBeContract(address module);

    bytes32 public constant PROTOCOL_MODULE_ROLE = keccak256("PROTOCOL_MODULE_ROLE");

    IGenesisReserveToken public token;

    event GenesisTokenConfigured(address indexed token);
    event ProtocolModuleUpdated(address indexed module, bool allowed);
    event GenesisReserveMovement(
        address indexed module, address indexed recipient, uint256 amount, bytes32 indexed operation
    );

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function configureToken(address token_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token_ == address(0)) revert ZeroAddress();
        if (address(token) != address(0)) revert TokenAlreadyConfigured();
        token = IGenesisReserveToken(token_);
        emit GenesisTokenConfigured(token_);
    }

    /// @dev A module must be deployed code, preventing registration of normal EOAs.
    function setProtocolModule(address module, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (module == address(0)) revert ZeroAddress();
        if (allowed && module.code.length == 0) revert ModuleMustBeContract(module);
        if (allowed) _grantRole(PROTOCOL_MODULE_ROLE, module);
        else _revokeRole(PROTOCOL_MODULE_ROLE, module);
        emit ProtocolModuleUpdated(module, allowed);
    }

    function releaseToProtocol(address recipient, uint256 amount, bytes32 operation)
        external
        onlyRole(PROTOCOL_MODULE_ROLE)
    {
        if (recipient == address(0) || recipient.code.length == 0) revert ModuleMustBeContract(recipient);
        IERC20(address(token)).safeTransfer(recipient, amount);
        emit GenesisReserveMovement(msg.sender, recipient, amount, operation);
    }

    function burn(uint256 amount, bytes32 operation) external onlyRole(PROTOCOL_MODULE_ROLE) {
        token.burnFromGenesisReserve(amount);
        emit GenesisReserveMovement(msg.sender, address(0), amount, operation);
    }
}

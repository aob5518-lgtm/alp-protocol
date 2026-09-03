// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ProductionConfigValidator} from "./ProductionConfigValidator.sol";

/// @notice Shared emergency circuit breaker and production-readiness gate.
contract ProtocolController is AccessControl, Pausable {
    error ZeroAddress();
    error ProtocolPaused();
    error ProductionNotReady();

    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    ProductionConfigValidator public immutable productionValidator;

    event EmergencyPaused(address indexed guardian);
    event ProtocolResumed(address indexed governance);

    constructor(ProductionConfigValidator productionValidator_, address admin) {
        if (address(productionValidator_) == address(0) || admin == address(0)) revert ZeroAddress();
        productionValidator = productionValidator_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
    }

    function emergencyPause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
        emit EmergencyPaused(msg.sender);
    }

    function resume() external onlyRole(GOVERNANCE_ROLE) {
        _unpause();
        emit ProtocolResumed(msg.sender);
    }

    function requireOperational() external view {
        if (paused()) revert ProtocolPaused();
    }

    function requireProductionReady() external view {
        if (!productionValidator.productionMode()) revert ProductionNotReady();
    }
}

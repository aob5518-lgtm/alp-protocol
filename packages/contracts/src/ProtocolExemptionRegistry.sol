// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Immutable-at-launch allowlist for protocol-only Liquidity Cycle exclusions.
contract ProtocolExemptionRegistry is AccessControl {
    error ZeroAddress();
    error ExemptionsSealed();
    error NotContract(address account);
    mapping(address => bool) public protocolExempt;
    bool public exemptionsSealed;
    event ProtocolExemptionUpdated(address indexed account, bool exempt);
    event ProtocolExemptionsSealed();

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setProtocolExempt(address account, bool exempt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (exemptionsSealed) revert ExemptionsSealed();
        if (account == address(0)) revert ZeroAddress();
        if (exempt && account.code.length == 0) revert NotContract(account);
        protocolExempt[account] = exempt;
        emit ProtocolExemptionUpdated(account, exempt);
    }

    function sealProtocolExemptions() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (exemptionsSealed) revert ExemptionsSealed();
        exemptionsSealed = true;
        emit ProtocolExemptionsSealed();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Explicit on-chain safety gate used by deployment and admin tooling before a production launch.
contract ProductionConfigValidator is AccessControl {
    error ZeroAddress();
    error ProductionRequirementsIncomplete();
    error ProductionAlreadyEnabled();

    struct Configuration {
        address oracle;
        address mainPair;
        address treasurySafe;
        address timelock;
        address compensationStrategy;
        address nodeDividendFundingSource;
        bool rewardSplitConfigured;
        bool liquidityALPSourceConfigured;
        bool tierVolumeBaseApproved;
        bool tierSnapshotSystemConfigured;
        bool emissionScheduleApproved;
        bool protocolModulesSealed;
        bool protocolExemptionsSealed;
        bool oracleConfigured;
        bool mainPairConfigured;
        bool treasurySafeConfigured;
        bool timelockConfigured;
        bool externalAuditApproved;
        bytes32 auditApprovalHash;
    }

    Configuration public configuration;
    bool public productionMode;

    event ConfigurationUpdated(Configuration configuration);
    event ProductionModeEnabled(address indexed by);

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function configure(Configuration calldata configuration_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (productionMode) revert ProductionAlreadyEnabled();
        configuration = configuration_;
        emit ConfigurationUpdated(configuration_);
    }

    function readyForProduction() public view returns (bool) {
        Configuration memory c = configuration;
        return c.rewardSplitConfigured && c.liquidityALPSourceConfigured && c.tierVolumeBaseApproved
            && c.tierSnapshotSystemConfigured && c.emissionScheduleApproved && c.protocolModulesSealed
            && c.protocolExemptionsSealed && c.oracleConfigured && c.mainPairConfigured && c.treasurySafeConfigured
            && c.timelockConfigured && c.externalAuditApproved && c.auditApprovalHash != bytes32(0)
            && _isContract(c.oracle) && _isContract(c.mainPair) && _isContract(c.treasurySafe) && _isContract(c.timelock)
            && _isContract(c.compensationStrategy) && _isContract(c.nodeDividendFundingSource);
    }

    function enableProductionMode() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!readyForProduction()) revert ProductionRequirementsIncomplete();
        productionMode = true;
        emit ProductionModeEnabled(msg.sender);
    }

    function _isContract(address account) private view returns (bool) { return account != address(0) && account.code.length != 0; }
}

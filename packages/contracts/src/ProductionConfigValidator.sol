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
        return c.rewardSplitConfigured && c.oracle != address(0) && c.mainPair != address(0) && c.treasurySafe != address(0)
            && c.timelock != address(0) && c.compensationStrategy != address(0) && c.nodeDividendFundingSource != address(0);
    }

    function enableProductionMode() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!readyForProduction()) revert ProductionRequirementsIncomplete();
        productionMode = true;
        emit ProductionModeEnabled(msg.sender);
    }
}

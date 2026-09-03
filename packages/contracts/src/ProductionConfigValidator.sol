// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

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
        address genesisReserve;
        address protocolExemptionRegistry;
        address alpToken;
        address emissionEngine;
        address tierSnapshotRegistry;
        address tierEngine;
        address genesisReserveLiquiditySource;
        bool rewardSplitConfigured;
        bool liquidityALPSourceConfigured;
        bool tierVolumeBaseApproved;
        bool tierSnapshotSystemConfigured;
        bool oracleConfigured;
        bool mainPairConfigured;
        bool treasurySafeConfigured;
        bool timelockConfigured;
        bool externalAuditApproved;
        bytes32 auditApprovalHash;
    }

    Configuration public configuration;
    bool public productionMode;
    bytes32 public constant TIER_RULES_V1_HASH = keccak256(
        "ALP_TIER_V1|TOTAL_POSITION_VALUE|UNLIMITED_DEPTH|3000:2|10000:3|30000:4|100000:5|300000:6|1000000:7|3000000:8|6000000:9|10000000:10"
    );

    event ConfigurationUpdated(Configuration configuration);
    event ProductionModeEnabled(address indexed by);

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function configure(Configuration calldata configuration_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (productionMode) revert ProductionAlreadyEnabled();
        configuration = configuration_;
        emit ConfigurationUpdated(configuration_);
    }

    function readyForProduction() public view returns (bool) {
        Configuration memory c = configuration;
        return c.rewardSplitConfigured && c.liquidityALPSourceConfigured && c.tierVolumeBaseApproved
            && c.tierSnapshotSystemConfigured && c.oracleConfigured && c.mainPairConfigured
            && c.treasurySafeConfigured && c.timelockConfigured && c.externalAuditApproved
            && c.auditApprovalHash != bytes32(0) && _isContract(c.oracle) && _isContract(c.mainPair)
            && _isContract(c.treasurySafe) && _isContract(c.timelock)
            && _isContract(c.compensationStrategy) && _isContract(c.nodeDividendFundingSource)
            && _returnsTrue(c.genesisReserve, "modulesSealed()")
            && _returnsTrue(c.protocolExemptionRegistry, "exemptionsSealed()")
            && _returnsTrue(c.alpToken, "sellFeeExemptionsSealed()")
            && _returnsTrue(c.alpToken, "buyRestrictionConfigSealed()")
            && _returnsTrue(c.emissionEngine, "emissionScheduleApproved()")
            && _returnsTrue(c.genesisReserveLiquiditySource, "liquidityConsumersSealed()")
            && _returnsAddress(c.tierEngine, "snapshotRegistry()", c.tierSnapshotRegistry)
            && _returnsUint8(c.tierEngine, "volumeBase()", 1)
            && _returnsBytes32(c.tierSnapshotRegistry, "TIER_RULES_V1_HASH()", TIER_RULES_V1_HASH);
    }

    function enableProductionMode() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!readyForProduction()) revert ProductionRequirementsIncomplete();
        productionMode = true;
        emit ProductionModeEnabled(msg.sender);
    }

    function _isContract(address account) private view returns (bool) {
        return account != address(0) && account.code.length != 0;
    }

    function _returnsTrue(address target, string memory selector) private view returns (bool) {
        if (!_isContract(target)) return false;
        (bool success, bytes memory result) = target.staticcall(abi.encodeWithSignature(selector));
        return success && result.length == 32 && abi.decode(result, (bool));
    }

    function _returnsBytes32(address target, string memory selector, bytes32 expected)
        private
        view
        returns (bool)
    {
        if (!_isContract(target)) return false;
        (bool success, bytes memory result) = target.staticcall(abi.encodeWithSignature(selector));
        return success && result.length == 32 && abi.decode(result, (bytes32)) == expected;
    }

    function _returnsAddress(address target, string memory selector, address expected) private view returns (bool) {
        if (!_isContract(target)) return false;
        (bool success, bytes memory result) = target.staticcall(abi.encodeWithSignature(selector));
        return success && result.length == 32 && abi.decode(result, (address)) == expected;
    }

    function _returnsUint8(address target, string memory selector, uint8 expected) private view returns (bool) {
        if (!_isContract(target)) return false;
        (bool success, bytes memory result) = target.staticcall(abi.encodeWithSignature(selector));
        return success && result.length == 32 && abi.decode(result, (uint8)) == expected;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ProductionConfigValidator } from "../src/ProductionConfigValidator.sol";

contract ConfigTarget {
    bool public closed = true;
    bool public approved = true;

    function modulesSealed() external view returns (bool) {
        return closed;
    }

    function exemptionsSealed() external view returns (bool) {
        return closed;
    }

    function sellFeeExemptionsSealed() external view returns (bool) {
        return closed;
    }

    function buyRestrictionConfigSealed() external view returns (bool) {
        return closed;
    }

    function emissionScheduleApproved() external view returns (bool) {
        return approved;
    }

    function TIER_RULES_V1_HASH() external pure returns (bytes32) {
        return keccak256(
            "ALP_TIER_V1|TOTAL_POSITION_VALUE|UNLIMITED_DEPTH|3000:2|10000:3|30000:4|100000:5|300000:6|1000000:7|3000000:8|6000000:9|10000000:10"
        );
    }

    function setSealed(bool value) external {
        closed = value;
    }
}

contract ProductionConfigValidatorTest is Test {
    ProductionConfigValidator internal validator;

    function setUp() public {
        validator = new ProductionConfigValidator(address(this));
    }

    function testCannotEnableProductionWithMissingSafetyConfiguration() public {
        vm.expectRevert(ProductionConfigValidator.ProductionRequirementsIncomplete.selector);
        validator.enableProductionMode();
    }

    function testEnablesOnlyAfterAllMandatoryItemsAreSet() public {
        ConfigTarget target = new ConfigTarget();
        validator.configure(
            ProductionConfigValidator.Configuration({
                oracle: address(target),
                mainPair: address(target),
                treasurySafe: address(target),
                timelock: address(target),
                compensationStrategy: address(target),
                nodeDividendFundingSource: address(target),
                genesisReserve: address(target),
                protocolExemptionRegistry: address(target),
                alpToken: address(target),
                emissionEngine: address(target),
                tierSnapshotRegistry: address(target),
                rewardSplitConfigured: true,
                liquidityALPSourceConfigured: true,
                tierVolumeBaseApproved: true,
                tierSnapshotSystemConfigured: true,
                oracleConfigured: true,
                mainPairConfigured: true,
                treasurySafeConfigured: true,
                timelockConfigured: true,
                externalAuditApproved: true,
                auditApprovalHash: keccak256("audit")
            })
        );
        assertTrue(validator.readyForProduction());
        validator.enableProductionMode();
        assertTrue(validator.productionMode());
    }

    function testRejectsAdministratorClaimWhenModuleIsNotActuallySealed() public {
        ConfigTarget target = new ConfigTarget();
        target.setSealed(false);
        validator.configure(_completeConfiguration(address(target)));
        assertFalse(validator.readyForProduction());
    }

    function testEOAAddressesCanNeverEnableProduction() public {
        validator.configure(
            ProductionConfigValidator.Configuration({
                oracle: makeAddr("oracle"),
                mainPair: makeAddr("pair"),
                treasurySafe: makeAddr("safe"),
                timelock: makeAddr("timelock"),
                compensationStrategy: makeAddr("linear"),
                nodeDividendFundingSource: makeAddr("nodeFunding"),
                genesisReserve: makeAddr("reserve"),
                protocolExemptionRegistry: makeAddr("exemptions"),
                alpToken: makeAddr("alp"),
                emissionEngine: makeAddr("emission"),
                tierSnapshotRegistry: makeAddr("tierSnapshots"),
                rewardSplitConfigured: true,
                liquidityALPSourceConfigured: true,
                tierVolumeBaseApproved: true,
                tierSnapshotSystemConfigured: true,
                oracleConfigured: true,
                mainPairConfigured: true,
                treasurySafeConfigured: true,
                timelockConfigured: true,
                externalAuditApproved: true,
                auditApprovalHash: keccak256("audit")
            })
        );
        assertFalse(validator.readyForProduction());
    }

    function _completeConfiguration(address target)
        private
        pure
        returns (ProductionConfigValidator.Configuration memory)
    {
        return ProductionConfigValidator.Configuration({
            oracle: target,
            mainPair: target,
            treasurySafe: target,
            timelock: target,
            compensationStrategy: target,
            nodeDividendFundingSource: target,
            genesisReserve: target,
            protocolExemptionRegistry: target,
            alpToken: target,
            emissionEngine: target,
            tierSnapshotRegistry: target,
            rewardSplitConfigured: true,
            liquidityALPSourceConfigured: true,
            tierVolumeBaseApproved: true,
            tierSnapshotSystemConfigured: true,
            oracleConfigured: true,
            mainPairConfigured: true,
            treasurySafeConfigured: true,
            timelockConfigured: true,
            externalAuditApproved: true,
            auditApprovalHash: keccak256("audit")
        });
    }
}

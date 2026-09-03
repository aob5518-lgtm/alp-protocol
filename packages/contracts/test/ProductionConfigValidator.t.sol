// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ProductionConfigValidator} from "../src/ProductionConfigValidator.sol";

contract ConfigTarget {}

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
                oracle: address(target), mainPair: address(target), treasurySafe: address(target), timelock: address(target),
                compensationStrategy: address(target), nodeDividendFundingSource: address(target), rewardSplitConfigured: true,
                liquidityALPSourceConfigured: true, tierVolumeBaseApproved: true, tierSnapshotSystemConfigured: true,
                emissionScheduleApproved: true, protocolModulesSealed: true, protocolExemptionsSealed: true,
                oracleConfigured: true, mainPairConfigured: true, treasurySafeConfigured: true, timelockConfigured: true,
                externalAuditApproved: true, auditApprovalHash: keccak256("audit")
            })
        );
        assertTrue(validator.readyForProduction());
        validator.enableProductionMode();
        assertTrue(validator.productionMode());
    }

    function testEOAAddressesCanNeverEnableProduction() public {
        validator.configure(ProductionConfigValidator.Configuration({
            oracle: makeAddr("oracle"), mainPair: makeAddr("pair"), treasurySafe: makeAddr("safe"), timelock: makeAddr("timelock"),
            compensationStrategy: makeAddr("linear"), nodeDividendFundingSource: makeAddr("nodeFunding"), rewardSplitConfigured: true,
            liquidityALPSourceConfigured: true, tierVolumeBaseApproved: true, tierSnapshotSystemConfigured: true,
            emissionScheduleApproved: true, protocolModulesSealed: true, protocolExemptionsSealed: true,
            oracleConfigured: true, mainPairConfigured: true, treasurySafeConfigured: true, timelockConfigured: true,
            externalAuditApproved: true, auditApprovalHash: keccak256("audit")
        }));
        assertFalse(validator.readyForProduction());
    }
}

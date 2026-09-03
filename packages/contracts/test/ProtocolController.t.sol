// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ProductionConfigValidator } from "../src/ProductionConfigValidator.sol";
import { ProtocolController } from "../src/ProtocolController.sol";

contract ProtocolConfigTarget { }

contract ProtocolControllerTest is Test {
    ProductionConfigValidator internal validator;
    ProtocolController internal controller;

    function setUp() public {
        validator = new ProductionConfigValidator(address(this));
        controller = new ProtocolController(validator, address(this));
    }

    function testProductionGateUsesValidatorState() public {
        vm.expectRevert(ProtocolController.ProductionNotReady.selector);
        controller.requireProductionReady();

        ProtocolConfigTarget target = new ProtocolConfigTarget();
        validator.configure(
            ProductionConfigValidator.Configuration({
                oracle: address(target),
                mainPair: address(target),
                treasurySafe: address(target),
                timelock: address(target),
                compensationStrategy: address(target),
                nodeDividendFundingSource: address(target),
                rewardSplitConfigured: true,
                liquidityALPSourceConfigured: true,
                tierVolumeBaseApproved: true,
                tierSnapshotSystemConfigured: true,
                emissionScheduleApproved: true,
                protocolModulesSealed: true,
                protocolExemptionsSealed: true,
                oracleConfigured: true,
                mainPairConfigured: true,
                treasurySafeConfigured: true,
                timelockConfigured: true,
                externalAuditApproved: true,
                auditApprovalHash: keccak256("audit")
            })
        );
        validator.enableProductionMode();
        controller.requireProductionReady();
    }
}

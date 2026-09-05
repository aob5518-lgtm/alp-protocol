// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ProductionConfigValidator } from "../src/ProductionConfigValidator.sol";
import { ProtocolController } from "../src/ProtocolController.sol";

contract ProtocolConfigTarget {
    function modulesSealed() external pure returns (bool) {
        return true;
    }

    function exemptionsSealed() external pure returns (bool) {
        return true;
    }

    function sellFeeExemptionsSealed() external pure returns (bool) {
        return true;
    }

    function buyRestrictionConfigSealed() external pure returns (bool) {
        return true;
    }

    function emissionScheduleApproved() external pure returns (bool) {
        return true;
    }

    function liquidityConsumersSealed() external pure returns (bool) {
        return true;
    }

    function TIER_RULES_V1_HASH() external pure returns (bytes32) {
        return keccak256(
            "ALP_TIER_V1|TOTAL_POSITION_VALUE|UNLIMITED_DEPTH|3000:2|10000:3|30000:4|100000:5|300000:6|1000000:7|3000000:8|6000000:9|10000000:10"
        );
    }
}

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
                genesisReserve: address(target),
                protocolExemptionRegistry: address(target),
                alpToken: address(target),
                emissionEngine: address(target),
                tierSnapshotRegistry: address(target),
                tierEngine: address(target),
                genesisReserveLiquiditySource: address(target),
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
        validator.enableProductionMode();
        controller.requireProductionReady();
    }
}

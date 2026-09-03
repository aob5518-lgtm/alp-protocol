// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ProductionConfigValidator} from "../src/ProductionConfigValidator.sol";
import {ProtocolController} from "../src/ProtocolController.sol";

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

        validator.configure(
            ProductionConfigValidator.Configuration({
                oracle: makeAddr("oracle"), mainPair: makeAddr("pair"), treasurySafe: makeAddr("safe"),
                timelock: makeAddr("timelock"), compensationStrategy: makeAddr("strategy"),
                nodeDividendFundingSource: makeAddr("funding"), rewardSplitConfigured: true
            })
        );
        validator.enableProductionMode();
        controller.requireProductionReady();
    }
}

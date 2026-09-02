// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ProductionConfigValidator} from "../src/ProductionConfigValidator.sol";

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
        validator.configure(
            ProductionConfigValidator.Configuration({
                oracle: makeAddr("oracle"),
                mainPair: makeAddr("pair"),
                treasurySafe: makeAddr("safe"),
                timelock: makeAddr("timelock"),
                compensationStrategy: makeAddr("linear"),
                nodeDividendFundingSource: makeAddr("nodeFunding"),
                rewardSplitConfigured: true
            })
        );
        assertTrue(validator.readyForProduction());
        validator.enableProductionMode();
        assertTrue(validator.productionMode());
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import {
    LinearDailyCompensationStrategy
} from "../src/strategies/LinearDailyCompensationStrategy.sol";
import {
    CompoundDailyCompensationStrategy
} from "../src/strategies/CompoundDailyCompensationStrategy.sol";

contract CompensationTest is Test {
    function testLinearMatchesSpecifiedFactors() public {
        LinearDailyCompensationStrategy strategy = new LinearDailyCompensationStrategy();
        assertEq(strategy.factor(0), 1e18);
        assertEq(strategy.factor(30), 1.3e18);
        assertEq(strategy.factor(60), 1.6e18);
        assertEq(strategy.factor(100), 2e18);
    }

    function testCompoundIsHigherThanLinearAfterOneDay() public {
        CompoundDailyCompensationStrategy compound = new CompoundDailyCompensationStrategy();
        assertEq(compound.factor(1), 1.01e18);
        assertGt(compound.factor(30), 1.3e18);
    }
}

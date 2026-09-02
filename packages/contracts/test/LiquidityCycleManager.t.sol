// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ALPToken} from "../src/ALPToken.sol";
import {LiquidityCycleManager} from "../src/LiquidityCycleManager.sol";

contract LiquidityCycleManagerTest is Test {
    address internal reserve = makeAddr("reserve");
    address internal user = makeAddr("user");
    address internal recipient = makeAddr("recipient");
    address internal pair = makeAddr("pair");
    ALPToken internal alp;
    LiquidityCycleManager internal manager;

    function setUp() public {
        alp = new ALPToken(
            reserve,
            address(this),
            makeAddr("buyback"),
            makeAddr("top100"),
            makeAddr("nodeAirdrop"),
            makeAddr("community"),
            makeAddr("development")
        );
        manager = new LiquidityCycleManager(alp);
        alp.grantRole(alp.LIQUIDITY_CYCLE_ROLE(), address(manager));
        alp.configureLiquidityCycleManager(address(manager));
        alp.configureMainPair(pair);
        alp.setSellFeeExempt(reserve, true);
    }

    function testOverdueCycleBurnsMissingSellAmount() public {
        vm.prank(reserve);
        alp.transfer(user, 100 ether);
        vm.warp(block.timestamp + 15 days);
        manager.settleOverdueCycle(user, 0);
        assertEq(alp.balanceOf(user), 80 ether);
        assertEq(alp.totalSupply(), 210_000_000 ether - 20 ether);
        (uint256 required, uint256 sold, uint256 burned, bool settled) = manager.cycleProgress(user, 0);
        assertEq(required, 20 ether);
        assertEq(sold, 0);
        assertEq(burned, 20 ether);
        assertTrue(settled);
    }

    function testGrossSellCreditsCycleBeforeDeadline() public {
        vm.prank(reserve);
        alp.transfer(user, 100 ether);
        vm.prank(user);
        alp.transfer(pair, 20 ether);
        vm.warp(block.timestamp + 15 days);
        manager.settleOverdueCycle(user, 0);
        assertEq(alp.balanceOf(user), 80 ether);
        assertEq(alp.balanceOf(pair), 16.6 ether);
        (,, uint256 burned,) = manager.cycleProgress(user, 0);
        assertEq(burned, 0);
    }

    function testUnfundedForcedBurnBecomesDebtAndBurnsFutureReceipts() public {
        vm.prank(reserve);
        alp.transfer(user, 100 ether);
        vm.prank(user);
        alp.transfer(recipient, 100 ether);
        vm.warp(block.timestamp + 15 days);
        manager.settleOverdueCycle(user, 0);
        (,, uint256 debt,) = manager.cycleState(user);
        assertEq(debt, 20 ether);

        vm.prank(reserve);
        alp.transfer(user, 10 ether);
        (,, debt,) = manager.cycleState(user);
        assertEq(alp.balanceOf(user), 0);
        assertEq(debt, 10 ether);
    }
}

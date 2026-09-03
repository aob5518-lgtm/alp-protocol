// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ALPToken } from "../src/ALPToken.sol";
import { GenesisReserve } from "../src/GenesisReserve.sol";
import { LiquidityCycleManager } from "../src/LiquidityCycleManager.sol";
import { ProtocolExemptionRegistry } from "../src/ProtocolExemptionRegistry.sol";

contract LiquidityCycleManagerTest is Test {
    address internal reserve = makeAddr("reserve");
    address internal user = makeAddr("user");
    address internal recipient = makeAddr("recipient");
    address internal pair = makeAddr("pair");
    ALPToken internal alp;
    LiquidityCycleManager internal manager;
    GenesisReserve internal genesisReserve;

    function setUp() public {
        genesisReserve = new GenesisReserve(address(this));
        reserve = address(genesisReserve);
        alp = new ALPToken(
            reserve,
            address(this),
            makeAddr("buyback"),
            makeAddr("top100"),
            makeAddr("nodeAirdrop"),
            makeAddr("community"),
            makeAddr("development")
        );
        genesisReserve.configureToken(address(alp));
        manager = new LiquidityCycleManager(alp);
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
        (uint256 required, uint256 sold, uint256 burned, bool settled) =
            manager.cycleProgress(user, 0);
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
        // An extreme protocol-side burn can still leave a debt; ordinary P2P
        // transfers cannot create this state because they retain the obligation.
        vm.prank(address(manager));
        alp.forceBurnForLiquidityCycle(user, 100 ether);
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

    function testP2PTransferCannotEscapeCurrentCycleObligation() public {
        vm.prank(reserve);
        alp.transfer(user, 100 ether);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                LiquidityCycleManager.LiquidityObligationViolation.selector,
                user,
                19 ether,
                20 ether
            )
        );
        alp.transfer(recipient, 81 ether);

        vm.prank(user);
        alp.transfer(recipient, 80 ether);
        assertEq(alp.balanceOf(user), 20 ether);
        assertEq(manager.outstandingObligation(user), 20 ether);
    }

    function testEachCycleTakesAnIndependentSnapshotBeforeIncomingTransfers() public {
        vm.prank(reserve);
        alp.transfer(user, 100 ether);
        vm.warp(block.timestamp + 15 days);

        // The first movement in cycle two snapshots the 100 ALP balance.
        vm.prank(user);
        alp.transfer(recipient, 1 ether);
        (uint64 startTime, uint256 baseline, uint256 required) = manager.cycleSnapshot(user, 1);
        assertEq(startTime, uint64(block.timestamp));
        assertEq(baseline, 100 ether);
        assertEq(required, 15 ether);

        // ALP received during this cycle stays out of the current baseline.
        vm.prank(reserve);
        alp.transfer(user, 100 ether);
        (, baseline, required) = manager.cycleSnapshot(user, 1);
        assertEq(baseline, 100 ether);
        assertEq(required, 15 ether);
    }

    function testFirstSellOfCycleTwoUsesPreSellBalanceAsBaseline() public {
        vm.prank(reserve);
        alp.transfer(user, 100 ether);
        vm.warp(block.timestamp + 15 days);

        vm.prank(user);
        alp.transfer(pair, 10 ether);

        (, uint256 baseline, uint256 required) = manager.cycleSnapshot(user, 1);
        assertEq(baseline, 100 ether);
        assertEq(required, 15 ether);
    }

    function testProtocolExemptRecipientDoesNotStartLiquidityCycle() public {
        ProtocolExemptionRegistry registry = new ProtocolExemptionRegistry(address(this));
        registry.setProtocolExempt(address(manager), true);
        registry.sealProtocolExemptions();
        alp.configureProtocolExemptionRegistry(address(registry));

        vm.prank(reserve);
        alp.transfer(address(manager), 100 ether);
        (uint64 startedAt,,,) = manager.cycleState(address(manager));
        assertEq(startedAt, 0);
    }
}

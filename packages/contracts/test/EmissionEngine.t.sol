// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ALPToken} from "../src/ALPToken.sol";
import {GenesisReserve} from "../src/GenesisReserve.sol";
import {GlobalComputeEngine} from "../src/GlobalComputeEngine.sol";
import {EmissionEngine} from "../src/EmissionEngine.sol";
import {MockPair} from "./mocks/MockPair.sol";

contract EmissionEngineTest is Test {
    address internal reserve = makeAddr("reserve");
    address internal computeUser = makeAddr("computeUser");
    ALPToken internal alp;
    GlobalComputeEngine internal compute;
    EmissionEngine internal engine;
    MockPair internal pair;
    GenesisReserve internal genesisReserve;

    function setUp() public {
        pair = new MockPair();
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
        alp.configureMainPair(address(pair));
        alp.setSellFeeExempt(reserve, true);
        compute = new GlobalComputeEngine(alp, address(this));
        engine = new EmissionEngine(alp, compute, address(pair), 1 days, address(this));
        alp.configureEmissionEngine(address(engine));
        compute.grantRole(compute.EMISSION_ROLE(), address(engine));
        compute.grantRole(compute.POOL_ROLE(), address(this));
        compute.addPosition(1, computeUser, 1 ether);
        vm.prank(reserve);
        alp.transfer(address(pair), 10_000 ether);
    }

    function testPermissionlessEpochBurnsAndEmitsFromStartReserve() public {
        vm.warp(1 days);
        engine.approveV1EmissionSchedule();
        engine.activateEmission();
        engine.settleEpoch();

        assertEq(engine.epochId(), 1);
        assertEq(alp.balanceOf(address(pair)), 9_820 ether);
        assertEq(alp.balanceOf(address(compute)), 60 ether);
        assertEq(alp.totalSupply(), 210_000_000 ether - 120 ether);
        assertEq(compute.undistributedEmission(), 0);
        assertEq(pair.syncCount(), 1);
        (,, uint256 burnAmount, uint256 emissionAmount,,,) = engine.epochs(1);
        assertEq(burnAmount, 120 ether);
        assertEq(emissionAmount, 60 ether);
    }

    function testOutputRateCapsAtOnePointTwoPercent() public view {
        assertEq(engine.outputRateBps(1), 60);
        assertEq(engine.outputRateBps(59), 118);
        assertEq(engine.outputRateBps(60), 120);
        assertEq(engine.outputRateBps(500), 120);
    }

    function testCannotActivateBeforeAnyUserComputeExists() public {
        GlobalComputeEngine emptyCompute = new GlobalComputeEngine(alp, address(this));
        EmissionEngine emptyEngine = new EmissionEngine(alp, emptyCompute, address(pair), 1 days, address(this));
        emptyEngine.approveV1EmissionSchedule();

        vm.expectRevert(EmissionEngine.NoGlobalCompute.selector);
        emptyEngine.activateEmission();
    }

    function testEmissionScheduleRequiresGovernanceApprovalBeforeActivation() public {
        vm.expectRevert(EmissionEngine.EmissionScheduleNotApproved.selector);
        engine.activateEmission();
        engine.approveV1EmissionSchedule();
        assertTrue(engine.emissionScheduleApproved());
        assertEq(engine.V1_SCHEDULE_HASH(), keccak256("ALP_V1_EMISSION_DAY60_120_BPS"));
    }

    function testZeroComputeEmissionIsDeferredThenAllocatedToTheFirstActiveCompute() public {
        GlobalComputeEngine deferredCompute = new GlobalComputeEngine(alp, address(this));
        deferredCompute.grantRole(deferredCompute.EMISSION_ROLE(), address(this));
        deferredCompute.notifyEmission(60 ether);
        assertEq(deferredCompute.undistributedEmission(), 60 ether);
        assertEq(deferredCompute.totalEmitted(), 0);

        deferredCompute.grantRole(deferredCompute.POOL_ROLE(), address(this));
        deferredCompute.addPosition(999, computeUser, 1 ether);
        deferredCompute.notifyEmission(6 ether);

        assertEq(deferredCompute.undistributedEmission(), 0);
        assertEq(deferredCompute.totalEmitted(), 66 ether);
        assertEq(deferredCompute.pending(999), 66 ether);
    }
}

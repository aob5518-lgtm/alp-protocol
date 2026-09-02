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
        vm.prank(reserve);
        alp.transfer(address(pair), 10_000 ether);
    }

    function testPermissionlessEpochBurnsAndEmitsFromStartReserve() public {
        vm.warp(1 days);
        engine.settleEpoch();

        assertEq(engine.epochId(), 1);
        assertEq(alp.balanceOf(address(pair)), 9_820 ether);
        assertEq(alp.balanceOf(address(compute)), 60 ether);
        assertEq(alp.totalSupply(), 210_000_000 ether - 120 ether);
        assertEq(compute.undistributedEmission(), 60 ether);
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
}

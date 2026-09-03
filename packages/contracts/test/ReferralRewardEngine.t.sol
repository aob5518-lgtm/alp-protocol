// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { SponsorRegistry } from "../src/SponsorRegistry.sol";
import { ReferralRewardEngine } from "../src/ReferralRewardEngine.sol";
import { GlobalComputeEngine } from "../src/GlobalComputeEngine.sol";

contract ReferralRewardEngineTest is Test {
    MockERC20 internal usdt;
    MockERC20 internal alp;
    SponsorRegistry internal sponsors;
    GlobalComputeEngine internal compute;
    ReferralRewardEngine internal referral;
    address internal treasury = makeAddr("treasury");
    address internal sponsor = makeAddr("sponsor");
    address internal referred = makeAddr("referred");

    function setUp() public {
        usdt = new MockERC20("USDT", "USDT", 18);
        alp = new MockERC20("ALP", "ALP", 18);
        sponsors = new SponsorRegistry(address(this));
        compute = new GlobalComputeEngine(alp, address(this));
        referral = new ReferralRewardEngine(usdt, treasury, sponsors, compute, address(this), true);
        sponsors.grantRole(sponsors.POOL_ROLE(), address(this));
        referral.grantRole(referral.POOL_ROLE(), address(this));
        compute.grantRole(compute.POOL_ROLE(), address(referral));
        usdt.mint(treasury, 1_000 ether);
        vm.prank(treasury);
        usdt.approve(address(referral), type(uint256).max);
        vm.prank(referred);
        sponsors.bindSponsor(sponsor);
        sponsors.activateContributor(referred);
    }

    function testDefaultSplitPaysSixPercentLevelOneInUsdt() public {
        referral.distribute(111, referred, 500 ether);
        assertEq(usdt.balanceOf(sponsor), 30 ether);
        assertEq(usdt.balanceOf(treasury), 970 ether);
        assertEq(compute.globalEffectiveCompute(), 0);
    }

    function testComputeSplitCreatesGlobalComputeAndPreventsReplay() public {
        referral.configureRewardSplit(5_000, 5_000);
        referral.distribute(222, referred, 500 ether);
        assertEq(usdt.balanceOf(sponsor), 15 ether);
        assertEq(compute.globalEffectiveCompute(), 15 ether);
        vm.expectRevert(abi.encodeWithSelector(ReferralRewardEngine.AlreadyProcessed.selector, 222));
        referral.distribute(222, referred, 500 ether);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {SponsorRegistry} from "../src/SponsorRegistry.sol";
import {TierEngine} from "../src/TierEngine.sol";
import {DifferentialRewardEngine} from "../src/DifferentialRewardEngine.sol";

contract DifferentialRewardEngineTest is Test {
    address internal treasury = makeAddr("treasury");
    address internal upper = makeAddr("upper");
    address internal lower = makeAddr("lower");
    address internal other = makeAddr("other");
    address internal user = makeAddr("user");
    MockERC20 internal usdt;
    SponsorRegistry internal sponsors;
    TierEngine internal tiers;
    DifferentialRewardEngine internal engine;

    function setUp() public {
        usdt = new MockERC20("USDT", "USDT", 18);
        sponsors = new SponsorRegistry(address(this));
        tiers = new TierEngine(sponsors, TierEngine.VolumeBase.USDT_CONTRIBUTION, address(this));
        engine = new DifferentialRewardEngine(usdt, treasury, sponsors, tiers, address(this));
        sponsors.grantRole(sponsors.POOL_ROLE(), address(this));
        tiers.grantRole(tiers.POOL_ROLE(), address(this));
        engine.grantRole(engine.POOL_ROLE(), address(this));
        usdt.mint(treasury, 100 ether);
        vm.prank(treasury);
        usdt.approve(address(engine), type(uint256).max);
        vm.prank(lower);
        sponsors.bindSponsor(upper);
        vm.prank(other);
        sponsors.bindSponsor(upper);
        vm.prank(user);
        sponsors.bindSponsor(lower);
        // Root has two branches: 4,000 and 3,000 USDT, so its small district is 3,000 => V1 (2%).
        tiers.recordPosition(lower, 4_000 ether, 8_000 ether);
        tiers.recordPosition(other, 3_000 ether, 6_000 ether);
    }

    function testPaysOnlyTheNonOverlappingTierDelta() public {
        engine.distribute(1, user, 500 ether);
        assertEq(usdt.balanceOf(lower), 0);
        assertEq(usdt.balanceOf(upper), 10 ether);
        assertEq(usdt.balanceOf(treasury), 90 ether);
        vm.expectRevert(abi.encodeWithSelector(DifferentialRewardEngine.AlreadyProcessed.selector, 1));
        engine.distribute(1, user, 500 ether);
    }
}

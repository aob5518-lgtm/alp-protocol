// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { SponsorRegistry } from "../src/SponsorRegistry.sol";
import { TierEngine } from "../src/TierEngine.sol";
import { DifferentialRewardEngine } from "../src/DifferentialRewardEngine.sol";
import { TierSnapshotRegistry } from "../src/TierSnapshotRegistry.sol";

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
        vm.expectRevert(
            abi.encodeWithSelector(DifferentialRewardEngine.AlreadyProcessed.selector, 1)
        );
        engine.distribute(1, user, 500 ether);
    }

    function testSnapshotTiersPayV5ThenV4ThenV9AsSixZeroFour() public {
        address v5 = makeAddr("v5");
        address v4 = makeAddr("v4");
        address v9 = makeAddr("v9");
        address contributor = makeAddr("contributor");
        TierSnapshotRegistry snapshots = new TierSnapshotRegistry(0, address(this));
        TierEngine snapshotTiers =
            new TierEngine(sponsors, TierEngine.VolumeBase.TOTAL_POSITION_VALUE, address(this));
        snapshotTiers.configureSnapshotRegistry(snapshots);
        DifferentialRewardEngine snapshotEngine =
            new DifferentialRewardEngine(usdt, treasury, sponsors, snapshotTiers, address(this));
        snapshotEngine.grantRole(snapshotEngine.POOL_ROLE(), address(this));
        vm.prank(treasury);
        usdt.approve(address(snapshotEngine), type(uint256).max);

        vm.prank(v5);
        sponsors.bindSponsor(v4);
        vm.prank(v4);
        sponsors.bindSponsor(v9);
        vm.prank(contributor);
        sponsors.bindSponsor(v5);
        _activateSnapshotTier(snapshots, 1, 101, v5, 5);
        _activateSnapshotTier(snapshots, 2, 102, v4, 4);
        _activateSnapshotTier(snapshots, 3, 103, v9, 9);
        assertEq(snapshotTiers.tierOf(v5), 5);
        assertEq(snapshotTiers.tierOf(v4), 4);
        assertEq(snapshotTiers.tierOf(v9), 9);

        snapshotEngine.distribute(999, contributor, 100 ether);
        assertEq(usdt.balanceOf(v5), 6 ether);
        assertEq(usdt.balanceOf(v4), 0);
        assertEq(usdt.balanceOf(v9), 4 ether);
        assertEq(snapshotEngine.totalDifferentialPaid(999), 10 ether);
    }

    function _activateSnapshotTier(
        TierSnapshotRegistry snapshots,
        uint64 snapshotId,
        uint64 snapshotBlock,
        address wallet,
        uint8 tier
    ) private {
        bytes32 leaf = keccak256(
            abi.encode(snapshotId, snapshotBlock, wallet, 0, address(0), 0, 0, tier)
        );
        snapshots.publish(
            snapshotId,
            snapshotBlock,
            leaf,
            keccak256(abi.encode(snapshotId)),
            snapshots.TIER_RULES_V1_HASH()
        );
        snapshots.finalize(snapshotId);
        snapshots.activateUserTier(snapshotId, wallet, 0, address(0), 0, 0, tier, new bytes32[](0));
    }
}

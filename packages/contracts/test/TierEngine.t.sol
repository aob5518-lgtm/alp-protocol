// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { SponsorRegistry } from "../src/SponsorRegistry.sol";
import { TierEngine } from "../src/TierEngine.sol";
import { TierSnapshotRegistry } from "../src/TierSnapshotRegistry.sol";

contract TierEngineTest is Test {
    SponsorRegistry internal sponsors;
    TierEngine internal tiers;
    address internal root = makeAddr("root");
    address internal branchA = makeAddr("branchA");
    address internal branchB = makeAddr("branchB");

    function setUp() public {
        sponsors = new SponsorRegistry(address(this));
        tiers = new TierEngine(sponsors, TierEngine.VolumeBase.USDT_CONTRIBUTION, address(this));
        sponsors.grantRole(sponsors.POOL_ROLE(), address(this));
        tiers.grantRole(tiers.POOL_ROLE(), address(this));
        vm.prank(branchA);
        sponsors.bindSponsor(root);
        vm.prank(branchB);
        sponsors.bindSponsor(root);
    }

    function testSmallDistrictExcludesLargestDirectBranchAndUnlocksTier() public {
        tiers.recordPosition(branchA, 4_000 ether, 8_000 ether);
        tiers.recordPosition(branchB, 3_000 ether, 6_000 ether);
        assertEq(tiers.totalNetworkVolume(root), 7_000 ether);
        assertEq(tiers.largestDirectBranchVolume(root), 4_000 ether);
        assertEq(tiers.smallDistrictVolumeOf(root), 3_000 ether);
        assertEq(tiers.tierOf(root), 1);
        TierEngine.TierDefinition memory definition = tiers.tierDefinition(1);
        assertEq(definition.requiredSmallDistrictVolume, 3_000 ether);
        assertEq(definition.rewardBps, 200);
    }

    function testTotalPositionValueStrategyCanBeSelectedForNewEngine() public {
        TierEngine totalValueTiers =
            new TierEngine(sponsors, TierEngine.VolumeBase.TOTAL_POSITION_VALUE, address(this));
        totalValueTiers.grantRole(totalValueTiers.POOL_ROLE(), address(this));
        totalValueTiers.recordPosition(branchA, 500 ether, 1_000 ether);
        assertEq(totalValueTiers.totalNetworkVolume(root), 1_000 ether);
    }

    function testSnapshotAuthorityDisablesLegacyTwentyHopAccumulator() public {
        TierSnapshotRegistry snapshots = new TierSnapshotRegistry(0, address(this));
        tiers.configureSnapshotRegistry(snapshots);

        tiers.recordPosition(branchA, 500 ether, 1_000 ether);

        assertEq(tiers.totalNetworkVolume(root), 0);
        assertEq(tiers.largestDirectBranchVolume(root), 0);
    }

    function testSnapshotRegistryCannotBeReplaced() public {
        tiers.configureSnapshotRegistry(new TierSnapshotRegistry(0, address(this)));
        vm.expectRevert(TierEngine.SnapshotRegistryAlreadyConfigured.selector);
        tiers.configureSnapshotRegistry(new TierSnapshotRegistry(0, address(this)));
    }
}

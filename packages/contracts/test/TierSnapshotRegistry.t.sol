// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { TierSnapshotRegistry } from "../src/TierSnapshotRegistry.sol";

contract TierSnapshotRegistryTest is Test {
    TierSnapshotRegistry internal registry;
    address internal user = makeAddr("user");

    function setUp() public {
        registry = new TierSnapshotRegistry(30 minutes, address(this));
    }

    function testFinalizedSnapshotActivatesMerkleVerifiedTier() public {
        uint64 id = 1;
        uint64 blockNumber = 123;
        uint256 total = 20_000 ether;
        uint256 largest = 8_000 ether;
        uint256 small = 12_000 ether;
        uint8 tier = 2;
        bytes32 leaf =
            keccak256(abi.encode(id, blockNumber, user, total, address(0), largest, small, tier));
        registry.publish(id, blockNumber, leaf, keccak256("dataset"), registry.TIER_RULES_V1_HASH());
        vm.warp(block.timestamp + 30 minutes);
        registry.finalize(id);
        registry.activateUserTier(
            id, user, total, address(0), largest, small, tier, new bytes32[](0)
        );
        assertEq(registry.currentTier(user), tier);
    }

    function testSameSnapshotBlockCannotHaveTwoRoots() public {
        bytes32 rulesHash = registry.TIER_RULES_V1_HASH();
        registry.publish(1, 123, keccak256("one"), keccak256("dataset"), rulesHash);
        vm.expectRevert(TierSnapshotRegistry.InvalidSnapshot.selector);
        registry.publish(2, 123, keccak256("two"), keccak256("dataset2"), rulesHash);
    }

    function testNewFinalizedSnapshotDoesNotResetPreviouslyVerifiedTier() public {
        uint64 id = 1;
        uint64 blockNumber = 123;
        uint8 tier = 2;
        bytes32 leaf = keccak256(
            abi.encode(
                id, blockNumber, user, 20_000 ether, address(0), 8_000 ether, 12_000 ether, tier
            )
        );
        registry.publish(id, blockNumber, leaf, keccak256("dataset"), registry.TIER_RULES_V1_HASH());
        vm.warp(block.timestamp + 30 minutes + 1);
        registry.finalize(id);
        registry.activateUserTier(
            id, user, 20_000 ether, address(0), 8_000 ether, 12_000 ether, tier, new bytes32[](0)
        );

        registry.publish(
            2, 124, keccak256("new-root"), keccak256("dataset2"), registry.TIER_RULES_V1_HASH()
        );
        vm.warp(block.timestamp + 60 minutes + 2);
        registry.finalize(2);
        assertEq(registry.currentTier(user), tier);
    }

    function testTierOnlyUpgrades() public {
        uint64 id = 1;
        uint8 tier = 2;
        bytes32 leaf = keccak256(
            abi.encode(
                id, uint64(123), user, 20_000 ether, address(0), 8_000 ether, 12_000 ether, tier
            )
        );
        registry.publish(id, 123, leaf, keccak256("dataset"), registry.TIER_RULES_V1_HASH());
        vm.warp(block.timestamp + 30 minutes);
        registry.finalize(id);
        registry.activateUserTier(
            id, user, 20_000 ether, address(0), 8_000 ether, 12_000 ether, tier, new bytes32[](0)
        );
        vm.expectRevert(TierSnapshotRegistry.TierNotUpgrade.selector);
        registry.activateUserTier(
            id, user, 20_000 ether, address(0), 8_000 ether, 12_000 ether, tier, new bytes32[](0)
        );
    }

    function testCannotFinalizeOlderSnapshotAfterNewerSnapshot() public {
        registry.publish(
            1, 123, keccak256("one"), keccak256("dataset"), registry.TIER_RULES_V1_HASH()
        );
        registry.publish(
            2, 124, keccak256("two"), keccak256("dataset2"), registry.TIER_RULES_V1_HASH()
        );
        vm.warp(block.timestamp + 30 minutes);
        registry.finalize(2);
        vm.expectRevert(TierSnapshotRegistry.SnapshotNotIncreasing.selector);
        registry.finalize(1);
    }

    function testRejectsUnapprovedTierRules() public {
        vm.expectRevert(TierSnapshotRegistry.InvalidTierRules.selector);
        registry.publish(1, 123, keccak256("one"), keccak256("dataset"), keccak256("wrong-rules"));
    }
}

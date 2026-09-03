// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {TierSnapshotRegistry} from "../src/TierSnapshotRegistry.sol";

contract TierSnapshotRegistryTest is Test {
    TierSnapshotRegistry internal registry;
    address internal user = makeAddr("user");
    function setUp() public { registry = new TierSnapshotRegistry(30 minutes, address(this)); }
    function testFinalizedSnapshotActivatesMerkleVerifiedTier() public {
        uint64 id = 1; uint64 blockNumber = 123; uint256 total = 20_000 ether; uint256 largest = 8_000 ether; uint256 small = 12_000 ether; uint8 tier = 2;
        bytes32 leaf = keccak256(abi.encode(id, blockNumber, user, total, address(0), largest, small, tier));
        registry.publish(id, blockNumber, leaf, keccak256("dataset"));
        vm.warp(block.timestamp + 30 minutes); registry.finalize(id);
        registry.activateUserTier(id, user, total, address(0), largest, small, tier, new bytes32[](0));
        assertEq(registry.currentTier(user), tier);
    }
    function testSameSnapshotBlockCannotHaveTwoRoots() public {
        registry.publish(1, 123, keccak256("one"), keccak256("dataset"));
        vm.expectRevert(TierSnapshotRegistry.InvalidSnapshot.selector);
        registry.publish(2, 123, keccak256("two"), keccak256("dataset2"));
    }
}

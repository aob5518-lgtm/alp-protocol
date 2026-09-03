// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {Top100Distributor} from "../src/Top100Distributor.sol";

contract Top100DistributorTest is Test {
    address internal treasury = makeAddr("top100Treasury");
    address internal winner = makeAddr("winner");
    MockERC20 internal usdt;
    Top100Distributor internal distributor;

    function setUp() public {
        usdt = new MockERC20("USDT", "USDT", 18);
        distributor = new Top100Distributor(usdt, treasury, address(this));
        distributor.grantRole(distributor.ROOT_MANAGER_ROLE(), address(this));
        usdt.mint(treasury, 100 ether);
        vm.prank(treasury);
        usdt.approve(address(distributor), type(uint256).max);
    }

    function testClaimUsesRankAndComputeSnapshotLeaf() public {
        uint256 epochId = 12;
        uint8 rank = 1;
        uint256 compute = 500_000 ether;
        uint256 amount = 10 ether;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(epochId, rank, winner, compute, amount))));
        distributor.submitRoot(epochId, leaf, uint64(block.number), uint128(amount));
        bytes32[] memory emptyProof;
        vm.prank(winner);
        distributor.claim(epochId, rank, compute, amount, emptyProof);
        assertEq(usdt.balanceOf(winner), amount);
        assertTrue(distributor.claimed(epochId, winner));
    }

    function testInvalidRankAndDuplicateClaimAreRejected() public {
        vm.prank(winner);
        vm.expectRevert(abi.encodeWithSelector(Top100Distributor.InvalidRank.selector, 101));
        distributor.claim(1, 101, 0, 0, new bytes32[](0));

        uint256 epochId = 13;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(epochId, 100, winner, 1 ether, 1 ether))));
        distributor.submitRoot(epochId, leaf, uint64(block.number), uint128(1 ether));
        bytes32[] memory emptyProof;
        vm.startPrank(winner);
        distributor.claim(epochId, 100, 1 ether, 1 ether, emptyProof);
        vm.expectRevert(abi.encodeWithSelector(Top100Distributor.AlreadyClaimed.selector, epochId, winner));
        distributor.claim(epochId, 100, 1 ether, 1 ether, emptyProof);
        vm.stopPrank();
    }

    function testEpochClaimsCannotExceedCommittedSnapshotTotal() public {
        uint256 epochId = 14;
        uint256 amount = 25 ether;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(epochId, 1, winner, 1 ether, amount))));
        distributor.submitRoot(epochId, leaf, uint64(block.number), uint128(20 ether));
        vm.prank(winner);
        vm.expectRevert(
            abi.encodeWithSelector(Top100Distributor.EpochAllocationExceeded.selector, epochId, amount, 20 ether)
        );
        distributor.claim(epochId, 1, 1 ether, amount, new bytes32[](0));
    }
}

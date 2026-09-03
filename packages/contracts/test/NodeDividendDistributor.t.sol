// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { NodeRegistry } from "../src/NodeRegistry.sol";
import { NodeDividendDistributor } from "../src/NodeDividendDistributor.sol";

contract NodeDividendDistributorTest is Test {
    address internal treasury = makeAddr("nodeTreasury");
    address internal owner = makeAddr("nodeOwner");
    MockERC20 internal usdt;
    NodeRegistry internal nodes;
    NodeDividendDistributor internal distributor;
    uint256 internal nodeId;

    function setUp() public {
        usdt = new MockERC20("USDT", "USDT", 18);
        nodes = new NodeRegistry(address(this));
        nodes.grantRole(nodes.NODE_OPERATOR_ROLE(), address(this));
        nodeId = nodes.createNode(owner, NodeRegistry.NodeType.BIG, 100, bytes32("APAC"));
        distributor = new NodeDividendDistributor(usdt, treasury, nodes, address(this));
        distributor.grantRole(distributor.ROOT_MANAGER_ROLE(), address(this));
        usdt.mint(treasury, 100 ether);
        vm.prank(treasury);
        usdt.approve(address(distributor), type(uint256).max);
    }

    function testSnapshotRootPaysNodeOwnerOnce() public {
        uint256 epochId = 7;
        uint256 amount = 12 ether;
        bytes32 leaf =
            keccak256(bytes.concat(keccak256(abi.encode(epochId, nodeId, owner, amount))));
        distributor.submitRoot(epochId, leaf, uint64(block.number), uint128(amount));
        bytes32[] memory emptyProof;
        vm.prank(owner);
        distributor.claim(epochId, nodeId, amount, emptyProof);
        assertEq(usdt.balanceOf(owner), amount);
        assertTrue(distributor.claimed(epochId, nodeId));
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(NodeDividendDistributor.AlreadyClaimed.selector, epochId, nodeId)
        );
        distributor.claim(epochId, nodeId, amount, emptyProof);
    }

    function testOnlyCurrentNodeOwnerCanClaim() public {
        uint256 epochId = 8;
        uint256 amount = 1 ether;
        bytes32 leaf =
            keccak256(bytes.concat(keccak256(abi.encode(epochId, nodeId, owner, amount))));
        distributor.submitRoot(epochId, leaf, uint64(block.number), uint128(amount));
        bytes32[] memory emptyProof;
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(NodeDividendDistributor.NotNodeOwner.selector, stranger, nodeId)
        );
        distributor.claim(epochId, nodeId, amount, emptyProof);
    }

    function testEpochClaimsCannotExceedCommittedSnapshotTotal() public {
        uint256 epochId = 9;
        uint256 amount = 25 ether;
        bytes32 leaf =
            keccak256(bytes.concat(keccak256(abi.encode(epochId, nodeId, owner, amount))));
        distributor.submitRoot(epochId, leaf, uint64(block.number), uint128(20 ether));
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                NodeDividendDistributor.EpochAllocationExceeded.selector, epochId, amount, 20 ether
            )
        );
        distributor.claim(epochId, nodeId, amount, new bytes32[](0));
    }
}

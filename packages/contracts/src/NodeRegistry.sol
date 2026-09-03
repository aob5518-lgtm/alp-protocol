// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Governance-operated registry for Small and Big Launch Nodes. It has no custody capability.
contract NodeRegistry is AccessControl {
    error ZeroAddress();
    error InvalidWeight();
    error NodeNotFound(uint256 nodeId);

    bytes32 public constant NODE_OPERATOR_ROLE = keccak256("NODE_OPERATOR_ROLE");

    enum NodeType {
        SMALL,
        BIG
    }
    enum NodeStatus {
        ACTIVE,
        PAUSED,
        CLOSED
    }

    struct Node {
        address owner;
        NodeType nodeType;
        uint128 weight;
        bytes32 region;
        NodeStatus status;
        uint64 createdAt;
    }

    uint256 public nextNodeId = 1;
    mapping(uint256 => Node) private _nodes;

    event NodeCreated(
        uint256 indexed nodeId,
        address indexed owner,
        NodeType indexed nodeType,
        uint256 weight,
        bytes32 region
    );
    event NodeStatusUpdated(uint256 indexed nodeId, NodeStatus status);

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function createNode(address owner, NodeType nodeType, uint128 weight, bytes32 region)
        external
        onlyRole(NODE_OPERATOR_ROLE)
        returns (uint256 nodeId)
    {
        if (owner == address(0)) revert ZeroAddress();
        if (weight == 0) revert InvalidWeight();
        nodeId = nextNodeId++;
        _nodes[nodeId] = Node({
            owner: owner,
            nodeType: nodeType,
            weight: weight,
            region: region,
            status: NodeStatus.ACTIVE,
            createdAt: uint64(block.timestamp)
        });
        emit NodeCreated(nodeId, owner, nodeType, weight, region);
    }

    function setNodeStatus(uint256 nodeId, NodeStatus status)
        external
        onlyRole(NODE_OPERATOR_ROLE)
    {
        if (_nodes[nodeId].owner == address(0)) {
            revert NodeNotFound(nodeId);
        }
        _nodes[nodeId].status = status;
        emit NodeStatusUpdated(nodeId, status);
    }

    function node(uint256 nodeId) external view returns (Node memory) {
        Node memory item = _nodes[nodeId];
        if (item.owner == address(0)) revert NodeNotFound(nodeId);
        return item;
    }
}

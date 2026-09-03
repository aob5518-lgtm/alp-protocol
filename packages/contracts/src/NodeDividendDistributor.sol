// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {NodeRegistry} from "./NodeRegistry.sol";

/// @notice Claims node dividends from an independently funded treasury using auditable snapshot roots.
contract NodeDividendDistributor is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error RootAlreadySubmitted(uint256 epochId);
    error RootNotFound(uint256 epochId);
    error AlreadyClaimed(uint256 epochId, uint256 nodeId);
    error NotNodeOwner(address caller, uint256 nodeId);
    error InvalidProof();
    error EpochAllocationExceeded(uint256 epochId, uint256 requested, uint256 remaining);

    bytes32 public constant ROOT_MANAGER_ROLE = keccak256("ROOT_MANAGER_ROLE");

    struct RootSnapshot {
        bytes32 merkleRoot;
        uint64 snapshotBlock;
        uint128 totalAmount;
    }

    IERC20 public immutable rewardToken;
    address public immutable nodeDividendTreasury;
    NodeRegistry public immutable nodeRegistry;
    mapping(uint256 => RootSnapshot) public rootForEpoch;
    mapping(uint256 => mapping(uint256 => bool)) public claimed;
    mapping(uint256 => uint256) public totalClaimedForEpoch;

    event RootSubmitted(uint256 indexed epochId, bytes32 indexed root, uint64 snapshotBlock, uint256 totalAmount);
    event NodeDividendClaimed(uint256 indexed epochId, uint256 indexed nodeId, address indexed owner, uint256 amount);

    constructor(IERC20 rewardToken_, address nodeDividendTreasury_, NodeRegistry nodeRegistry_, address admin) {
        if (address(rewardToken_) == address(0) || nodeDividendTreasury_ == address(0) || address(nodeRegistry_) == address(0) || admin == address(0)) {
            revert ZeroAddress();
        }
        rewardToken = rewardToken_;
        nodeDividendTreasury = nodeDividendTreasury_;
        nodeRegistry = nodeRegistry_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function submitRoot(uint256 epochId, bytes32 merkleRoot, uint64 snapshotBlock, uint128 totalAmount)
        external
        onlyRole(ROOT_MANAGER_ROLE)
    {
        if (merkleRoot == bytes32(0)) revert ZeroAddress();
        if (rootForEpoch[epochId].merkleRoot != bytes32(0)) revert RootAlreadySubmitted(epochId);
        rootForEpoch[epochId] = RootSnapshot({merkleRoot: merkleRoot, snapshotBlock: snapshotBlock, totalAmount: totalAmount});
        emit RootSubmitted(epochId, merkleRoot, snapshotBlock, totalAmount);
    }

    function claim(uint256 epochId, uint256 nodeId, uint256 amount, bytes32[] calldata proof) external nonReentrant {
        RootSnapshot memory snapshot = rootForEpoch[epochId];
        if (snapshot.merkleRoot == bytes32(0)) revert RootNotFound(epochId);
        if (claimed[epochId][nodeId]) revert AlreadyClaimed(epochId, nodeId);
        NodeRegistry.Node memory item = nodeRegistry.node(nodeId);
        if (item.owner != msg.sender) revert NotNodeOwner(msg.sender, nodeId);
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(epochId, nodeId, msg.sender, amount))));
        if (!MerkleProof.verifyCalldata(proof, snapshot.merkleRoot, leaf)) revert InvalidProof();
        uint256 claimedAfter = totalClaimedForEpoch[epochId] + amount;
        if (claimedAfter > snapshot.totalAmount) {
            revert EpochAllocationExceeded(epochId, amount, snapshot.totalAmount - totalClaimedForEpoch[epochId]);
        }
        claimed[epochId][nodeId] = true;
        totalClaimedForEpoch[epochId] = claimedAfter;
        rewardToken.safeTransferFrom(nodeDividendTreasury, msg.sender, amount);
        emit NodeDividendClaimed(epochId, nodeId, msg.sender, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @notice Trust-minimised publication point for off-chain, unlimited-depth sponsor-tree snapshots.
/// @dev The indexer computes from immutable chain events. A user tier is activated only with a proof
/// against the finalised root, so PostgreSQL is never a source of on-chain truth.
contract TierSnapshotRegistry is AccessControl {
    error ZeroAddress();
    error InvalidSnapshot();
    error NotReady();
    error AlreadyActiveForBlock();
    error InvalidProof();
    bytes32 public constant SNAPSHOT_PUBLISHER_ROLE = keccak256("SNAPSHOT_PUBLISHER_ROLE");

    struct Snapshot {
        uint64 snapshotBlock;
        bytes32 root;
        bytes32 datasetHash;
        uint64 validFrom;
        uint64 finalizedAt;
        address publisher;
        bool finalized;
    }

    struct UserTier {
        uint64 snapshotId;
        uint8 tier;
        uint256 totalNetworkVolume;
        uint256 largestBranchVolume;
        uint256 smallDistrictVolume;
    }
    uint64 public immutable minimumActivationDelay;
    uint64 public latestFinalizedSnapshotId;
    mapping(uint64 => Snapshot) public snapshots;
    mapping(uint64 => bool) public activeBlockUsed;
    mapping(address => UserTier) public userTier;
    event SnapshotPublished(
        uint64 indexed snapshotId,
        uint64 indexed snapshotBlock,
        bytes32 root,
        bytes32 datasetHash,
        uint64 validFrom,
        address publisher
    );
    event SnapshotFinalized(uint64 indexed snapshotId);
    event UserTierActivated(
        uint64 indexed snapshotId, address indexed wallet, uint8 tier, uint256 smallDistrictVolume
    );

    constructor(uint64 minimumActivationDelay_, address admin) {
        if (admin == address(0)) revert ZeroAddress();
        minimumActivationDelay = minimumActivationDelay_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SNAPSHOT_PUBLISHER_ROLE, admin);
    }

    function publish(uint64 snapshotId, uint64 snapshotBlock, bytes32 root, bytes32 datasetHash)
        external
        onlyRole(SNAPSHOT_PUBLISHER_ROLE)
    {
        if (
            snapshotId == 0 || root == bytes32(0) || snapshots[snapshotId].publisher != address(0)
                || activeBlockUsed[snapshotBlock]
        ) revert InvalidSnapshot();
        uint64 validFrom = uint64(block.timestamp) + minimumActivationDelay;
        snapshots[snapshotId] =
            Snapshot(snapshotBlock, root, datasetHash, validFrom, 0, msg.sender, false);
        activeBlockUsed[snapshotBlock] = true;
        emit SnapshotPublished(snapshotId, snapshotBlock, root, datasetHash, validFrom, msg.sender);
    }

    function finalize(uint64 snapshotId) external {
        Snapshot storage snapshot = snapshots[snapshotId];
        if (snapshot.publisher == address(0) || snapshot.finalized) revert InvalidSnapshot();
        if (block.timestamp < snapshot.validFrom) revert NotReady();
        snapshot.finalized = true;
        snapshot.finalizedAt = uint64(block.timestamp);
        latestFinalizedSnapshotId = snapshotId;
        emit SnapshotFinalized(snapshotId);
    }

    function activateUserTier(
        uint64 snapshotId,
        address wallet,
        uint256 totalNetworkVolume,
        address largestBranch,
        uint256 largestBranchVolume,
        uint256 smallDistrictVolume,
        uint8 tier,
        bytes32[] calldata proof
    ) external {
        Snapshot storage snapshot = snapshots[snapshotId];
        if (!snapshot.finalized || tier > 9) revert InvalidSnapshot();
        bytes32 leaf = keccak256(
            abi.encode(
                snapshotId,
                snapshot.snapshotBlock,
                wallet,
                totalNetworkVolume,
                largestBranch,
                largestBranchVolume,
                smallDistrictVolume,
                tier
            )
        );
        if (!MerkleProof.verify(proof, snapshot.root, leaf)) revert InvalidProof();
        userTier[wallet] = UserTier(
            snapshotId, tier, totalNetworkVolume, largestBranchVolume, smallDistrictVolume
        );
        emit UserTierActivated(snapshotId, wallet, tier, smallDistrictVolume);
    }

    function currentTier(address wallet) external view returns (uint8) {
        UserTier memory value = userTier[wallet];
        return value.snapshotId == latestFinalizedSnapshotId ? value.tier : 0;
    }
}

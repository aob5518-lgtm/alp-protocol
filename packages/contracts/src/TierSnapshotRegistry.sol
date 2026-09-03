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
    error InvalidTierRules();
    error SnapshotNotIncreasing();
    error TierNotUpgrade();
    bytes32 public constant SNAPSHOT_PUBLISHER_ROLE = keccak256("SNAPSHOT_PUBLISHER_ROLE");
    /// @notice Immutable V1 tier economics accepted by this registry.
    bytes32 public constant TIER_RULES_V1_HASH = keccak256(
        "ALP_TIER_V1|TOTAL_POSITION_VALUE|UNLIMITED_DEPTH|3000:2|10000:3|30000:4|100000:5|300000:6|1000000:7|3000000:8|6000000:9|10000000:10"
    );

    struct Snapshot {
        uint64 snapshotBlock;
        bytes32 root;
        bytes32 datasetHash;
        bytes32 tierRulesHash;
        uint64 validFrom;
        uint64 finalizedAt;
        address publisher;
        bool finalized;
    }

    struct VerifiedTier {
        uint64 lastTierSnapshot;
        uint256 totalNetworkVolume;
        uint256 largestBranchVolume;
        uint256 smallDistrictVolume;
    }
    uint64 public immutable minimumActivationDelay;
    uint64 public latestFinalizedSnapshotId;
    uint64 public latestFinalizedSnapshotBlock;
    mapping(uint64 => Snapshot) public snapshots;
    mapping(uint64 => bool) public activeBlockUsed;
    mapping(address => uint8) public verifiedTier;
    mapping(address => VerifiedTier) public userTier;
    event SnapshotPublished(
        uint64 indexed snapshotId,
        uint64 indexed snapshotBlock,
        bytes32 root,
        bytes32 datasetHash,
        bytes32 tierRulesHash,
        uint64 validFrom,
        address publisher
    );
    event SnapshotFinalized(uint64 indexed snapshotId, uint64 indexed snapshotBlock);
    event UserTierActivated(
        uint64 indexed snapshotId, address indexed wallet, uint8 tier, uint256 smallDistrictVolume
    );

    constructor(uint64 minimumActivationDelay_, address admin) {
        if (admin == address(0)) revert ZeroAddress();
        minimumActivationDelay = minimumActivationDelay_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SNAPSHOT_PUBLISHER_ROLE, admin);
    }

    function publish(
        uint64 snapshotId,
        uint64 snapshotBlock,
        bytes32 root,
        bytes32 datasetHash,
        bytes32 tierRulesHash
    ) external onlyRole(SNAPSHOT_PUBLISHER_ROLE) {
        if (
            snapshotId == 0 || root == bytes32(0) || snapshots[snapshotId].publisher != address(0)
                || activeBlockUsed[snapshotBlock]
        ) revert InvalidSnapshot();
        if (tierRulesHash != TIER_RULES_V1_HASH) revert InvalidTierRules();
        uint64 validFrom = uint64(block.timestamp) + minimumActivationDelay;
        snapshots[snapshotId] = Snapshot(
            snapshotBlock, root, datasetHash, tierRulesHash, validFrom, 0, msg.sender, false
        );
        activeBlockUsed[snapshotBlock] = true;
        emit SnapshotPublished(
            snapshotId, snapshotBlock, root, datasetHash, tierRulesHash, validFrom, msg.sender
        );
    }

    function finalize(uint64 snapshotId) external {
        Snapshot storage snapshot = snapshots[snapshotId];
        if (snapshot.publisher == address(0) || snapshot.finalized) revert InvalidSnapshot();
        if (block.timestamp < snapshot.validFrom) revert NotReady();
        if (
            snapshotId <= latestFinalizedSnapshotId
                || snapshot.snapshotBlock <= latestFinalizedSnapshotBlock
        ) revert SnapshotNotIncreasing();
        snapshot.finalized = true;
        snapshot.finalizedAt = uint64(block.timestamp);
        latestFinalizedSnapshotId = snapshotId;
        latestFinalizedSnapshotBlock = snapshot.snapshotBlock;
        emit SnapshotFinalized(snapshotId, snapshot.snapshotBlock);
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
        if (tier <= verifiedTier[wallet]) revert TierNotUpgrade();
        verifiedTier[wallet] = tier;
        userTier[wallet] = VerifiedTier(
            snapshotId, totalNetworkVolume, largestBranchVolume, smallDistrictVolume
        );
        emit UserTierActivated(snapshotId, wallet, tier, smallDistrictVolume);
    }

    function currentTier(address wallet) external view returns (uint8) {
        return verifiedTier[wallet];
    }
}

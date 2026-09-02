// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Claim contract for the 1% sell-fee Top100 treasury.
/// @dev Ranking/weighting remains an indexer strategy; its selected block and root are immutable per epoch.
contract Top100Distributor is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error RootAlreadySubmitted(uint256 epochId);
    error RootNotFound(uint256 epochId);
    error AlreadyClaimed(uint256 epochId, address account);
    error InvalidProof();
    error InvalidRank(uint8 rank);

    bytes32 public constant ROOT_MANAGER_ROLE = keccak256("ROOT_MANAGER_ROLE");
    uint8 public constant MAX_RANK = 100;

    struct RootSnapshot {
        bytes32 merkleRoot;
        uint64 snapshotBlock;
        uint128 totalAmount;
    }

    IERC20 public immutable rewardToken;
    address public immutable top100Treasury;
    mapping(uint256 => RootSnapshot) public rootForEpoch;
    mapping(uint256 => mapping(address => bool)) public claimed;

    event RootSubmitted(uint256 indexed epochId, bytes32 indexed root, uint64 snapshotBlock, uint256 totalAmount);
    event Top100RewardClaimed(
        uint256 indexed epochId, address indexed account, uint8 indexed rank, uint256 effectiveCompute, uint256 amount
    );

    constructor(IERC20 rewardToken_, address top100Treasury_, address admin) {
        if (address(rewardToken_) == address(0) || top100Treasury_ == address(0) || admin == address(0)) revert ZeroAddress();
        rewardToken = rewardToken_;
        top100Treasury = top100Treasury_;
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

    /// @notice Claim a snapshot allocation. The leaf carries the rank and compute for public auditability.
    function claim(uint256 epochId, uint8 rank, uint256 effectiveCompute, uint256 amount, bytes32[] calldata proof)
        external
        nonReentrant
    {
        if (rank == 0 || rank > MAX_RANK) revert InvalidRank(rank);
        RootSnapshot memory snapshot = rootForEpoch[epochId];
        if (snapshot.merkleRoot == bytes32(0)) revert RootNotFound(epochId);
        if (claimed[epochId][msg.sender]) revert AlreadyClaimed(epochId, msg.sender);
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(epochId, rank, msg.sender, effectiveCompute, amount))));
        if (!MerkleProof.verifyCalldata(proof, snapshot.merkleRoot, leaf)) revert InvalidProof();
        claimed[epochId][msg.sender] = true;
        rewardToken.safeTransferFrom(top100Treasury, msg.sender, amount);
        emit Top100RewardClaimed(epochId, msg.sender, rank, effectiveCompute, amount);
    }
}

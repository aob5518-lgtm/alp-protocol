// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SponsorRegistry } from "./SponsorRegistry.sol";
import { ITierEngine } from "./interfaces/ITierEngine.sol";
import { TierSnapshotRegistry } from "./TierSnapshotRegistry.sol";

/// @notice Maintains 20-level referral-tree volume without unbounded traversal or database trust.
contract TierEngine is AccessControl, ITierEngine {
    error ZeroAddress();
    error InvalidVolume();

    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    bytes32 public constant POOL_FACTORY_ROLE = keccak256("POOL_FACTORY_ROLE");
    uint8 public constant MAX_DEPTH = 20;

    enum VolumeBase {
        USDT_CONTRIBUTION,
        TOTAL_POSITION_VALUE
    }

    struct TierDefinition {
        uint128 requiredSmallDistrictVolume;
        uint16 rewardBps;
    }

    SponsorRegistry public immutable sponsorRegistry;
    VolumeBase public immutable volumeBase;
    TierSnapshotRegistry public snapshotRegistry;
    mapping(address => uint256) public totalNetworkVolume;
    mapping(address => uint256) public largestDirectBranchVolume;
    mapping(address => address) public largestDirectBranch;
    mapping(address => mapping(address => uint256)) public directBranchVolume;

    event NetworkVolumeRecorded(address indexed user, uint256 volume, uint8 traversedLevels);
    event SnapshotAuthorityUsed(address indexed user, uint256 totalPositionValue);
    event TierUpdated(
        address indexed user,
        uint8 previousTier,
        uint8 newTier,
        uint256 smallDistrictVolume,
        uint256 totalNetworkVolume,
        address largestDirectBranch
    );

    constructor(SponsorRegistry sponsorRegistry_, VolumeBase volumeBase_, address admin) {
        if (address(sponsorRegistry_) == address(0) || admin == address(0)) revert ZeroAddress();
        sponsorRegistry = sponsorRegistry_;
        volumeBase = volumeBase_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Enables the unlimited-depth, indexer-generated, Merkle-verified V1-V9 authority.
    function configureSnapshotRegistry(TierSnapshotRegistry registry)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (address(registry) == address(0)) revert ZeroAddress();
        snapshotRegistry = registry;
    }

    function registerPool(address pool) external onlyRole(POOL_FACTORY_ROLE) {
        if (pool == address(0)) revert ZeroAddress();
        _grantRole(POOL_ROLE, pool);
    }

    function recordPosition(address user, uint256 usdtContribution, uint256 totalPositionValue)
        external
        override
        onlyRole(POOL_ROLE)
    {
        // V1 production tiers are computed off-chain over the full sponsor graph
        // and committed through TierSnapshotRegistry. Retaining this legacy
        // 20-hop accumulator after that authority is configured would create a
        // second, incomplete source of truth while also risking Position reverts.
        if (address(snapshotRegistry) != address(0)) {
            emit SnapshotAuthorityUsed(user, totalPositionValue);
            return;
        }
        uint256 volume =
            volumeBase == VolumeBase.USDT_CONTRIBUTION ? usdtContribution : totalPositionValue;
        if (volume == 0) revert InvalidVolume();
        address directBranch = user;
        address cursor = user;
        for (uint8 depth; depth < MAX_DEPTH; ++depth) {
            address upline = sponsorRegistry.sponsorOf(cursor);
            if (upline == address(0)) {
                emit NetworkVolumeRecorded(user, volume, depth);
                return;
            }
            uint8 previousTier = tierOf(upline);
            totalNetworkVolume[upline] += volume;
            uint256 newBranchVolume = directBranchVolume[upline][directBranch] + volume;
            directBranchVolume[upline][directBranch] = newBranchVolume;
            if (newBranchVolume > largestDirectBranchVolume[upline]) {
                largestDirectBranchVolume[upline] = newBranchVolume;
                largestDirectBranch[upline] = directBranch;
            }
            uint8 newTier = tierOf(upline);
            if (newTier != previousTier) {
                emit TierUpdated(
                    upline,
                    previousTier,
                    newTier,
                    smallDistrictVolumeOf(upline),
                    totalNetworkVolume[upline],
                    largestDirectBranch[upline]
                );
            }
            directBranch = upline;
            cursor = upline;
        }
        emit NetworkVolumeRecorded(user, volume, MAX_DEPTH);
    }

    function smallDistrictVolumeOf(address user) public view returns (uint256) {
        return totalNetworkVolume[user] - largestDirectBranchVolume[user];
    }

    function tierOf(address user) public view returns (uint8) {
        if (address(snapshotRegistry) != address(0)) return snapshotRegistry.currentTier(user);
        uint256 smallDistrictVolume = smallDistrictVolumeOf(user);
        for (uint8 tier = 9; tier != 0; --tier) {
            if (smallDistrictVolume >= tierDefinition(tier).requiredSmallDistrictVolume) {
                return tier;
            }
        }
        return 0;
    }

    function tierDefinition(uint8 tier) public pure returns (TierDefinition memory) {
        if (tier == 1) return TierDefinition(3_000 ether, 200);
        if (tier == 2) return TierDefinition(10_000 ether, 300);
        if (tier == 3) return TierDefinition(30_000 ether, 400);
        if (tier == 4) return TierDefinition(100_000 ether, 500);
        if (tier == 5) return TierDefinition(300_000 ether, 600);
        if (tier == 6) return TierDefinition(1_000_000 ether, 700);
        if (tier == 7) return TierDefinition(3_000_000 ether, 800);
        if (tier == 8) return TierDefinition(6_000_000 ether, 900);
        if (tier == 9) return TierDefinition(10_000_000 ether, 1_000);
        return TierDefinition(0, 0);
    }
}

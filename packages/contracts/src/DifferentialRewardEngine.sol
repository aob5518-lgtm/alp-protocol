// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SponsorRegistry} from "./SponsorRegistry.sol";
import {TierEngine} from "./TierEngine.sol";
import {IDifferentialRewardEngine} from "./interfaces/IDifferentialRewardEngine.sol";

/// @notice Pays the non-overlapping tier-rate delta along a referral path from the reward treasury.
contract DifferentialRewardEngine is AccessControl, ReentrancyGuard, IDifferentialRewardEngine {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error AlreadyProcessed(uint256 positionId);

    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    bytes32 public constant POOL_FACTORY_ROLE = keccak256("POOL_FACTORY_ROLE");
    uint8 public constant MAX_LEVELS = 20;
    uint16 public constant BPS_DENOMINATOR = 10_000;

    IERC20 public immutable rewardToken;
    address public immutable rewardTreasury;
    SponsorRegistry public immutable sponsorRegistry;
    TierEngine public immutable tierEngine;
    mapping(uint256 => bool) public processedPosition;

    event DifferentialRewardPaid(
        uint256 indexed positionId,
        address indexed beneficiary,
        uint8 indexed level,
        uint8 upperTier,
        uint8 lowerTier,
        uint16 differentialBps,
        uint256 amount
    );

    constructor(IERC20 rewardToken_, address rewardTreasury_, SponsorRegistry sponsorRegistry_, TierEngine tierEngine_, address admin) {
        if (
            address(rewardToken_) == address(0) || rewardTreasury_ == address(0) || address(sponsorRegistry_) == address(0)
                || address(tierEngine_) == address(0) || admin == address(0)
        ) revert ZeroAddress();
        rewardToken = rewardToken_;
        rewardTreasury = rewardTreasury_;
        sponsorRegistry = sponsorRegistry_;
        tierEngine = tierEngine_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerPool(address pool) external onlyRole(POOL_FACTORY_ROLE) {
        if (pool == address(0)) revert ZeroAddress();
        _grantRole(POOL_ROLE, pool);
    }

    function distribute(uint256 positionId, address user, uint256 rewardBase)
        external
        override
        onlyRole(POOL_ROLE)
        nonReentrant
    {
        if (processedPosition[positionId]) revert AlreadyProcessed(positionId);
        processedPosition[positionId] = true;
        address lower = user;
        address upper = sponsorRegistry.sponsorOf(lower);
        for (uint8 level = 1; level <= MAX_LEVELS && upper != address(0); ++level) {
            uint8 upperTier = tierEngine.tierOf(upper);
            uint8 lowerTier = tierEngine.tierOf(lower);
            uint16 upperRate = tierEngine.tierDefinition(upperTier).rewardBps;
            uint16 lowerRate = tierEngine.tierDefinition(lowerTier).rewardBps;
            uint16 differentialBps = upperRate > lowerRate ? upperRate - lowerRate : 0;
            if (differentialBps != 0) {
                uint256 amount = rewardBase * differentialBps / BPS_DENOMINATOR;
                if (amount != 0) rewardToken.safeTransferFrom(rewardTreasury, upper, amount);
                emit DifferentialRewardPaid(positionId, upper, level, upperTier, lowerTier, differentialBps, amount);
            }
            lower = upper;
            upper = sponsorRegistry.sponsorOf(upper);
        }
    }
}

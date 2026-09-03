// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SponsorRegistry } from "./SponsorRegistry.sol";
import { IGlobalComputeEngine } from "./interfaces/IGlobalComputeEngine.sol";

/// @notice Pays the immutable 20-level referral schedule from an explicitly funded reward treasury.
/// @dev The treasury must grant this contract a bounded allowance through the governing Safe/timelock.
contract ReferralRewardEngine is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error InvalidSplit(uint16 usdtBps, uint16 computeBps);
    error AlreadyProcessed(uint256 positionId);

    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    bytes32 public constant POOL_FACTORY_ROLE = keccak256("POOL_FACTORY_ROLE");
    bytes32 private constant REFERRAL_POSITION_NAMESPACE = keccak256("ALP_REFERRAL_COMPUTE");
    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint8 public constant MAX_LEVELS = 20;

    IERC20 public immutable rewardToken;
    address public immutable rewardTreasury;
    SponsorRegistry public immutable sponsorRegistry;
    IGlobalComputeEngine public immutable computeEngine;
    uint16 public rewardUsdtBps;
    uint16 public rewardComputeBps;
    bool public rewardSplitConfigured;
    mapping(uint256 => bool) public processedPosition;

    event RewardSplitConfigured(
        uint16 rewardUsdtBps, uint16 rewardComputeBps, bool productionReady
    );
    event ReferralRewardPaid(
        uint256 indexed referredPositionId,
        address indexed beneficiary,
        uint8 indexed level,
        uint256 usdtAmount,
        uint256 computeBoost
    );

    constructor(
        IERC20 rewardToken_,
        address rewardTreasury_,
        SponsorRegistry sponsorRegistry_,
        IGlobalComputeEngine computeEngine_,
        address admin,
        bool testnetDefaults
    ) {
        if (
            address(rewardToken_) == address(0) || rewardTreasury_ == address(0)
                || address(sponsorRegistry_) == address(0) || address(computeEngine_) == address(0)
                || admin == address(0)
        ) revert ZeroAddress();
        rewardToken = rewardToken_;
        rewardTreasury = rewardTreasury_;
        sponsorRegistry = sponsorRegistry_;
        computeEngine = computeEngine_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        if (testnetDefaults) {
            rewardUsdtBps = BPS_DENOMINATOR;
            rewardSplitConfigured = false;
            emit RewardSplitConfigured(BPS_DENOMINATOR, 0, false);
        }
    }

    /// @notice Governance must call this with the final production split before activation.
    function configureRewardSplit(uint16 usdtBps, uint16 computeBps)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (uint256(usdtBps) + computeBps != BPS_DENOMINATOR) {
            revert InvalidSplit(usdtBps, computeBps);
        }
        rewardUsdtBps = usdtBps;
        rewardComputeBps = computeBps;
        rewardSplitConfigured = true;
        emit RewardSplitConfigured(usdtBps, computeBps, true);
    }

    function registerPool(address pool) external onlyRole(POOL_FACTORY_ROLE) {
        if (pool == address(0)) revert ZeroAddress();
        _grantRole(POOL_ROLE, pool);
    }

    /// @param referredPositionId Globally unique position key, not a pool-local sequence number.
    /// @param referredUser The user who just created an active position.
    /// @param usdtContribution Value of the USDT leg in the reward token's native decimals.
    function distribute(uint256 referredPositionId, address referredUser, uint256 usdtContribution)
        external
        onlyRole(POOL_ROLE)
        nonReentrant
    {
        if (processedPosition[referredPositionId]) revert AlreadyProcessed(referredPositionId);
        processedPosition[referredPositionId] = true;
        address cursor = sponsorRegistry.sponsorOf(referredUser);
        for (uint8 level = 1; level <= MAX_LEVELS && cursor != address(0); ++level) {
            if (sponsorRegistry.activeDirectReferralCount(cursor) >= level) {
                uint256 grossReward = usdtContribution * _levelBps(level) / BPS_DENOMINATOR;
                uint256 usdtReward = grossReward * rewardUsdtBps / BPS_DENOMINATOR;
                uint256 computeBoost = grossReward - usdtReward;
                if (usdtReward != 0) {
                    rewardToken.safeTransferFrom(rewardTreasury, cursor, usdtReward);
                }
                if (computeBoost != 0) {
                    uint256 computePositionId = uint256(
                        keccak256(
                            abi.encode(
                                REFERRAL_POSITION_NAMESPACE, referredPositionId, cursor, level
                            )
                        )
                    );
                    computeEngine.addPosition(computePositionId, cursor, computeBoost);
                }
                emit ReferralRewardPaid(referredPositionId, cursor, level, usdtReward, computeBoost);
            }
            cursor = sponsorRegistry.sponsorOf(cursor);
        }
    }

    function levelBps(uint8 level) external pure returns (uint16) {
        return _levelBps(level);
    }

    function _levelBps(uint8 level) private pure returns (uint16) {
        if (level == 1) return 600;
        if (level <= 10) return 100;
        return 50;
    }
}

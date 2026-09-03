// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Permanent sponsor graph plus activation accounting for direct referrals.
contract SponsorRegistry is AccessControl {
    error ZeroAddress();
    error SelfSponsor();
    error SponsorAlreadyBound(address user);
    error SponsorCycle(address user, address proposedSponsor);
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    bytes32 public constant POOL_FACTORY_ROLE = keccak256("POOL_FACTORY_ROLE");

    mapping(address => address) public sponsorOf;
    mapping(address => bool) public activeContributor;
    mapping(address => uint256) public activeDirectReferralCount;

    event SponsorBound(address indexed user, address indexed sponsor);
    event ContributorActivated(
        address indexed user, address indexed sponsor, uint256 activeDirectCount
    );

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function bindSponsor(address sponsor) external {
        _bind(msg.sender, sponsor);
    }

    function registerPool(address pool) external onlyRole(POOL_FACTORY_ROLE) {
        if (pool == address(0)) revert ZeroAddress();
        _grantRole(POOL_ROLE, pool);
    }

    /// @notice Enables a pool to atomically bind the sponsor provided at first valid position creation.
    function bindSponsorFor(address user, address sponsor) external onlyRole(POOL_ROLE) {
        _bind(user, sponsor);
    }

    /// @notice A user becomes an effective direct referral only once, after their first valid position.
    function activateContributor(address user) external onlyRole(POOL_ROLE) {
        if (activeContributor[user]) return;
        activeContributor[user] = true;
        address sponsor = sponsorOf[user];
        uint256 newCount;
        if (sponsor != address(0)) {
            newCount = ++activeDirectReferralCount[sponsor];
        }
        emit ContributorActivated(user, sponsor, newCount);
    }

    function unlockedDepth(address user) external view returns (uint256) {
        uint256 directCount = activeDirectReferralCount[user];
        return directCount > 20 ? 20 : directCount;
    }

    function _bind(address user, address sponsor) private {
        if (user == address(0) || sponsor == address(0)) revert ZeroAddress();
        if (user == sponsor) revert SelfSponsor();
        if (sponsorOf[user] != address(0)) revert SponsorAlreadyBound(user);
        address cursor = sponsor;
        while (cursor != address(0)) {
            if (cursor == user) revert SponsorCycle(user, sponsor);
            cursor = sponsorOf[cursor];
        }
        sponsorOf[user] = sponsor;
        emit SponsorBound(user, sponsor);
    }
}

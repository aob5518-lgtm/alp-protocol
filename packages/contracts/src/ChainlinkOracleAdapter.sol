// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracleAdapter} from "./interfaces/IPriceOracleAdapter.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";

/// @notice Normalizes Chainlink USD feeds to 18 decimals and rejects stale or incomplete rounds.
contract ChainlinkOracleAdapter is Ownable2Step, IPriceOracleAdapter {
    error ZeroAddress();
    error FeedNotConfigured(address token);
    error InvalidFeedDecimals(uint8 decimals);
    error InvalidAnswer(address token, int256 answer);
    error IncompleteRound(address token, uint80 roundId, uint80 answeredInRound);
    error StalePrice(address token, uint256 updatedAt, uint256 maxAge);

    uint256 public constant WAD = 1e18;

    struct FeedConfig {
        IAggregatorV3 feed;
        uint32 maxAge;
    }

    mapping(address => FeedConfig) public feedFor;

    event FeedConfigured(address indexed token, address indexed feed, uint32 maxAge);

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
    }

    function configureFeed(address token, IAggregatorV3 feed, uint32 maxAge) external onlyOwner {
        if (token == address(0) || address(feed) == address(0)) revert ZeroAddress();
        if (maxAge == 0) revert StalePrice(token, 0, 0);
        uint8 decimals = feed.decimals();
        if (decimals > 36) revert InvalidFeedDecimals(decimals);
        feedFor[token] = FeedConfig({feed: feed, maxAge: maxAge});
        emit FeedConfigured(token, address(feed), maxAge);
    }

    function getPrice(address token) public view returns (uint256 priceE18, uint256 updatedAt) {
        FeedConfig memory config = feedFor[token];
        if (address(config.feed) == address(0)) revert FeedNotConfigured(token);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 latestUpdatedAt, uint80 answeredInRound) =
            config.feed.latestRoundData();
        startedAt;
        updatedAt = latestUpdatedAt;
        if (answer <= 0) revert InvalidAnswer(token, answer);
        if (updatedAt == 0 || answeredInRound < roundId) revert IncompleteRound(token, roundId, answeredInRound);
        if (block.timestamp > updatedAt + config.maxAge) revert StalePrice(token, updatedAt, config.maxAge);
        uint8 feedDecimals = config.feed.decimals();
        uint256 unsignedAnswer = uint256(answer);
        priceE18 = feedDecimals <= 18
            ? unsignedAnswer * (10 ** (18 - feedDecimals))
            : unsignedAnswer / (10 ** (feedDecimals - 18));
    }

    function isPriceValid(address token) external view returns (bool) {
        try this.getPrice(token) returns (uint256, uint256) {
            return true;
        } catch {
            return false;
        }
    }
}

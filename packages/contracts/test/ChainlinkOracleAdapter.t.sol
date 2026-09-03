// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ChainlinkOracleAdapter } from "../src/ChainlinkOracleAdapter.sol";
import { MockChainlinkFeed } from "./mocks/MockChainlinkFeed.sol";

contract ChainlinkOracleAdapterTest is Test {
    address internal token = makeAddr("card");
    ChainlinkOracleAdapter internal adapter;
    MockChainlinkFeed internal feed;

    function setUp() public {
        adapter = new ChainlinkOracleAdapter(address(this));
        feed = new MockChainlinkFeed(8);
        adapter.configureFeed(token, feed, 1 hours);
    }

    function testNormalizesEightDecimalUsdPriceToWad() public {
        feed.setRound(5, 123_450_000, block.timestamp, 5);
        (uint256 price, uint256 updatedAt) = adapter.getPrice(token);
        assertEq(price, 1_234_500_000_000_000_000);
        assertEq(updatedAt, block.timestamp);
        assertTrue(adapter.isPriceValid(token));
    }

    function testStalePriceIsRejected() public {
        vm.warp(2 hours);
        feed.setRound(1, 1e8, block.timestamp - 1 hours - 1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkOracleAdapter.StalePrice.selector,
                token,
                block.timestamp - 1 hours - 1,
                1 hours
            )
        );
        adapter.getPrice(token);
        assertFalse(adapter.isPriceValid(token));
    }

    function testIncompleteRoundIsRejected() public {
        feed.setRound(2, 1e8, block.timestamp, 1);
        vm.expectRevert(
            abi.encodeWithSelector(ChainlinkOracleAdapter.IncompleteRound.selector, token, 2, 1)
        );
        adapter.getPrice(token);
    }
}

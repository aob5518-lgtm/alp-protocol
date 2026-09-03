// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockOracleAdapter} from "./mocks/MockOracleAdapter.sol";
import {MockPancakeRouter} from "./mocks/MockPancakeRouter.sol";
import {BuybackExecutor} from "../src/BuybackExecutor.sol";

contract BuybackExecutorTest is Test {
    address internal treasury = makeAddr("buybackTreasury");
    address internal recipient = makeAddr("buybackRecipient");
    MockERC20 internal alp;
    MockERC20 internal card;
    MockERC20 internal wbnb;
    MockOracleAdapter internal oracle;
    MockPancakeRouter internal router;
    BuybackExecutor internal executor;

    function setUp() public {
        alp = new MockERC20("ALP", "ALP", 18);
        card = new MockERC20("CARD", "CARD", 18);
        wbnb = new MockERC20("WBNB", "WBNB", 18);
        oracle = new MockOracleAdapter();
        oracle.setPrice(1 ether, block.timestamp, true);
        oracle.setTokenPrice(address(alp), 1 ether);
        oracle.setTokenPrice(address(card), 2 ether);
        oracle.setTokenPrice(address(wbnb), 0.5 ether);
        router = new MockPancakeRouter();
        router.setRateWad(0.5 ether);
        executor = new BuybackExecutor(alp, treasury, oracle, recipient, 1 days, 500, address(this));
        executor.grantRole(executor.SCHEDULER_ROLE(), address(this));
        executor.setRouterWhitelist(address(router), true);
        executor.configureToken(address(alp), true, 100 ether);
        executor.configureToken(address(card), true, 1_000 ether);
        executor.configureToken(address(wbnb), true, 1_000 ether);
        alp.mint(treasury, 100 ether);
        card.mint(address(router), 100 ether);
        vm.prank(treasury);
        alp.approve(address(executor), type(uint256).max);
    }

    function testQueuedBuybackUsesOracleMinimumAndApprovedRouter() public {
        bytes32 tradeId = executor.queueTrade(address(router), address(alp), address(card), 100 ether);
        vm.warp(block.timestamp + 1 days);
        executor.executeTrade(tradeId, 47.5 ether, block.timestamp + 10 minutes);
        assertEq(alp.balanceOf(treasury), 0);
        assertEq(card.balanceOf(recipient), 50 ether);
        (,,,,, bool executed) = executor.queuedTrade(tradeId);
        assertTrue(executed);
    }

    function testTradeCannotExecuteBeforeTimelockOrBelowOracleBound() public {
        bytes32 tradeId = executor.queueTrade(address(router), address(alp), address(card), 100 ether);
        vm.expectRevert(abi.encodeWithSelector(BuybackExecutor.TradeNotReady.selector, tradeId, block.timestamp + 1 days, block.timestamp));
        executor.executeTrade(tradeId, 47.5 ether, block.timestamp + 10 minutes);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(abi.encodeWithSelector(BuybackExecutor.InsufficientMinimumOut.selector, 40 ether, 47.5 ether));
        executor.executeTrade(tradeId, 40 ether, block.timestamp + 10 minutes);
    }

    function testMultiHopPathRequiresEveryWhitelistedAssetAndUsesChainedOraclePrice() public {
        address[] memory path = new address[](3);
        path[0] = address(alp);
        path[1] = address(wbnb);
        path[2] = address(card);
        bytes32 tradeId = executor.queueTradePath(address(router), path, 100 ether);
        assertEq(executor.oracleMinimumOutPath(path, 100 ether), 47.5 ether);
        vm.warp(block.timestamp + 1 days);
        executor.executeTrade(tradeId, 47.5 ether, block.timestamp + 10 minutes);
        assertEq(card.balanceOf(recipient), 50 ether);
    }
}

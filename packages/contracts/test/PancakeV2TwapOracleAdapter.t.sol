// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockOracleAdapter } from "./mocks/MockOracleAdapter.sol";
import { MockTwapPair } from "./mocks/MockTwapPair.sol";
import { PancakeV2TwapOracleAdapter } from "../src/PancakeV2TwapOracleAdapter.sol";
import { IPancakeV2Pair } from "../src/interfaces/IPancakeV2Pair.sol";

contract PancakeV2TwapOracleAdapterTest is Test {
    uint256 internal constant Q112 = 2 ** 112;
    MockERC20 internal asset;
    MockERC20 internal usdt;
    MockOracleAdapter internal referenceOracle;
    MockTwapPair internal pair;
    PancakeV2TwapOracleAdapter internal twap;

    function setUp() public {
        asset = new MockERC20("ASSET", "AST", 18);
        usdt = new MockERC20("USDT", "USDT", 18);
        referenceOracle = new MockOracleAdapter();
        referenceOracle.setPrice(1 ether, block.timestamp, true);
        referenceOracle.setTokenPrice(address(asset), 2 ether);
        referenceOracle.setTokenPrice(address(usdt), 1 ether);
        pair = new MockTwapPair(address(asset), address(usdt));
        pair.setState(0, 0, 100 ether, 200 ether, uint32(block.timestamp));
        twap = new PancakeV2TwapOracleAdapter(
            IPancakeV2Pair(address(pair)),
            asset,
            usdt,
            referenceOracle,
            30 minutes,
            2 hours,
            10 ether,
            10 ether,
            500
        );
    }

    function testTwapNeedsWindowAndProducesQuoteUsdPrice() public {
        twap.update();
        vm.warp(block.timestamp + 30 minutes);
        pair.setState(2 * Q112 * 30 minutes, 0, 100 ether, 200 ether, uint32(block.timestamp));
        assertEq(twap.update(), 2 ether);
        assertTrue(twap.isPriceValid(address(asset)));
    }

    function testRejectsInsufficientLiquidityAndStaleObservations() public {
        pair.setState(0, 0, 1 ether, 1 ether, uint32(block.timestamp));
        vm.expectRevert(
            abi.encodeWithSelector(
                PancakeV2TwapOracleAdapter.InsufficientLiquidity.selector, 1 ether, 1 ether
            )
        );
        twap.update();

        pair.setState(0, 0, 100 ether, 200 ether, uint32(block.timestamp));
        twap.update();
        vm.warp(block.timestamp + 30 minutes);
        pair.setState(2 * Q112 * 30 minutes, 0, 100 ether, 200 ether, uint32(block.timestamp));
        referenceOracle.setTokenPrice(address(asset), 4 ether);
        twap.update();
        vm.warp(block.timestamp + 2 hours + 1);
        assertFalse(twap.isPriceValid(address(asset)));
    }

    function testRejectsReferencePriceDeviation() public {
        twap.update();
        referenceOracle.setTokenPrice(address(asset), 1 ether);
        vm.warp(block.timestamp + 30 minutes);
        pair.setState(2 * Q112 * 30 minutes, 0, 100 ether, 200 ether, uint32(block.timestamp));
        vm.expectRevert(
            abi.encodeWithSelector(
                PancakeV2TwapOracleAdapter.TwapPriceDeviation.selector, 2 ether, 1 ether
            )
        );
        twap.update();
    }
}

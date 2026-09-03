// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { LaunchReferencePriceOracle } from "../src/LaunchReferencePriceOracle.sol";
import { OracleRouter } from "../src/OracleRouter.sol";
import { IPriceOracleAdapter } from "../src/interfaces/IPriceOracleAdapter.sol";
import { MockOracleAdapter } from "./mocks/MockOracleAdapter.sol";

contract LaunchReferencePriceOracleTest is Test {
    address internal asset = makeAddr("relique-card");
    address internal quote = makeAddr("test-usdt");
    LaunchReferencePriceOracle internal referenceOracle;
    OracleRouter internal router;

    function setUp() public {
        referenceOracle = new LaunchReferencePriceOracle(1 hours, address(this));
        router = new OracleRouter(address(this));
    }

    function testPriceRequiresTimelockAndExpires() public {
        uint64 activation = uint64(block.timestamp + 1 hours);
        referenceOracle.proposePrice(asset, quote, 2 ether, activation, activation + 1 days, 500);
        vm.expectRevert(
            abi.encodeWithSelector(
                LaunchReferencePriceOracle.ActivationNotReady.selector, activation, block.timestamp
            )
        );
        referenceOracle.activatePrice(asset);
        vm.warp(activation);
        referenceOracle.activatePrice(asset);
        (uint256 price, uint256 updatedAt) = referenceOracle.getPrice(asset);
        assertEq(price, 2 ether);
        assertEq(updatedAt, activation);
        assertTrue(referenceOracle.isPriceValid(asset));
        vm.warp(activation + 1 days + 1);
        assertFalse(referenceOracle.isPriceValid(asset));
    }

    function testRouterTransitionsFromReferenceToTwap() public {
        uint64 activation = uint64(block.timestamp + 1 hours);
        referenceOracle.proposePrice(asset, quote, 2 ether, activation, activation + 1 days, 500);
        vm.warp(activation);
        referenceOracle.activatePrice(asset);
        router.configureSource(
            asset,
            IPriceOracleAdapter(address(referenceOracle)),
            OracleRouter.SourceKind.LAUNCH_REFERENCE
        );
        (uint256 price,) = router.getPrice(asset);
        assertEq(price, 2 ether);
        MockOracleAdapter twap = new MockOracleAdapter();
        twap.setPrice(21 ether / 10, block.timestamp, true);
        router.configureSource(
            asset, IPriceOracleAdapter(address(twap)), OracleRouter.SourceKind.PANCAKE_V2_TWAP
        );
        (price,) = router.getPrice(asset);
        assertEq(price, 21 ether / 10);
    }
}

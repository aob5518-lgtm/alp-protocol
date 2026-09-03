// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { MockOracleAdapter } from "./mocks/MockOracleAdapter.sol";
import { OracleRouter } from "../src/OracleRouter.sol";
import { IPriceOracleAdapter } from "../src/interfaces/IPriceOracleAdapter.sol";

contract OracleRouterTest is Test {
    OracleRouter internal router;
    MockOracleAdapter internal chainlinkSource;
    MockOracleAdapter internal twapSource;
    address internal asset = makeAddr("asset");

    function setUp() public {
        router = new OracleRouter(address(this));
        chainlinkSource = new MockOracleAdapter();
        twapSource = new MockOracleAdapter();
        chainlinkSource.setPrice(3 ether, block.timestamp, true);
        twapSource.setPrice(4 ether, block.timestamp, true);
    }

    function testRoutesConfiguredSourcesAndCanSwitchSourceKindByGovernance() public {
        router.configureSource(
            asset, IPriceOracleAdapter(address(chainlinkSource)), OracleRouter.SourceKind.CHAINLINK
        );
        (uint256 price, uint256 updatedAt) = router.getPrice(asset);
        assertEq(price, 3 ether);
        assertEq(updatedAt, block.timestamp);
        (address source, OracleRouter.SourceKind kind) = router.sourceConfig(asset);
        assertEq(source, address(chainlinkSource));
        assertEq(uint8(kind), uint8(OracleRouter.SourceKind.CHAINLINK));

        router.configureSource(
            asset, IPriceOracleAdapter(address(twapSource)), OracleRouter.SourceKind.PANCAKE_V2_TWAP
        );
        (price,) = router.getPrice(asset);
        assertEq(price, 4 ether);
        assertTrue(router.isPriceValid(asset));
    }

    function testUnconfiguredAssetsCannotReturnAPrice() public {
        vm.expectRevert(abi.encodeWithSelector(OracleRouter.SourceNotConfigured.selector, asset));
        router.getPrice(asset);
        assertFalse(router.isPriceValid(asset));
    }
}

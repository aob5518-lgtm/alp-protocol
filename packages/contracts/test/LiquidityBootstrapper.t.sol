// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ALPToken} from "../src/ALPToken.sol";
import {GenesisReserve} from "../src/GenesisReserve.sol";
import {GenesisReserveLiquiditySource} from "../src/GenesisReserveLiquiditySource.sol";
import {PermanentLiquidityLocker} from "../src/PermanentLiquidityLocker.sol";
import {LiquidityBootstrapper} from "../src/LiquidityBootstrapper.sol";
import {IPancakeV2Router} from "../src/interfaces/IPancakeV2Router.sol";
import {IPancakeV2Factory} from "../src/interfaces/IPancakeV2Factory.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockLiquidityPair} from "./mocks/MockLiquidityPair.sol";
import {MockPancakeFactory, MockPancakeLiquidityRouter} from "./mocks/MockPancakeLiquidity.sol";

contract LiquidityBootstrapperTest is Test {
    GenesisReserve internal reserve;
    ALPToken internal alp;
    MockERC20 internal usdt;
    GenesisReserveLiquiditySource internal source;
    PermanentLiquidityLocker internal locker;
    MockPancakeFactory internal factory;
    MockPancakeLiquidityRouter internal router;
    LiquidityBootstrapper internal bootstrapper;
    address internal pair;

    function setUp() public {
        reserve = new GenesisReserve(address(this));
        alp = new ALPToken(
            address(reserve), address(this), makeAddr("buyback"), makeAddr("top100"), makeAddr("nodeAirdrop"),
            makeAddr("community"), makeAddr("development")
        );
        reserve.configureToken(address(alp));
        usdt = new MockERC20("USDT", "USDT", 18);
        source = new GenesisReserveLiquiditySource(reserve, address(this));
        locker = new PermanentLiquidityLocker(address(this), address(this));
        factory = new MockPancakeFactory();
        router = new MockPancakeLiquidityRouter();
        pair = factory.createPair(address(alp), address(usdt));
        router.setPair(pair);
        bootstrapper = new LiquidityBootstrapper(
            alp, usdt, source, IPancakeV2Router(address(router)), IPancakeV2Factory(address(factory)), locker, address(this)
        );

        reserve.setProtocolModule(address(source), true);
        reserve.setProtocolModule(address(bootstrapper), true);
        source.setLiquidityConsumer(address(bootstrapper), true);
        locker.setLiquidityExecutor(address(bootstrapper), true);
        alp.configureLiquidityBootstrapper(address(bootstrapper));
        usdt.mint(address(this), 1 ether);
        usdt.approve(address(bootstrapper), type(uint256).max);
    }

    function testBootstrapUsesFixedPriceAndPermanentlyLocksLP() public {
        uint256 alpAmount = 1_000 ether;
        uint256 usdtAmount = bootstrapper.requiredUsdtForAlp(alpAmount);
        assertEq(usdtAmount, 0.1 ether);

        (address initializedPair, uint256 usedAlp, uint256 usedUsdt, uint256 lpAmount) = bootstrapper.initialize(
            alpAmount, usdtAmount, alpAmount, usdtAmount, block.timestamp + 1 days
        );

        assertEq(initializedPair, pair);
        assertEq(usedAlp, alpAmount);
        assertEq(usedUsdt, usdtAmount);
        assertEq(alp.mainPair(), pair);
        assertEq(locker.lockedLiquidity(pair), lpAmount);
        assertEq(MockLiquidityPair(pair).balanceOf(address(locker)), lpAmount);
        assertEq(alp.balanceOf(address(reserve)), 210_000_000 ether - alpAmount);
    }

    function testBootstrapRejectsNonTargetRatioAndCannotRunTwice() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityBootstrapper.PriceRatioMismatch.selector, 1 ether, 0.1 ether));
        bootstrapper.initialize(1_000 ether, 1 ether, 0, 0, block.timestamp + 1 days);

        bootstrapper.initialize(1_000 ether, 0.1 ether, 0, 0, block.timestamp + 1 days);
        vm.expectRevert(LiquidityBootstrapper.AlreadyInitialized.selector);
        bootstrapper.initialize(1_000 ether, 0.1 ether, 0, 0, block.timestamp + 1 days);
    }
}

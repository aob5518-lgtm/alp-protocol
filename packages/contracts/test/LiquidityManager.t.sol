// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ALPToken} from "../src/ALPToken.sol";
import {GenesisReserve} from "../src/GenesisReserve.sol";
import {GenesisReserveLiquiditySource} from "../src/GenesisReserveLiquiditySource.sol";
import {PermanentLiquidityLocker} from "../src/PermanentLiquidityLocker.sol";
import {LiquidityManager} from "../src/LiquidityManager.sol";
import {ProductionConfigValidator} from "../src/ProductionConfigValidator.sol";
import {ProtocolController} from "../src/ProtocolController.sol";
import {IProtocolController} from "../src/interfaces/IProtocolController.sol";
import {IPancakeV2Router} from "../src/interfaces/IPancakeV2Router.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockLiquidityPair} from "./mocks/MockLiquidityPair.sol";
import {MockPancakeFactory, MockPancakeLiquidityRouter} from "./mocks/MockPancakeLiquidity.sol";

contract LiquidityManagerTest is Test {
    GenesisReserve internal reserve;
    ALPToken internal alp;
    MockERC20 internal usdt;
    GenesisReserveLiquiditySource internal source;
    PermanentLiquidityLocker internal locker;
    LiquidityManager internal manager;
    ProtocolController internal controller;
    MockPancakeLiquidityRouter internal router;
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
        controller = new ProtocolController(new ProductionConfigValidator(address(this)), address(this));
        manager = new LiquidityManager(alp, usdt, source, locker, IProtocolController(address(controller)), address(this));
        MockPancakeFactory factory = new MockPancakeFactory();
        router = new MockPancakeLiquidityRouter();
        pair = factory.createPair(address(alp), address(usdt));
        router.setPair(pair);

        reserve.setProtocolModule(address(source), true);
        reserve.setProtocolModule(address(manager), true);
        source.setLiquidityConsumer(address(manager), true);
        locker.setLiquidityExecutor(address(manager), true);
        manager.configureRouter(IPancakeV2Router(address(router)));
        manager.configureMainPair(pair);
        manager.grantRole(manager.LIQUIDITY_OPERATOR_ROLE(), address(this));
        manager.registerPool(address(this));
        usdt.mint(address(this), 100 ether);
        usdt.transfer(address(manager), 50 ether);
        manager.receiveLiquidityAllocation(1, 50 ether);
    }

    function testManagerUsesPreMintedALPAndPermanentlyLocksLP() public {
        (uint256 usedAlp, uint256 usedUsdt, uint256 lpAmount) = manager.addLiquidity(
            1, 100 ether, 50 ether, 100 ether, 50 ether, block.timestamp + 1 days
        );
        assertEq(usedAlp, 100 ether);
        assertEq(usedUsdt, 50 ether);
        assertEq(manager.pendingUsdtByAsset(1), 0);
        assertEq(locker.lockedLiquidity(pair), lpAmount);
        assertEq(MockLiquidityPair(pair).balanceOf(address(locker)), lpAmount);
        assertEq(alp.balanceOf(address(reserve)), 210_000_000 ether - 100 ether);
    }

    function testEmergencyPauseBlocksLiquidityAddition() public {
        controller.emergencyPause();
        vm.expectRevert(ProtocolController.ProtocolPaused.selector);
        manager.addLiquidity(1, 100 ether, 50 ether, 0, 0, block.timestamp + 1 days);
    }
}

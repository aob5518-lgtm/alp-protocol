// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockOracleAdapter} from "./mocks/MockOracleAdapter.sol";
import {AssetRegistry} from "../src/AssetRegistry.sol";
import {PartnerAssetVault} from "../src/PartnerAssetVault.sol";
import {GlobalComputeEngine} from "../src/GlobalComputeEngine.sol";
import {SponsorRegistry} from "../src/SponsorRegistry.sol";
import {ReferralRewardEngine} from "../src/ReferralRewardEngine.sol";
import {LaunchPoolFactory} from "../src/LaunchPoolFactory.sol";
import {LaunchPool} from "../src/LaunchPool.sol";
import {LinearDailyCompensationStrategy} from "../src/strategies/LinearDailyCompensationStrategy.sol";
import {TierEngine} from "../src/TierEngine.sol";
import {DifferentialRewardEngine} from "../src/DifferentialRewardEngine.sol";
import {ILiquidityManager} from "../src/interfaces/ILiquidityManager.sol";
import {MockLiquidityManager} from "./mocks/MockLiquidityManager.sol";
import {ProductionConfigValidator} from "../src/ProductionConfigValidator.sol";
import {ProtocolController} from "../src/ProtocolController.sol";
import {IProtocolController} from "../src/interfaces/IProtocolController.sol";

contract LaunchPoolFactoryTest is Test {
    address internal treasury = makeAddr("rewardTreasury");
    MockLiquidityManager internal liquidity;
    address internal sponsor = makeAddr("sponsor");
    address internal user = makeAddr("user");
    MockERC20 internal card;
    MockERC20 internal usdt;
    MockERC20 internal alp;
    MockOracleAdapter internal oracle;
    PartnerAssetVault internal vault;
    AssetRegistry internal registry;
    GlobalComputeEngine internal compute;
    SponsorRegistry internal sponsors;
    ReferralRewardEngine internal referral;
    TierEngine internal tiers;
    DifferentialRewardEngine internal differential;
    LaunchPoolFactory internal factory;
    LaunchPool internal pool;
    ProductionConfigValidator internal validator;
    ProtocolController internal controller;

    function setUp() public {
        card = new MockERC20("CARD", "CARD", 18);
        usdt = new MockERC20("USDT", "USDT", 18);
        alp = new MockERC20("ALP", "ALP", 18);
        oracle = new MockOracleAdapter();
        oracle.setPrice(2 ether, block.timestamp, true);
        vault = new PartnerAssetVault(address(this), card, PartnerAssetVault.Strategy.LOCK, address(0));
        registry = new AssetRegistry(address(this));
        compute = new GlobalComputeEngine(alp, address(this));
        sponsors = new SponsorRegistry(address(this));
        referral = new ReferralRewardEngine(usdt, treasury, sponsors, compute, address(this), true);
        tiers = new TierEngine(sponsors, TierEngine.VolumeBase.USDT_CONTRIBUTION, address(this));
        differential = new DifferentialRewardEngine(usdt, treasury, sponsors, tiers, address(this));
        liquidity = new MockLiquidityManager();
        validator = new ProductionConfigValidator(address(this));
        controller = new ProtocolController(validator, address(this));
        factory = new LaunchPoolFactory(
            address(this), registry, usdt, compute, sponsors, referral, tiers, differential, IProtocolController(address(controller))
        );
        registry.configurePoolFactory(address(factory));

        vault.grantFactory(address(factory));
        compute.grantRole(compute.POOL_FACTORY_ROLE(), address(factory));
        sponsors.grantRole(sponsors.POOL_FACTORY_ROLE(), address(factory));
        referral.grantRole(referral.POOL_FACTORY_ROLE(), address(factory));
        tiers.grantRole(tiers.POOL_FACTORY_ROLE(), address(factory));
        differential.grantRole(differential.POOL_FACTORY_ROLE(), address(factory));
        registry.registerAsset(
            AssetRegistry.AssetConfig({
                token: address(card),
                oracle: address(oracle),
                vault: address(vault),
                symbol: "CARD",
                name: "Genesis CARD",
                launchTime: uint64(block.timestamp),
                riskStatus: AssetRegistry.RiskStatus.NORMAL,
                launchStatus: AssetRegistry.LaunchStatus.ACTIVE
            })
        );
        pool = factory.createPool(
            1,
            LaunchPoolFactory.PoolConfig({
                poolOwner: address(this),
                compensationStrategy: new LinearDailyCompensationStrategy(),
                rewardTreasury: treasury,
                liquidityManager: ILiquidityManager(address(liquidity)),
                computeWeightE18: 1e18
            })
        );
        vm.prank(treasury);
        usdt.approve(address(referral), type(uint256).max);
        card.mint(user, 100 ether);
        usdt.mint(user, 100 ether);
        vm.prank(user);
        card.approve(address(vault), type(uint256).max);
        vm.prank(user);
        usdt.approve(address(pool), type(uint256).max);
        vm.prank(user);
        sponsors.bindSponsor(sponsor);
    }

    function testFactoryCreatesAuthorizedPoolAndPositionSettlesAllLegs() public {
        vm.prank(user);
        uint256 positionId = pool.createPosition(100 ether, 25 ether);

        assertEq(positionId, 1);
        assertTrue(factory.isPool(address(pool)));
        assertTrue(vault.authorizedPool(address(pool)));
        assertEq(card.balanceOf(address(vault)), 25 ether);
        assertEq(usdt.balanceOf(treasury), 22 ether);
        assertEq(usdt.balanceOf(address(liquidity)), 25 ether);
        assertEq(liquidity.pending(1), 25 ether);
        assertEq(usdt.balanceOf(sponsor), 3 ether);
        assertEq(compute.globalEffectiveCompute(), 100 ether);
        assertEq(sponsors.activeDirectReferralCount(sponsor), 1);
        (address positionUser,,,,,,,,,,) = pool.positions(positionId);
        assertEq(positionUser, user);
    }

    function testRiskPauseBlocksNewPositionsEvenAfterPoolDeployment() public {
        AssetRegistry.AssetConfig memory assetConfig = registry.asset(1);
        assetConfig.launchStatus = AssetRegistry.LaunchStatus.PAUSED;
        registry.updateAsset(1, assetConfig);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LaunchPool.AssetUnavailable.selector, 1));
        pool.createPosition(100 ether, 25 ether);
    }

    function testFirstPoolSealsImmutableAssetIdentityButRetainsGovernedRiskUpdates() public {
        assertTrue(registry.assetSealed(1));
        AssetRegistry.AssetConfig memory mutableConfig = registry.asset(1);
        mutableConfig.oracle = address(new MockOracleAdapter());
        mutableConfig.riskStatus = AssetRegistry.RiskStatus.WARNING;
        registry.updateAsset(1, mutableConfig);
        assertEq(registry.asset(1).oracle, address(mutableConfig.oracle));

        AssetRegistry.AssetConfig memory invalidConfig = registry.asset(1);
        invalidConfig.symbol = "NEW";
        vm.expectRevert(abi.encodeWithSelector(AssetRegistry.ImmutableAssetFieldsSealed.selector, 1));
        registry.updateAsset(1, invalidConfig);
    }

    function testProtocolEmergencyPauseBlocksNewPositionsUntilGovernanceResumes() public {
        controller.emergencyPause();
        vm.prank(user);
        vm.expectRevert(ProtocolController.ProtocolPaused.selector);
        pool.createPosition(100 ether, 25 ether);

        controller.resume();
        vm.prank(user);
        pool.createPosition(100 ether, 25 ether);
        assertEq(pool.nextPositionId(), 2);
    }
}

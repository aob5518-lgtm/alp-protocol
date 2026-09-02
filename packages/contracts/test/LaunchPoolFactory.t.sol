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

contract LaunchPoolFactoryTest is Test {
    address internal treasury = makeAddr("rewardTreasury");
    address internal liquidity = makeAddr("liquidity");
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
        factory = new LaunchPoolFactory(address(this), registry, usdt, compute, sponsors, referral, tiers, differential);

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
                liquidityTreasury: liquidity,
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
        assertEq(usdt.balanceOf(liquidity), 25 ether);
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
}

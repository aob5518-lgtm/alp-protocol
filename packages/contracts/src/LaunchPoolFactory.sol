// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AssetRegistry} from "./AssetRegistry.sol";
import {LaunchPool} from "./LaunchPool.sol";
import {GlobalComputeEngine} from "./GlobalComputeEngine.sol";
import {SponsorRegistry} from "./SponsorRegistry.sol";
import {ReferralRewardEngine} from "./ReferralRewardEngine.sol";
import {ICompensationStrategy} from "./interfaces/ICompensationStrategy.sol";
import {IPartnerAssetVault} from "./interfaces/IPartnerAssetVault.sol";

/// @notice Creates per-asset pools and grants them only the narrow roles required for position accounting.
contract LaunchPoolFactory is Ownable2Step {
    error ZeroAddress();
    error AssetNotActive(uint256 assetId);
    error InvalidPoolConfiguration();

    struct PoolConfig {
        address poolOwner;
        ICompensationStrategy compensationStrategy;
        address rewardTreasury;
        address liquidityTreasury;
        uint256 computeWeightE18;
    }

    AssetRegistry public immutable registry;
    IERC20Metadata public immutable usdt;
    GlobalComputeEngine public immutable computeEngine;
    SponsorRegistry public immutable sponsorRegistry;
    ReferralRewardEngine public immutable referralRewardEngine;
    mapping(uint256 => address[]) private _poolsForAsset;
    mapping(address => bool) public isPool;

    event LaunchPoolCreated(
        uint256 indexed assetId,
        address indexed pool,
        address indexed poolOwner,
        address compensationStrategy,
        uint256 computeWeightE18
    );

    constructor(
        address initialOwner,
        AssetRegistry registry_,
        IERC20Metadata usdt_,
        GlobalComputeEngine computeEngine_,
        SponsorRegistry sponsorRegistry_,
        ReferralRewardEngine referralRewardEngine_
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) || address(registry_) == address(0) || address(usdt_) == address(0)
                || address(computeEngine_) == address(0) || address(sponsorRegistry_) == address(0)
                || address(referralRewardEngine_) == address(0)
        ) revert ZeroAddress();
        registry = registry_;
        usdt = usdt_;
        computeEngine = computeEngine_;
        sponsorRegistry = sponsorRegistry_;
        referralRewardEngine = referralRewardEngine_;
    }

    function createPool(uint256 assetId, PoolConfig calldata config) external onlyOwner returns (LaunchPool pool) {
        if (
            config.poolOwner == address(0) || address(config.compensationStrategy) == address(0)
                || config.rewardTreasury == address(0) || config.liquidityTreasury == address(0) || config.computeWeightE18 == 0
        ) revert InvalidPoolConfiguration();
        AssetRegistry.AssetConfig memory assetConfig = registry.asset(assetId);
        if (assetConfig.launchStatus != AssetRegistry.LaunchStatus.ACTIVE) revert AssetNotActive(assetId);
        pool = new LaunchPool(
            config.poolOwner,
            registry,
            assetId,
            usdt,
            computeEngine,
            config.compensationStrategy,
            sponsorRegistry,
            referralRewardEngine,
            config.rewardTreasury,
            config.liquidityTreasury,
            config.computeWeightE18
        );
        IPartnerAssetVault(assetConfig.vault).registerPool(address(pool));
        computeEngine.registerPool(address(pool));
        sponsorRegistry.registerPool(address(pool));
        referralRewardEngine.registerPool(address(pool));
        _poolsForAsset[assetId].push(address(pool));
        isPool[address(pool)] = true;
        emit LaunchPoolCreated(assetId, address(pool), config.poolOwner, address(config.compensationStrategy), config.computeWeightE18);
    }

    function poolCount(uint256 assetId) external view returns (uint256) {
        return _poolsForAsset[assetId].length;
    }

    function poolAt(uint256 assetId, uint256 index) external view returns (address) {
        return _poolsForAsset[assetId][index];
    }
}

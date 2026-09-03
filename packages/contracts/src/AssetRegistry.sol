// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracleAdapter} from "./interfaces/IPriceOracleAdapter.sol";

/// @notice Governance registry for assets. Pool contracts snapshot their mutable economic inputs at creation.
contract AssetRegistry is Ownable2Step {
    error ZeroAddress();
    error AssetNotFound(uint256 assetId);
    error InvalidLaunchTime(uint64 launchTime);
    error PoolFactoryAlreadyConfigured();
    error OnlyPoolFactory(address caller);
    error ImmutableAssetFieldsSealed(uint256 assetId);

    enum RiskStatus { REVIEW, NORMAL, WARNING, BLOCKED }
    enum LaunchStatus { DRAFT, REVIEW, ACTIVE, PAUSED, DELISTED }

    struct AssetConfig {
        address token;
        address oracle;
        address vault;
        string symbol;
        string name;
        uint64 launchTime;
        RiskStatus riskStatus;
        LaunchStatus launchStatus;
    }

    uint256 public nextAssetId = 1;
    mapping(uint256 => AssetConfig) private _assets;
    mapping(uint256 => bool) public assetSealed;
    address public poolFactory;

    event AssetRegistered(uint256 indexed assetId, address indexed token, string symbol, string name);
    event AssetUpdated(uint256 indexed assetId, LaunchStatus launchStatus, RiskStatus riskStatus);
    event PoolFactoryConfigured(address indexed poolFactory);
    event AssetSealed(uint256 indexed assetId, address indexed pool);

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
    }

    function registerAsset(AssetConfig calldata config) external onlyOwner returns (uint256 assetId) {
        _validate(config);
        assetId = nextAssetId++;
        _assets[assetId] = config;
        emit AssetRegistered(assetId, config.token, config.symbol, config.name);
    }

    function updateAsset(uint256 assetId, AssetConfig calldata config) external onlyOwner {
        AssetConfig storage previous = _assets[assetId];
        if (previous.token == address(0)) revert AssetNotFound(assetId);
        _validate(config);
        if (assetSealed[assetId] && (
            previous.token != config.token || previous.vault != config.vault || previous.launchTime != config.launchTime
                || keccak256(bytes(previous.symbol)) != keccak256(bytes(config.symbol))
                || keccak256(bytes(previous.name)) != keccak256(bytes(config.name))
        )) revert ImmutableAssetFieldsSealed(assetId);
        _assets[assetId] = config;
        emit AssetUpdated(assetId, config.launchStatus, config.riskStatus);
    }

    /// @notice Binds the trusted factory once; only it can seal an asset after its first pool exists.
    function configurePoolFactory(address poolFactory_) external onlyOwner {
        if (poolFactory_ == address(0)) revert ZeroAddress();
        if (poolFactory != address(0)) revert PoolFactoryAlreadyConfigured();
        poolFactory = poolFactory_;
        emit PoolFactoryConfigured(poolFactory_);
    }

    function sealAsset(uint256 assetId, address pool) external {
        if (msg.sender != poolFactory) revert OnlyPoolFactory(msg.sender);
        if (_assets[assetId].token == address(0)) revert AssetNotFound(assetId);
        if (pool == address(0) || pool.code.length == 0) revert ZeroAddress();
        if (!assetSealed[assetId]) {
            assetSealed[assetId] = true;
            emit AssetSealed(assetId, pool);
        }
    }

    function asset(uint256 assetId) external view returns (AssetConfig memory) {
        AssetConfig memory config = _assets[assetId];
        if (config.token == address(0)) revert AssetNotFound(assetId);
        return config;
    }

    function canCreatePosition(uint256 assetId) external view returns (bool) {
        AssetConfig storage config = _assets[assetId];
        return config.token != address(0) && config.launchStatus == LaunchStatus.ACTIVE
            && config.riskStatus != RiskStatus.BLOCKED && IPriceOracleAdapter(config.oracle).isPriceValid(config.token);
    }

    function _validate(AssetConfig calldata config) private pure {
        if (config.token == address(0) || config.oracle == address(0) || config.vault == address(0)) revert ZeroAddress();
        if (config.launchTime == 0) revert InvalidLaunchTime(config.launchTime);
    }
}

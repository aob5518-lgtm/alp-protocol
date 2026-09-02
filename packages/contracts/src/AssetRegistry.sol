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

    event AssetRegistered(uint256 indexed assetId, address indexed token, string symbol, string name);
    event AssetUpdated(uint256 indexed assetId, LaunchStatus launchStatus, RiskStatus riskStatus);

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
        if (_assets[assetId].token == address(0)) revert AssetNotFound(assetId);
        _validate(config);
        _assets[assetId] = config;
        emit AssetUpdated(assetId, config.launchStatus, config.riskStatus);
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

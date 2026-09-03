// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IPriceOracleAdapter } from "./interfaces/IPriceOracleAdapter.sol";

/// @notice Canonical asset-price entry point. Each asset is pinned to one reviewed
/// Chainlink or Pancake V2 TWAP adapter; callers never need to infer the source type.
contract OracleRouter is AccessControl, IPriceOracleAdapter {
    error ZeroAddress();
    error SourceMustBeContract(address source);
    error SourceNotConfigured(address token);
    error InvalidSourceKind();

    enum SourceKind {
        CHAINLINK,
        PANCAKE_V2_TWAP
    }

    struct SourceConfig {
        IPriceOracleAdapter source;
        SourceKind kind;
    }

    mapping(address => SourceConfig) private _sources;

    event SourceConfigured(address indexed token, address indexed source, SourceKind kind);

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function configureSource(address token, IPriceOracleAdapter source, SourceKind kind)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (token == address(0) || address(source) == address(0)) revert ZeroAddress();
        if (address(source).code.length == 0) revert SourceMustBeContract(address(source));
        if (uint8(kind) > uint8(SourceKind.PANCAKE_V2_TWAP)) revert InvalidSourceKind();
        _sources[token] = SourceConfig({ source: source, kind: kind });
        emit SourceConfigured(token, address(source), kind);
    }

    function sourceConfig(address token) external view returns (address source, SourceKind kind) {
        SourceConfig storage config = _sources[token];
        return (address(config.source), config.kind);
    }

    function getPrice(address token) external view returns (uint256 priceE18, uint256 updatedAt) {
        IPriceOracleAdapter source = _source(token);
        return source.getPrice(token);
    }

    function isPriceValid(address token) external view returns (bool) {
        SourceConfig storage config = _sources[token];
        return address(config.source) != address(0) && config.source.isPriceValid(token);
    }

    function _source(address token) private view returns (IPriceOracleAdapter source) {
        source = _sources[token].source;
        if (address(source) == address(0)) revert SourceNotConfigured(token);
    }
}

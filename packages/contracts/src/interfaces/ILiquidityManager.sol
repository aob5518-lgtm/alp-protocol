// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ILiquidityManager {
    function receiveLiquidityAllocation(uint256 assetId, uint256 amount) external;
}

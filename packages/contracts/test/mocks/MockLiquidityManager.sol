// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ILiquidityManager} from "../../src/interfaces/ILiquidityManager.sol";

contract MockLiquidityManager is ILiquidityManager {
    mapping(uint256 => uint256) public pending;

    function receiveLiquidityAllocation(uint256 assetId, uint256 amount) external {
        pending[assetId] += amount;
    }
}

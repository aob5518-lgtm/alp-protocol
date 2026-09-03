// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Supplies pre-existing ALP for liquidity; implementations must never mint.
interface ILiquidityALPSource {
    function provideLiquidityALP(address recipient, uint256 amount, bytes32 operation) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IGlobalComputeEngine {
    function addPosition(uint256 positionId, address user, uint256 effectiveCompute) external;

    function pending(uint256 positionId) external view returns (uint256);

    function claim(uint256 positionId, address recipient) external returns (uint256 amount);
}

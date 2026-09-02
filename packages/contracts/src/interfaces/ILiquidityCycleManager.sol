// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ILiquidityCycleManager {
    function onAlpReceived(address account, uint256 amount) external;

    function onAlpSold(address account, uint256 grossAmount) external;
}

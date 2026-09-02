// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IDifferentialRewardEngine {
    function distribute(uint256 positionId, address user, uint256 rewardBase) external;
}

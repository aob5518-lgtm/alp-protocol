// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ITierEngine {
    function recordPosition(address user, uint256 usdtContribution, uint256 totalPositionValue)
        external;
}

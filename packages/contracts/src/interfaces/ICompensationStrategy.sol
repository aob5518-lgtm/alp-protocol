// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ICompensationStrategy {
    /// @notice Multiplier in 1e18 for `elapsedDays` after the pool launch date.
    function factor(uint256 elapsedDays) external pure returns (uint256 factorE18);
}

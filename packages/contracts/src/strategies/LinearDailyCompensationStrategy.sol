// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ICompensationStrategy} from "../interfaces/ICompensationStrategy.sol";

/// @notice 1% additive compensation per full day. A factor is fixed when a position is created.
contract LinearDailyCompensationStrategy is ICompensationStrategy {
    uint256 public constant WAD = 1e18;
    uint256 public constant DAILY_INCREMENT = 1e16;

    function factor(uint256 elapsedDays) external pure returns (uint256 factorE18) {
        return WAD + elapsedDays * DAILY_INCREMENT;
    }
}

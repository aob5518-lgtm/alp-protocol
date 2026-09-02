// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ICompensationStrategy} from "../interfaces/ICompensationStrategy.sol";

/// @notice 1.01^days multiplier, in WAD precision. Exponentiation is intentionally bounded.
contract CompoundDailyCompensationStrategy is ICompensationStrategy {
    error ExponentTooLarge(uint256 elapsedDays);

    uint256 public constant WAD = 1e18;
    uint256 public constant DAILY_FACTOR = 1_010_000_000_000_000_000;
    uint256 public constant MAX_DAYS = 10_000;

    function factor(uint256 elapsedDays) external pure returns (uint256) {
        if (elapsedDays > MAX_DAYS) revert ExponentTooLarge(elapsedDays);
        uint256 result = WAD;
        uint256 base = DAILY_FACTOR;
        uint256 exponent = elapsedDays;
        while (exponent != 0) {
            if (exponent & 1 != 0) result = result * base / WAD;
            base = base * base / WAD;
            exponent >>= 1;
        }
        return result;
    }
}

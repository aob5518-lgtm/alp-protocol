// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockPair {
    uint256 public syncCount;

    function sync() external {
        syncCount++;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockTwapPair {
    address public immutable token0;
    address public immutable token1;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint112 internal reserve0;
    uint112 internal reserve1;
    uint32 internal timestampLast;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setState(
        uint256 cumulative0,
        uint256 cumulative1,
        uint112 reserve0_,
        uint112 reserve1_,
        uint32 timestamp_
    ) external {
        price0CumulativeLast = cumulative0;
        price1CumulativeLast = cumulative1;
        reserve0 = reserve0_;
        reserve1 = reserve1_;
        timestampLast = timestamp_;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, timestampLast);
    }
}

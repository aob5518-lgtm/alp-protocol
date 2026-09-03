// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MockLiquidityPair } from "./MockLiquidityPair.sol";

contract MockPancakeFactory {
    mapping(address => mapping(address => address)) internal pairs;

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB && tokenA != address(0) && tokenB != address(0), "pair");
        require(pairs[tokenA][tokenB] == address(0), "exists");
        pair = address(new MockLiquidityPair(tokenA, tokenB));
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
    }
}

contract MockPancakeLiquidityRouter {
    using SafeERC20 for IERC20;

    address public pair;
    uint16 public alpUsageBps = 10_000;

    function setPair(address pair_) external {
        pair = pair_;
    }

    function setAlpUsageBps(uint16 value) external {
        require(value <= 10_000, "bps");
        alpUsageBps = value;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(block.timestamp <= deadline, "expired");
        require(amountADesired >= amountAMin && amountBDesired >= amountBMin, "slippage");
        require(pair != address(0), "pair");
        // This deterministic test router consumes exact desired amounts and mints the
        // resulting LP directly to the requested receiver.
        amountA = amountADesired * alpUsageBps / 10_000;
        amountB = amountBDesired;
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        liquidity = amountA < amountB ? amountA : amountB;
        MockLiquidityPair(pair).mint(to, liquidity);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLiquidityPair is ERC20 {
    uint256 public syncCount;
    address public immutable token0;
    address public immutable token1;
    uint112 private reserve0;
    uint112 private reserve1;

    constructor(address token0_, address token1_) ERC20("Mock ALP-USDT LP", "MALP-LP") {
        token0 = token0_;
        token1 = token1_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function sync() external {
        syncCount++;
    }

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, uint32(block.timestamp));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLiquidityPair is ERC20 {
    uint256 public syncCount;

    constructor() ERC20("Mock ALP-USDT LP", "MALP-LP") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function sync() external {
        syncCount++;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockPancakeRouter {
    using SafeERC20 for IERC20;

    uint256 public rateWad;

    function setRateWad(uint256 rateWad_) external {
        rateWad = rateWad_;
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        returns (uint256[] memory amounts)
    {
        require(block.timestamp <= deadline, "expired");
        require(path.length == 2, "path");
        uint256 amountOut = amountIn * rateWad / 1e18;
        require(amountOut >= amountOutMin, "slippage");
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(path[1]).safeTransfer(to, amountOut);
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }
}

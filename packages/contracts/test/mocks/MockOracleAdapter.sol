// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPriceOracleAdapter} from "../../src/interfaces/IPriceOracleAdapter.sol";

contract MockOracleAdapter is IPriceOracleAdapter {
    uint256 public priceE18;
    uint256 public updatedAt;
    bool public valid = true;
    mapping(address => uint256) public tokenPriceE18;

    function setPrice(uint256 priceE18_, uint256 updatedAt_, bool valid_) external {
        priceE18 = priceE18_;
        updatedAt = updatedAt_;
        valid = valid_;
    }

    function setTokenPrice(address token, uint256 priceE18_) external {
        tokenPriceE18[token] = priceE18_;
    }

    function getPrice(address token) external view returns (uint256, uint256) {
        uint256 tokenPrice = tokenPriceE18[token];
        return (tokenPrice == 0 ? priceE18 : tokenPrice, updatedAt);
    }

    function isPriceValid(address) external view returns (bool) {
        return valid;
    }
}

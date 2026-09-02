// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPriceOracleAdapter} from "../../src/interfaces/IPriceOracleAdapter.sol";

contract MockOracleAdapter is IPriceOracleAdapter {
    uint256 public priceE18;
    uint256 public updatedAt;
    bool public valid = true;

    function setPrice(uint256 priceE18_, uint256 updatedAt_, bool valid_) external {
        priceE18 = priceE18_;
        updatedAt = updatedAt_;
        valid = valid_;
    }

    function getPrice(address) external view returns (uint256, uint256) {
        return (priceE18, updatedAt);
    }

    function isPriceValid(address) external view returns (bool) {
        return valid;
    }
}

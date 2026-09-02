// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IPriceOracleAdapter {
    /// @notice USD price of one whole partner-token unit, expressed in 1e18.
    function getPrice(address token) external view returns (uint256 priceE18, uint256 updatedAt);

    function isPriceValid(address token) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IPartnerAssetVault {
    function deposit(address from, uint256 amount, uint256 assetId, uint256 positionId) external;
}

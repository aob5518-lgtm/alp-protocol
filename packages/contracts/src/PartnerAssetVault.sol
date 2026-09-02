// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IPartnerAssetVault} from "./interfaces/IPartnerAssetVault.sol";

/// @notice Per-asset custody endpoint. Its configured policy is sealed after its first contribution.
contract PartnerAssetVault is Ownable2Step, IPartnerAssetVault {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error UnauthorizedPool(address caller);
    error StrategySealed();
    error InvalidStrategy();

    enum Strategy { LOCK, BURN, LIQUIDITY, TREASURY, REDEEM }

    IERC20 public immutable asset;
    Strategy public strategy;
    address public strategyRecipient;
    bool public strategySealed;
    mapping(address => bool) public authorizedPool;
    mapping(uint256 => uint256) public depositedForPosition;
    uint256 public totalDeposited;

    event PoolAuthorizationUpdated(address indexed pool, bool allowed);
    event StrategyConfigured(Strategy strategy, address indexed recipient);
    event PartnerAssetDeposited(
        uint256 indexed assetId, uint256 indexed positionId, address indexed user, uint256 amount, Strategy strategy
    );

    constructor(address initialOwner, IERC20 asset_, Strategy strategy_, address strategyRecipient_)
        Ownable(initialOwner)
    {
        if (initialOwner == address(0) || address(asset_) == address(0)) revert ZeroAddress();
        asset = asset_;
        _setStrategy(strategy_, strategyRecipient_);
    }

    function setPoolAuthorization(address pool, bool allowed) external onlyOwner {
        if (pool == address(0)) revert ZeroAddress();
        authorizedPool[pool] = allowed;
        emit PoolAuthorizationUpdated(pool, allowed);
    }

    function configureStrategy(Strategy strategy_, address recipient) external onlyOwner {
        if (strategySealed) revert StrategySealed();
        _setStrategy(strategy_, recipient);
    }

    function deposit(address from, uint256 amount, uint256 assetId, uint256 positionId) external {
        if (!authorizedPool[msg.sender]) revert UnauthorizedPool(msg.sender);
        strategySealed = true;
        totalDeposited += amount;
        depositedForPosition[positionId] = amount;
        asset.safeTransferFrom(from, address(this), amount);
        if (strategy != Strategy.LOCK) asset.safeTransfer(strategyRecipient, amount);
        emit PartnerAssetDeposited(assetId, positionId, from, amount, strategy);
    }

    function _setStrategy(Strategy strategy_, address recipient) private {
        if (strategy_ > Strategy.REDEEM) revert InvalidStrategy();
        // LOCK retains funds locally. Every distribution strategy needs an explicit, non-zero receiver.
        if (strategy_ != Strategy.LOCK && recipient == address(0)) revert ZeroAddress();
        strategy = strategy_;
        strategyRecipient = recipient;
        emit StrategyConfigured(strategy_, recipient);
    }
}

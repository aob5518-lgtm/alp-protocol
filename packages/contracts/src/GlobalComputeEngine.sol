// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IGlobalComputeEngine} from "./interfaces/IGlobalComputeEngine.sol";

/// @notice O(1) reward accounting across all pools. It never loops through users when an epoch is settled.
contract GlobalComputeEngine is AccessControl, ReentrancyGuard, IGlobalComputeEngine {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error PositionAlreadyExists(uint256 positionId);
    error PositionNotFound(uint256 positionId);
    error NotPositionOwner(address caller, uint256 positionId);
    error InvalidCompute();

    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    bytes32 public constant POOL_FACTORY_ROLE = keccak256("POOL_FACTORY_ROLE");
    bytes32 public constant EMISSION_ROLE = keccak256("EMISSION_ROLE");
    uint256 public constant ACC_PRECISION = 1e27;

    struct ComputePosition {
        address owner;
        uint128 effectiveCompute;
        uint256 rewardDebt;
    }

    IERC20 public immutable alp;
    uint256 public globalEffectiveCompute;
    uint256 public accRewardPerCompute;
    uint256 public totalEmitted;
    uint256 public totalClaimed;
    uint256 public undistributedEmission;
    mapping(uint256 => ComputePosition) public positions;

    event PositionAdded(uint256 indexed positionId, address indexed user, uint256 effectiveCompute);
    event EmissionNotified(uint256 amount, uint256 accRewardPerCompute, uint256 globalEffectiveCompute);
    event EmissionDeferred(uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed positionId, uint256 amount);

    constructor(IERC20 alp_, address admin) {
        if (address(alp_) == address(0) || admin == address(0)) revert ZeroAddress();
        alp = alp_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function addPosition(uint256 positionId, address user, uint256 effectiveCompute) external onlyRole(POOL_ROLE) {
        if (user == address(0)) revert ZeroAddress();
        if (positions[positionId].owner != address(0)) revert PositionAlreadyExists(positionId);
        if (effectiveCompute == 0 || effectiveCompute > type(uint128).max) revert InvalidCompute();
        positions[positionId] = ComputePosition({
            owner: user,
            effectiveCompute: uint128(effectiveCompute),
            rewardDebt: effectiveCompute * accRewardPerCompute / ACC_PRECISION
        });
        globalEffectiveCompute += effectiveCompute;
        emit PositionAdded(positionId, user, effectiveCompute);
    }

    function registerPool(address pool) external onlyRole(POOL_FACTORY_ROLE) {
        if (pool == address(0)) revert ZeroAddress();
        _grantRole(POOL_ROLE, pool);
    }

    function notifyEmission(uint256 amount) external onlyRole(EMISSION_ROLE) {
        totalEmitted += amount;
        uint256 totalCompute = globalEffectiveCompute;
        if (totalCompute == 0) {
            undistributedEmission += amount;
            emit EmissionDeferred(amount);
            return;
        }
        accRewardPerCompute += amount * ACC_PRECISION / totalCompute;
        emit EmissionNotified(amount, accRewardPerCompute, totalCompute);
    }

    function pending(uint256 positionId) public view returns (uint256) {
        ComputePosition storage position = positions[positionId];
        if (position.owner == address(0)) revert PositionNotFound(positionId);
        return uint256(position.effectiveCompute) * accRewardPerCompute / ACC_PRECISION - position.rewardDebt;
    }

    function claim(uint256 positionId, address recipient) external nonReentrant returns (uint256 amount) {
        ComputePosition storage position = positions[positionId];
        if (position.owner == address(0)) revert PositionNotFound(positionId);
        if (msg.sender != position.owner) revert NotPositionOwner(msg.sender, positionId);
        if (recipient == address(0)) revert ZeroAddress();
        amount = uint256(position.effectiveCompute) * accRewardPerCompute / ACC_PRECISION - position.rewardDebt;
        position.rewardDebt += amount;
        totalClaimed += amount;
        if (amount != 0) alp.safeTransfer(recipient, amount);
        emit RewardClaimed(position.owner, positionId, amount);
    }
}

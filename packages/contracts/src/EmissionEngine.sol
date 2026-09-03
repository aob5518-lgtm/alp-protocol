// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ALPToken } from "./ALPToken.sol";
import { GlobalComputeEngine } from "./GlobalComputeEngine.sol";
import { IProtocolController } from "./interfaces/IProtocolController.sol";

interface IPancakeV2Pair {
    function sync() external;
}

/// @notice Permissionless daily settlement using the MainPair ALP balance at the start of each epoch.
contract EmissionEngine is Ownable2Step {
    error ZeroAddress();
    error EpochNotReady(uint64 nextEpochTime, uint256 currentTime);
    error InsufficientPairReserve(uint256 reserveBefore, uint256 required);
    error EmissionNotActivated();
    error NoGlobalCompute();
    error EmissionScheduleNotApproved();
    error ProtocolControllerAlreadyConfigured();

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant INITIAL_OUTPUT_BPS = 60;
    uint256 public constant DAILY_OUTPUT_INCREMENT_BPS = 1;
    uint256 public constant MAX_OUTPUT_BPS = 120;
    uint256 public constant BURN_BPS = 120;
    bytes32 public constant V1_SCHEDULE_HASH = keccak256("ALP_V1_EMISSION_DAY60_120_BPS");

    ALPToken public immutable alp;
    GlobalComputeEngine public immutable computeEngine;
    address public immutable mainPair;
    uint64 public immutable firstEpochTime;
    uint64 public nextEpochTime;
    uint64 public emissionStartTime;
    bool public emissionActivated;
    bool public emissionScheduleApproved;
    IProtocolController public protocolController;
    uint256 public epochId;

    struct Epoch {
        uint64 timestamp;
        uint256 reserveBefore;
        uint256 burnAmount;
        uint256 emissionAmount;
        uint256 reserveAfter;
        uint16 outputRateBps;
        uint16 burnRateBps;
    }

    mapping(uint256 => Epoch) public epochs;

    event EpochSettled(
        uint256 indexed epochId,
        uint64 timestamp,
        uint256 reserveBefore,
        uint256 burnAmount,
        uint256 emissionAmount,
        uint256 reserveAfter,
        uint16 outputRateBps,
        uint16 burnRateBps,
        address indexed caller
    );
    event EmissionActivated(
        uint64 indexed emissionStartTime, uint64 firstEpochTime, address indexed caller
    );
    event EmissionScheduleApproved(bytes32 indexed scheduleHash, address indexed governance);
    event ProtocolControllerConfigured(address indexed controller);

    constructor(
        ALPToken alp_,
        GlobalComputeEngine computeEngine_,
        address mainPair_,
        uint64 firstEpochTime_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (
            address(alp_) == address(0) || address(computeEngine_) == address(0)
                || mainPair_ == address(0) || initialOwner == address(0)
        ) revert ZeroAddress();
        alp = alp_;
        computeEngine = computeEngine_;
        mainPair = mainPair_;
        firstEpochTime = firstEpochTime_;
        nextEpochTime = firstEpochTime_;
    }

    /// @notice The first epoch cannot start until actual user compute exists.
    function approveV1EmissionSchedule() external onlyOwner {
        if (!emissionScheduleApproved) {
            emissionScheduleApproved = true;
            emit EmissionScheduleApproved(V1_SCHEDULE_HASH, msg.sender);
        }
    }

    function configureProtocolController(IProtocolController controller) external onlyOwner {
        if (address(controller) == address(0)) revert ZeroAddress();
        if (address(protocolController) != address(0)) {
            revert ProtocolControllerAlreadyConfigured();
        }
        protocolController = controller;
        emit ProtocolControllerConfigured(address(controller));
    }

    /// @notice The first epoch cannot start until actual user compute and governance schedule approval exist.
    function activateEmission() external onlyOwner {
        if (emissionActivated) revert EmissionNotActivated();
        if (!emissionScheduleApproved) revert EmissionScheduleNotApproved();
        if (computeEngine.globalEffectiveCompute() == 0) revert NoGlobalCompute();
        emissionActivated = true;
        emissionStartTime = uint64(block.timestamp);
        nextEpochTime = uint64(block.timestamp);
        emit EmissionActivated(emissionStartTime, nextEpochTime, msg.sender);
    }

    function outputRateBps(uint256 epochId_) public pure returns (uint16) {
        // The approved schedule fixes day 60 at 120 BPS. Days 1-59 rise one BPS from 60;
        // the final transition is intentionally capped to satisfy that explicit launch parameter.
        if (epochId_ >= 60) return uint16(MAX_OUTPUT_BPS);
        uint256 rate = INITIAL_OUTPUT_BPS + (epochId_ - 1) * DAILY_OUTPUT_INCREMENT_BPS;
        return uint16(rate);
    }

    function settleEpoch() external returns (uint256 settledEpochId) {
        if (address(protocolController) != address(0)) protocolController.requireOperational();
        if (!emissionActivated) revert EmissionNotActivated();
        if (block.timestamp < nextEpochTime) revert EpochNotReady(nextEpochTime, block.timestamp);
        settledEpochId = ++epochId;
        uint16 rate = outputRateBps(settledEpochId);
        uint256 reserveBefore = alp.balanceOf(mainPair);
        uint256 burnAmount = reserveBefore * BURN_BPS / BPS_DENOMINATOR;
        uint256 emissionAmount = reserveBefore * rate / BPS_DENOMINATOR;
        if (burnAmount + emissionAmount > reserveBefore) {
            revert InsufficientPairReserve(reserveBefore, burnAmount + emissionAmount);
        }

        if (burnAmount != 0) alp.burnFromMainPair(burnAmount);
        if (emissionAmount != 0) {
            alp.transferEmission(address(computeEngine), emissionAmount);
            computeEngine.notifyEmission(emissionAmount);
        }
        IPancakeV2Pair(mainPair).sync();
        uint256 reserveAfter = alp.balanceOf(mainPair);
        uint64 settledAt = uint64(block.timestamp);
        epochs[settledEpochId] = Epoch({
            timestamp: settledAt,
            reserveBefore: reserveBefore,
            burnAmount: burnAmount,
            emissionAmount: emissionAmount,
            reserveAfter: reserveAfter,
            outputRateBps: rate,
            burnRateBps: uint16(BURN_BPS)
        });
        // Preserve the established cadence even if settlement happens late; no double settlement is possible.
        nextEpochTime = emissionStartTime + uint64(settledEpochId) * 1 days;
        emit EpochSettled(
            settledEpochId,
            settledAt,
            reserveBefore,
            burnAmount,
            emissionAmount,
            reserveAfter,
            rate,
            uint16(BURN_BPS),
            msg.sender
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ALPToken} from "./ALPToken.sol";
import {ILiquidityCycleManager} from "./interfaces/ILiquidityCycleManager.sol";

/// @notice Permissionless settlement for the four post-receipt liquidity cycles.
/// @dev Transferred-away balances become a burn debt which is settled on future ALP receipts.
contract LiquidityCycleManager is ILiquidityCycleManager {
    error ZeroAddress();
    error OnlyToken(address caller);
    error CycleNotStarted(address account);
    error CycleNotMature(uint8 cycle, uint256 requiredTime, uint256 currentTime);
    error CycleAlreadySettled(address account, uint8 cycle);
    error InvalidCycle(uint8 cycle);

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint64 public constant CYCLE_DURATION = 15 days;
    uint8 public constant CYCLE_COUNT = 4;

    struct AccountCycle {
        uint64 startedAt;
        uint256 baselineAmount;
        uint256 burnDebt;
        uint8 settledMask;
        uint256[4] soldAmount;
        uint256[4] forcedBurned;
    }

    ALPToken public immutable alp;
    mapping(address => AccountCycle) private _cycles;

    event CycleStarted(address indexed account, uint256 baselineAmount, uint64 startedAt);
    event SellCredited(address indexed account, uint8 indexed cycle, uint256 grossAmount, uint256 cycleSoldAmount);
    event ForcedBurnSettled(
        address indexed account, uint8 indexed cycle, uint256 requiredAmount, uint256 soldAmount, uint256 burnedNow, uint256 burnDebt
    );
    event BurnDebtSettled(address indexed account, uint256 burnedNow, uint256 remainingDebt);

    constructor(ALPToken alp_) {
        if (address(alp_) == address(0)) revert ZeroAddress();
        alp = alp_;
    }

    modifier onlyToken() {
        if (msg.sender != address(alp)) revert OnlyToken(msg.sender);
        _;
    }

    function onAlpReceived(address account, uint256 amount) external onlyToken {
        AccountCycle storage cycle = _cycles[account];
        if (cycle.startedAt == 0) {
            cycle.startedAt = uint64(block.timestamp);
            cycle.baselineAmount = amount;
            emit CycleStarted(account, amount, cycle.startedAt);
        }
        _settleDebt(account, cycle);
    }

    function onAlpSold(address account, uint256 grossAmount) external onlyToken {
        AccountCycle storage cycle = _cycles[account];
        if (cycle.startedAt == 0) return;
        uint8 current = currentCycle(account);
        if (current >= CYCLE_COUNT) return;
        cycle.soldAmount[current] += grossAmount;
        emit SellCredited(account, current, grossAmount, cycle.soldAmount[current]);
    }

    /// @notice Anyone (including a keeper) can settle an overdue cycle for an account.
    function settleOverdueCycle(address account, uint8 cycleIndex) external returns (uint256 burnedNow) {
        if (cycleIndex >= CYCLE_COUNT) revert InvalidCycle(cycleIndex);
        AccountCycle storage cycle = _cycles[account];
        if (cycle.startedAt == 0) revert CycleNotStarted(account);
        uint256 dueAt = uint256(cycle.startedAt) + uint256(cycleIndex + 1) * CYCLE_DURATION;
        if (block.timestamp < dueAt) revert CycleNotMature(cycleIndex, dueAt, block.timestamp);
        uint8 flag = uint8(1 << cycleIndex);
        if (cycle.settledMask & flag != 0) revert CycleAlreadySettled(account, cycleIndex);
        cycle.settledMask |= flag;
        uint256 requiredAmount = cycle.baselineAmount * cycleRequirementBps(cycleIndex) / BPS_DENOMINATOR;
        uint256 missingAmount = requiredAmount > cycle.soldAmount[cycleIndex] ? requiredAmount - cycle.soldAmount[cycleIndex] : 0;
        cycle.burnDebt += missingAmount;
        burnedNow = _settleDebt(account, cycle);
        cycle.forcedBurned[cycleIndex] = burnedNow;
        emit ForcedBurnSettled(
            account, cycleIndex, requiredAmount, cycle.soldAmount[cycleIndex], burnedNow, cycle.burnDebt
        );
    }

    function currentCycle(address account) public view returns (uint8) {
        AccountCycle storage cycle = _cycles[account];
        if (cycle.startedAt == 0) return CYCLE_COUNT;
        uint256 elapsed = block.timestamp - cycle.startedAt;
        uint256 index = elapsed / CYCLE_DURATION;
        return index >= CYCLE_COUNT ? CYCLE_COUNT : uint8(index);
    }

    function cycleRequirementBps(uint8 cycleIndex) public pure returns (uint16) {
        if (cycleIndex == 0) return 2_000;
        if (cycleIndex == 1) return 1_500;
        if (cycleIndex == 2) return 1_000;
        if (cycleIndex == 3) return 500;
        revert InvalidCycle(cycleIndex);
    }

    function cycleState(address account)
        external
        view
        returns (uint64 startedAt, uint256 baselineAmount, uint256 burnDebt, uint8 settledMask)
    {
        AccountCycle storage cycle = _cycles[account];
        return (cycle.startedAt, cycle.baselineAmount, cycle.burnDebt, cycle.settledMask);
    }

    function cycleProgress(address account, uint8 cycleIndex)
        external
        view
        returns (uint256 requiredAmount, uint256 soldAmount, uint256 forcedBurned, bool settled)
    {
        if (cycleIndex >= CYCLE_COUNT) revert InvalidCycle(cycleIndex);
        AccountCycle storage cycle = _cycles[account];
        requiredAmount = cycle.baselineAmount * cycleRequirementBps(cycleIndex) / BPS_DENOMINATOR;
        soldAmount = cycle.soldAmount[cycleIndex];
        forcedBurned = cycle.forcedBurned[cycleIndex];
        settled = cycle.settledMask & uint8(1 << cycleIndex) != 0;
    }

    function _settleDebt(address account, AccountCycle storage cycle) private returns (uint256 burnedNow) {
        uint256 debt = cycle.burnDebt;
        if (debt == 0) return 0;
        uint256 balance = alp.balanceOf(account);
        burnedNow = balance < debt ? balance : debt;
        if (burnedNow != 0) {
            cycle.burnDebt = debt - burnedNow;
            alp.protocolBurn(account, burnedNow);
            emit BurnDebtSettled(account, burnedNow, cycle.burnDebt);
        }
    }
}

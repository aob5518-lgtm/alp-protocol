// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ALPToken} from "./ALPToken.sol";
import {ILiquidityCycleManager} from "./interfaces/ILiquidityCycleManager.sol";

/// @notice Enforces four independent, 15-day post-receipt liquidity cycles.
/// @dev A cycle snapshot is taken before any balance-changing transfer at or after
/// its start. Therefore incoming ALP during a cycle is intentionally deferred to
/// the next cycle's snapshot rather than increasing the current obligation.
contract LiquidityCycleManager is ILiquidityCycleManager {
    error ZeroAddress();
    error OnlyToken(address caller);
    error CycleNotStarted(address account);
    error CycleNotMature(uint8 cycle, uint256 requiredTime, uint256 currentTime);
    error CycleAlreadySettled(address account, uint8 cycle);
    error InvalidCycle(uint8 cycle);
    error LiquidityObligationViolation(address account, uint256 remainingBalance, uint256 requiredReserve);

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint64 public constant CYCLE_DURATION = 15 days;
    uint8 public constant CYCLE_COUNT = 4;

    struct AccountCycle {
        uint64 startedAt;
        uint64[4] cycleStartTime;
        uint256[4] cycleBaseline;
        uint256[4] requiredAmount;
        uint256[4] soldAmount;
        uint256[4] forcedBurned;
        uint256 burnDebt;
        uint8 settledMask;
    }

    ALPToken public immutable alp;
    mapping(address => AccountCycle) private _cycles;

    event CycleStarted(address indexed account, uint256 baselineAmount, uint64 startedAt);
    event CycleSnapshotTaken(
        address indexed account, uint8 indexed cycle, uint64 cycleStartTime, uint256 baselineAmount, uint256 requiredAmount
    );
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

    /// @notice Called after a recipient balance increases. First receipt starts cycle one;
    /// later incoming ALP does not mutate any existing cycle baseline.
    function onAlpReceived(address account, uint256) external onlyToken {
        AccountCycle storage cycle = _cycles[account];
        if (cycle.startedAt == 0) {
            cycle.startedAt = uint64(block.timestamp);
            cycle.cycleStartTime[0] = cycle.startedAt;
            uint256 baseline = alp.balanceOf(account);
            cycle.cycleBaseline[0] = baseline;
            cycle.requiredAmount[0] = baseline * cycleRequirementBps(0) / BPS_DENOMINATOR;
            emit CycleStarted(account, baseline, cycle.startedAt);
            emit CycleSnapshotTaken(account, 0, cycle.startedAt, baseline, cycle.requiredAmount[0]);
        }
        _settleDebt(account, cycle);
    }

    /// @notice Called by ALP before an ordinary wallet transfer. Snapshots are made
    /// before balance movement, then the sender must retain the current obligation.
    function beforeAlpTransfer(address from, address to, uint256 amount) external onlyToken {
        _syncSnapshots(from, _cycles[from]);
        if (to != from) _syncSnapshots(to, _cycles[to]);

        AccountCycle storage cycle = _cycles[from];
        if (cycle.startedAt == 0) return;
        uint256 reserve = _totalOutstandingObligation(cycle);
        if (reserve == 0) return;
        uint256 balance = alp.balanceOf(from);
        uint256 remainingBalance = amount > balance ? 0 : balance - amount;
        if (remainingBalance < reserve) {
            revert LiquidityObligationViolation(from, remainingBalance, reserve);
        }
    }

    function onAlpSold(address account, uint256 grossAmount) external onlyToken {
        AccountCycle storage cycle = _cycles[account];
        if (cycle.startedAt == 0) return;
        _syncSnapshots(account, cycle);
        uint8 current = currentCycle(account);
        if (current >= CYCLE_COUNT) return;
        cycle.soldAmount[current] += grossAmount;
        emit SellCredited(account, current, grossAmount, cycle.soldAmount[current]);
    }

    /// @notice Permissionless snapshot function for keepers/UI. It can be invoked
    /// after a cycle starts and is idempotent.
    function snapshotCycles(address account) external {
        _syncSnapshots(account, _cycles[account]);
    }

    /// @notice Anyone can settle an overdue cycle; missed sells are burned or carried as debt.
    function settleOverdueCycle(address account, uint8 cycleIndex) external returns (uint256 burnedNow) {
        if (cycleIndex >= CYCLE_COUNT) revert InvalidCycle(cycleIndex);
        AccountCycle storage cycle = _cycles[account];
        if (cycle.startedAt == 0) revert CycleNotStarted(account);
        _syncSnapshots(account, cycle);
        uint256 dueAt = uint256(cycle.startedAt) + uint256(cycleIndex + 1) * CYCLE_DURATION;
        if (block.timestamp < dueAt) revert CycleNotMature(cycleIndex, dueAt, block.timestamp);
        uint8 flag = uint8(1 << cycleIndex);
        if (cycle.settledMask & flag != 0) revert CycleAlreadySettled(account, cycleIndex);
        cycle.settledMask |= flag;
        uint256 required = cycle.requiredAmount[cycleIndex];
        uint256 missing = required > cycle.soldAmount[cycleIndex] ? required - cycle.soldAmount[cycleIndex] : 0;
        cycle.burnDebt += missing;
        burnedNow = _settleDebt(account, cycle);
        cycle.forcedBurned[cycleIndex] = burnedNow;
        emit ForcedBurnSettled(account, cycleIndex, required, cycle.soldAmount[cycleIndex], burnedNow, cycle.burnDebt);
    }

    function currentCycle(address account) public view returns (uint8) {
        AccountCycle storage cycle = _cycles[account];
        if (cycle.startedAt == 0) return CYCLE_COUNT;
        uint256 index = (block.timestamp - cycle.startedAt) / CYCLE_DURATION;
        return index >= CYCLE_COUNT ? CYCLE_COUNT : uint8(index);
    }

    function outstandingObligation(address account) public view returns (uint256) {
        AccountCycle storage cycle = _cycles[account];
        if (cycle.startedAt == 0) return 0;
        return _totalOutstandingObligation(cycle);
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
        return (cycle.startedAt, cycle.cycleBaseline[0], cycle.burnDebt, cycle.settledMask);
    }

    function cycleProgress(address account, uint8 cycleIndex)
        external
        view
        returns (uint256 requiredAmount, uint256 soldAmount, uint256 forcedBurned, bool settled)
    {
        if (cycleIndex >= CYCLE_COUNT) revert InvalidCycle(cycleIndex);
        AccountCycle storage cycle = _cycles[account];
        return (
            cycle.requiredAmount[cycleIndex],
            cycle.soldAmount[cycleIndex],
            cycle.forcedBurned[cycleIndex],
            cycle.settledMask & uint8(1 << cycleIndex) != 0
        );
    }

    function cycleSnapshot(address account, uint8 cycleIndex)
        external
        view
        returns (uint64 startTime, uint256 baseline, uint256 required)
    {
        if (cycleIndex >= CYCLE_COUNT) revert InvalidCycle(cycleIndex);
        AccountCycle storage cycle = _cycles[account];
        return (cycle.cycleStartTime[cycleIndex], cycle.cycleBaseline[cycleIndex], cycle.requiredAmount[cycleIndex]);
    }

    function _syncSnapshots(address account, AccountCycle storage cycle) private {
        if (cycle.startedAt == 0) return;
        for (uint8 i = 1; i < CYCLE_COUNT; ++i) {
            if (cycle.cycleStartTime[i] != 0) continue;
            uint64 startTime = cycle.startedAt + uint64(i) * CYCLE_DURATION;
            if (block.timestamp < startTime) break;
            uint256 baseline = alp.balanceOf(account);
            cycle.cycleStartTime[i] = startTime;
            cycle.cycleBaseline[i] = baseline;
            cycle.requiredAmount[i] = baseline * cycleRequirementBps(i) / BPS_DENOMINATOR;
            emit CycleSnapshotTaken(account, i, startTime, baseline, cycle.requiredAmount[i]);
        }
    }

    function _outstandingObligation(AccountCycle storage cycle, uint8 cycleIndex) private view returns (uint256) {
        if (cycleIndex >= CYCLE_COUNT || cycle.cycleStartTime[cycleIndex] == 0) return 0;
        uint256 required = cycle.requiredAmount[cycleIndex];
        uint256 sold = cycle.soldAmount[cycleIndex];
        return required > sold ? required - sold : 0;
    }

    /// @dev Includes burn debt and every taken-but-unsettled cycle, preventing cross-cycle transfer escape.
    function _totalOutstandingObligation(AccountCycle storage cycle) private view returns (uint256 total) {
        total = cycle.burnDebt;
        for (uint8 i; i < CYCLE_COUNT; ++i) {
            if (cycle.cycleStartTime[i] == 0 || cycle.settledMask & uint8(1 << i) != 0) continue;
            total += _outstandingObligation(cycle, i);
        }
    }

    function _settleDebt(address account, AccountCycle storage cycle) private returns (uint256 burnedNow) {
        uint256 debt = cycle.burnDebt;
        if (debt == 0) return 0;
        uint256 balance = alp.balanceOf(account);
        burnedNow = balance < debt ? balance : debt;
        if (burnedNow != 0) {
            cycle.burnDebt = debt - burnedNow;
            alp.forceBurnForLiquidityCycle(account, burnedNow);
            emit BurnDebtSettled(account, burnedNow, cycle.burnDebt);
        }
    }
}

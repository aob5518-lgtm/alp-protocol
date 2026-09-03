/**
 * Unlimited-depth tier aggregation. It is deliberately iterative (no recursive call stack),
 * deterministic at a fixed block, and produces data that can be independently re-derived from
 * SponsorBound and PositionCreated events.
 */
export type PositionFact = {wallet: string; totalPositionValue: bigint; usdtContribution: bigint};
export type TierRow = {wallet: string; totalNetworkVolume: bigint; largestBranch: string; largestBranchVolume: bigint; smallDistrictVolume: bigint; tier: number};
export type VolumeBase = "TOTAL_POSITION_VALUE" | "USDT_CONTRIBUTION";
const thresholds = [0n, 3_000n * 10n ** 18n, 10_000n * 10n ** 18n, 30_000n * 10n ** 18n, 100_000n * 10n ** 18n, 300_000n * 10n ** 18n, 1_000_000n * 10n ** 18n, 3_000_000n * 10n ** 18n, 6_000_000n * 10n ** 18n, 10_000_000n * 10n ** 18n];
export function aggregateUnlimitedTier(sponsors: Map<string, string>, positions: PositionFact[], base: VolumeBase): TierRow[] {
  const totals = new Map<string, bigint>(), branches = new Map<string, Map<string, bigint>>();
  for (const position of positions) {
    const volume = base === "TOTAL_POSITION_VALUE" ? position.totalPositionValue : position.usdtContribution;
    let child = position.wallet.toLowerCase(), cursor = child; const seen = new Set<string>([child]);
    while (sponsors.has(cursor)) {
      const upline = sponsors.get(cursor)!; if (seen.has(upline)) throw new Error(`Sponsor cycle at ${upline}`); seen.add(upline);
      totals.set(upline, (totals.get(upline) ?? 0n) + volume);
      const byBranch = branches.get(upline) ?? new Map<string, bigint>(); branches.set(upline, byBranch);
      byBranch.set(child, (byBranch.get(child) ?? 0n) + volume);
      child = upline; cursor = upline;
    }
  }
  return [...totals].map(([wallet, totalNetworkVolume]) => {
    const byBranch = branches.get(wallet)!; let largestBranch = "0x0000000000000000000000000000000000000000", largestBranchVolume = 0n;
    for (const [branch, value] of byBranch) if (value > largestBranchVolume) { largestBranch = branch; largestBranchVolume = value; }
    const smallDistrictVolume = totalNetworkVolume - largestBranchVolume; let tier = 0; for (let i = 9; i >= 1; i--) if (smallDistrictVolume >= thresholds[i]) { tier = i; break; }
    return {wallet, totalNetworkVolume, largestBranch, largestBranchVolume, smallDistrictVolume, tier};
  });
}

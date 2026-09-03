import {strict as assert} from "node:assert";
import {aggregateUnlimitedTier} from "./tier-snapshot.js";
const sponsors = new Map<string,string>(); for (let i=1; i<=500; i++) sponsors.set(`u${i}`, `u${i-1}`);
const rows = aggregateUnlimitedTier(sponsors, [{wallet:"u500", totalPositionValue: 4_000n * 10n**18n, usdtContribution:0n}], "TOTAL_POSITION_VALUE");
assert.equal(rows.find(row => row.wallet === "u0")?.totalNetworkVolume, 4_000n * 10n**18n);
console.log("500-depth aggregation passed");

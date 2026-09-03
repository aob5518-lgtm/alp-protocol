import {strict as assert} from "node:assert";
import {aggregateUnlimitedTier} from "./tier-snapshot.js";
const e18=10n**18n;
for (const depth of [100,500,1_000]) {
  const sponsors = new Map<string,string>(); for (let i=1; i<=depth; i++) sponsors.set(`u${i}`, `u${i-1}`);
  const rows = aggregateUnlimitedTier(sponsors, [{wallet:`u${depth}`, totalPositionValue: 4_000n * e18, usdtContribution:0n}], "TOTAL_POSITION_VALUE");
  assert.equal(rows.find(row => row.wallet === "u0")?.totalNetworkVolume, 4_000n * e18);
}
for (const users of [10_000,100_000]) {
  const sponsors = new Map<string,string>(), positions=[] as {wallet:string;totalPositionValue:bigint;usdtContribution:bigint}[];
  for(let i=1;i<=users;i++) { sponsors.set(`u${i}`,"root"); positions.push({wallet:`u${i}`,totalPositionValue:e18,usdtContribution:0n}); }
  const root=aggregateUnlimitedTier(sponsors,positions,"TOTAL_POSITION_VALUE").find(row=>row.wallet==="root");
  assert.equal(root?.totalNetworkVolume,BigInt(users)*e18); assert.equal(root?.smallDistrictVolume,BigInt(users-1)*e18);
}
console.log("unlimited-depth and 100k-user aggregation passed");

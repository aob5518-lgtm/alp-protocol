import {mkdir, writeFile} from "node:fs/promises";
import {join} from "node:path";

type Day = {day:number; users:number; principal:number; reserve:number; emitted:number; burned:number; rewardRate:number};
const days: Day[] = [];
let users = 100, reserve = 3_000_000, emitted = 0, burned = 0;
for (let day = 1; day <= 365; day++) {
  // Logistic onboarding: 100 users on day 1 approaches 100k without claiming this is a forecast.
  users = Math.min(100_000, Math.round(users + Math.max(3, users * (0.028 - users / 4_000_000))));
  const principal = users * (105 + (day % 17) * 7);
  const grossFees = principal * 0.17;
  const buyback = grossFees * 0.05;
  burned += buyback / Math.max(0.000001, 0.09 + day * 0.00003);
  const rewardRate = reserve > 0 ? Math.min(0.01, reserve / Math.max(principal * 365, 1)) : 0;
  const dayEmission = Math.min(reserve, principal * rewardRate);
  reserve -= dayEmission; emitted += dayEmission;
  days.push({day, users, principal, reserve, emitted, burned, rewardRate});
}
async function writeScenario() {
  const out = join(process.cwd(), "artifacts", "economics"); await mkdir(out, {recursive:true});
  await writeFile(join(out, "365-day-simulation.csv"), ["day,users,principal,reserve,emitted,burned,rewardRate", ...days.map(d => [d.day,d.users,d.principal.toFixed(2),d.reserve.toFixed(2),d.emitted.toFixed(2),d.burned.toFixed(2),d.rewardRate.toFixed(8)].join(","))].join("\n"));
  const max = Math.max(...days.map(d => d.users)); const path = days.map((d,i) => `${i === 0 ? "M" : "L"}${(i / 364 * 1000).toFixed(1)},${(360 - d.users / max * 320).toFixed(1)}`).join(" ");
  await writeFile(join(out, "365-day-users.svg"), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 400"><rect width="1000" height="400" fill="#07111f"/><path d="${path}" fill="none" stroke="#65d8ff" stroke-width="5"/><text x="32" y="48" fill="#eaf5ff" font-family="sans-serif" font-size="24">ALP simulation — users (scenario, not forecast)</text></svg>`);
  console.log(`Scenario written to ${out}; final users=${days.at(-1)?.users}, reserve=${days.at(-1)?.reserve.toFixed(2)}`);
}
void writeScenario();

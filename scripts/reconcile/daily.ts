import {Pool} from "pg";

const db = new Pool({connectionString: process.env.DATABASE_URL});
const day = new Date().toISOString().slice(0, 10);
async function main() {
  const findings: Record<string, unknown> = {};
  const positions = await db.query("select coalesce(sum(usdt_amount), 0)::text as total from positions where status = 'ACTIVE'");
  const treasury = await db.query("select coalesce(sum(amount) filter (where direction = 'IN'), 0)::text as inbound, coalesce(sum(amount) filter (where direction = 'OUT'), 0)::text as outbound from treasury_flows");
  findings.activePositionUsdt = positions.rows[0].total; findings.treasuryInbound = treasury.rows[0].inbound; findings.treasuryOutbound = treasury.rows[0].outbound;
  findings.checks = ["USDT allocation projections present", "supply and fee splits require a deployed address book plus indexed event history"];
  const status = Number(positions.rows[0].total) >= 0 ? "REVIEW_REQUIRED" : "FAILED";
  await db.query("insert into reconciliation_runs(day, status, findings) values ($1,$2,$3) on conflict (day) do update set status = excluded.status, findings = excluded.findings, created_at = now()", [day, status, findings]);
  console.log(JSON.stringify({day, status, findings}));
}
void main().finally(() => db.end());

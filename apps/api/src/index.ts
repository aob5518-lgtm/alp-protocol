import {randomUUID} from "node:crypto";
import {createServer, type IncomingMessage, type ServerResponse} from "node:http";
import {Pool} from "pg";
import {createNonce, hasRole, issueSession, readSession, verifySiwe, type Role} from "./auth.js";

const port = Number(process.env.API_PORT ?? 4000);
const pool = new Pool({connectionString: process.env.DATABASE_URL});
const json = (res: ServerResponse, status: number, body: unknown) => { res.writeHead(status, {"content-type":"application/json", "cache-control":"no-store"}); res.end(JSON.stringify(body)); };
const requestBody = async (req: IncomingMessage) => new Promise<string>((resolve, reject) => { let value = ""; req.on("data", chunk => { value += chunk; if (value.length > 65_536) reject(new Error("body_too_large")); }); req.on("end", () => resolve(value)); req.on("error", reject); });
const bearer = (req: IncomingMessage) => readSession(req.headers.authorization?.replace(/^Bearer\s+/i, ""));

createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
    if (url.pathname === "/health") { await pool.query("select 1"); return json(res, 200, {ok:true}); }
    if (req.method === "GET" && url.pathname === "/v1/auth/nonce") return json(res, 200, {nonce:await createNonce(pool)});
    if (req.method === "POST" && url.pathname === "/v1/auth/siwe") { const body = JSON.parse(await requestBody(req)) as {message:string; signature:`0x${string}`}; return json(res, 200, {session:issueSession(await verifySiwe(pool, body.message, body.signature))}); }
    if (url.pathname === "/v1/assets") return json(res, 200, (await pool.query("select asset_id, token_address, symbol, name, launch_status, risk_status, sealed from assets order by asset_id")).rows);
    if (url.pathname === "/v1/protocol") { const [assets, positions, epochs] = await Promise.all([pool.query("select count(*)::int as value from assets"), pool.query("select count(*)::int as value from positions where status = 'ACTIVE'"), pool.query("select epoch_id, output_rate_bps, burn_amount, emission_amount from epochs order by epoch_id desc limit 1")]); return json(res, 200, {assets:assets.rows[0].value, activePositions:positions.rows[0].value, latestEpoch:epochs.rows[0] ?? null, source:"indexed-chain-events"}); }
    if (url.pathname.startsWith("/v1/portfolio/")) { const wallet = url.pathname.split("/").pop()?.toLowerCase(); return json(res, 200, (await pool.query("select * from positions where lower(wallet_address) = $1 order by created_block desc", [wallet])).rows); }
    if (url.pathname === "/v1/admin/audit") { const session = bearer(req); if (!session || !hasRole(session.role, "AUDITOR")) return json(res, 403, {error:"insufficient_role"}); return json(res, 200, (await pool.query("select actor_address, role, action, proposal_payload, tx_hash, created_at from admin_audit_logs order by created_at desc limit 100")).rows); }
    if (req.method === "POST" && url.pathname === "/v1/admin/proposals") {
      const session = bearer(req); if (!session || !hasRole(session.role, "OPERATIONS")) return json(res, 403, {error:"insufficient_role"});
      const body = JSON.parse(await requestBody(req)) as {operation:string; payload:unknown; requiredRole?:Role}; const id = randomUUID(), requiredRole = body.requiredRole ?? "OPERATIONS";
      if (!hasRole(session.role, requiredRole)) return json(res, 403, {error:"insufficient_role"});
      await pool.query("insert into safe_proposals(id, proposer_address, required_role, operation, payload) values ($1,$2,$3,$4,$5)", [id, session.address, requiredRole, body.operation, body.payload]);
      await pool.query("insert into admin_audit_logs(actor_address, role, action, proposal_payload) values ($1,$2,$3,$4)", [session.address, session.role, `SAFE_PROPOSAL:${body.operation}`, body.payload]);
      return json(res, 201, {id, status:"DRAFT", note:"Prepared for Safe review; no transaction was sent."});
    }
    return json(res, 404, {error:"not_found"});
  } catch (error) { return json(res, 503, {error:"indexer_unavailable", detail:error instanceof Error ? error.message : "unknown"}); }
}).listen(port, () => console.log(`ALP API listening on ${port}`));

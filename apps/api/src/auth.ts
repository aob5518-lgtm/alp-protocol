import {randomUUID, timingSafeEqual, createHmac} from "node:crypto";
import {verifyMessage} from "viem";
import {Pool} from "pg";

export type Role = "SUPER_ADMIN" | "FINANCE" | "RISK" | "OPERATIONS" | "AUDITOR" | "READ_ONLY";
const roleRank: Record<Role, number> = {READ_ONLY: 0, AUDITOR: 1, OPERATIONS: 2, RISK: 3, FINANCE: 3, SUPER_ADMIN: 4};
export async function createNonce(db: Pool) { const nonce = randomUUID(); await db.query("insert into siwe_nonces(nonce, expires_at) values ($1, now() + interval '10 minutes')", [nonce]); return nonce; }
export async function verifySiwe(db: Pool, message: string, signature: `0x${string}`) {
  const match = message.match(/^.+ wants you to sign in with your Ethereum account:\n(0x[a-fA-F0-9]{40})\n[\s\S]*?Nonce: ([\w-]+)/m);
  if (!match) throw new Error("invalid_siwe_message");
  const address = match[1].toLowerCase() as `0x${string}`, nonce = match[2];
  const nonceResult = await db.query("update siwe_nonces set consumed_at = now() where nonce = $1 and consumed_at is null and expires_at > now() returning nonce", [nonce]);
  if (!nonceResult.rowCount) throw new Error("invalid_or_expired_nonce");
  if (!await verifyMessage({address, message, signature})) throw new Error("invalid_signature");
  const role = (await db.query("select role from admin_roles where lower(wallet_address) = $1", [address])).rows[0]?.role as Role | undefined;
  return {address, role: role ?? "READ_ONLY" as Role};
}
export function issueSession(payload: {address: string; role: Role}) { const secret = process.env.SESSION_SECRET; if (!secret) throw new Error("SESSION_SECRET is required"); const body = Buffer.from(JSON.stringify({...payload, exp: Date.now() + 8 * 60 * 60 * 1000})).toString("base64url"); return `${body}.${createHmac("sha256", secret).update(body).digest("base64url")}`; }
export function readSession(value?: string): {address: string; role: Role} | undefined { const secret = process.env.SESSION_SECRET; if (!value || !secret) return undefined; const [body, signature] = value.split("."); if (!body || !signature) return undefined; const expected = createHmac("sha256", secret).update(body).digest("base64url"); if (expected.length !== signature.length || !timingSafeEqual(Buffer.from(expected), Buffer.from(signature))) return undefined; const decoded = JSON.parse(Buffer.from(body, "base64url").toString()) as {address:string; role:Role; exp:number}; return decoded.exp > Date.now() ? {address:decoded.address, role:decoded.role} : undefined; }
export function hasRole(actual: Role, required: Role) { return roleRank[actual] >= roleRank[required]; }

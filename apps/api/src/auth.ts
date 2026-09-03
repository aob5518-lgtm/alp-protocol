import {randomUUID, timingSafeEqual, createHmac} from "node:crypto";
import {verifyMessage} from "viem";
import {Pool} from "pg";

export type Role = "SUPER_ADMIN" | "FINANCE" | "RISK" | "OPERATIONS" | "AUDITOR" | "READ_ONLY";
const roleRank: Record<Role, number> = {READ_ONLY: 0, AUDITOR: 1, OPERATIONS: 2, RISK: 3, FINANCE: 3, SUPER_ADMIN: 4};
export async function createNonce(db: Pool) { const nonce = randomUUID().replace(/-/g, ""); await db.query("insert into siwe_nonces(nonce, expires_at) values ($1, now() + interval '10 minutes')", [nonce]); return nonce; }
type SiweFields={address:`0x${string}`;nonce:string;domain:string;uri:string;chainId:number;issuedAt:Date;expirationTime?:Date};
function parseSiwe(message:string): SiweFields {
  const lines=message.replace(/\r\n/g,"\n").split("\n"), header=lines[0]?.match(/^([^\s]+) wants you to sign in with your Ethereum account:$/), address=lines[1];
  if(!header || !address || !/^0x[a-fA-F0-9]{40}$/.test(address)) throw new Error("invalid_siwe_message");
  const fields=new Map(lines.map(line=>{const separator=line.indexOf(": "); return separator===-1?["",""]:[line.slice(0,separator),line.slice(separator+2)];}));
  const uri=fields.get("URI"), version=fields.get("Version"), chainId=Number(fields.get("Chain ID")), nonce=fields.get("Nonce"), issuedAtRaw=fields.get("Issued At"), expiryRaw=fields.get("Expiration Time");
  const issuedAt=issuedAtRaw?new Date(issuedAtRaw):new Date("invalid"), expirationTime=expiryRaw?new Date(expiryRaw):undefined;
  if(!uri || !/^https?:\/\//.test(uri) || version!=="1" || chainId!==Number(process.env.SIWE_CHAIN_ID ?? 97) || !nonce || !/^[a-zA-Z0-9]{8,}$/.test(nonce) || Number.isNaN(issuedAt.getTime()) || issuedAt.getTime()>Date.now()+5*60_000 || (expirationTime && (Number.isNaN(expirationTime.getTime()) || expirationTime.getTime()<=Date.now()))) throw new Error("invalid_siwe_message");
  return {address:address.toLowerCase() as `0x${string}`,nonce,domain:header[1],uri,chainId,issuedAt,expirationTime};
}
export async function verifySiwe(db: Pool, message: string, signature: `0x${string}`, requestDomain?:string) {
  const parsed=parseSiwe(message), expectedDomain=process.env.SIWE_DOMAIN ?? requestDomain;
  if(expectedDomain && parsed.domain.toLowerCase()!==expectedDomain.toLowerCase()) throw new Error("siwe_domain_mismatch");
  if (!await verifyMessage({address:parsed.address, message, signature})) throw new Error("invalid_signature");
  const nonceResult = await db.query("update siwe_nonces set consumed_at = now() where nonce = $1 and consumed_at is null and expires_at > now() returning nonce", [parsed.nonce]);
  if (!nonceResult.rowCount) throw new Error("invalid_or_expired_nonce");
  const address=parsed.address;
  const role = (await db.query("select role from admin_roles where lower(wallet_address) = $1", [address])).rows[0]?.role as Role | undefined;
  return {address, role: role ?? "READ_ONLY" as Role};
}
export function issueSession(payload: {address: string; role: Role}) { const secret = process.env.SESSION_SECRET; if (!secret) throw new Error("SESSION_SECRET is required"); const body = Buffer.from(JSON.stringify({...payload, exp: Date.now() + 8 * 60 * 60 * 1000})).toString("base64url"); return `${body}.${createHmac("sha256", secret).update(body).digest("base64url")}`; }
export function readSession(value?: string): {address: string; role: Role} | undefined { const secret = process.env.SESSION_SECRET; if (!value || !secret) return undefined; const [body, signature] = value.split("."); if (!body || !signature) return undefined; const expected = createHmac("sha256", secret).update(body).digest("base64url"); if (expected.length !== signature.length || !timingSafeEqual(Buffer.from(expected), Buffer.from(signature))) return undefined; const decoded = JSON.parse(Buffer.from(body, "base64url").toString()) as {address:string; role:Role; exp:number}; return decoded.exp > Date.now() ? {address:decoded.address, role:decoded.role} : undefined; }
export function hasRole(actual: Role, required: Role) { return roleRank[actual] >= roleRank[required]; }

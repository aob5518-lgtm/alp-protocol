import {readFile} from "node:fs/promises";
import {resolve} from "node:path";
import {Pool} from "pg";

const db = new Pool({connectionString: process.env.DATABASE_URL});
const day = new Date().toISOString().slice(0, 10);
const scalar=async(field:string,eventName:string)=>BigInt((await db.query(`select coalesce(sum((payload->>$1)::numeric),0)::text value from indexed_events where event_name=$2`,[field,eventName])).rows[0].value);
const check=(name:string,left:bigint,right:bigint,tolerance=1n)=>({name,left:left.toString(),right:right.toString(),delta:(left-right).toString(),ok:left>=right?left-right<=tolerance:right-left<=tolerance});
async function main() {
  const book=JSON.parse(await readFile(resolve(process.cwd(),"deployments/bsc-testnet.json"),"utf8")) as {status:string};
  if(book.status!=="deployed") { const findings={reason:"Verified BSC Testnet address book is required; no reconciliation was inferred from template data."}; await db.query("insert into reconciliation_runs(day,status,findings) values($1,'NOT_READY',$2) on conflict(day) do update set status=excluded.status,findings=excluded.findings,created_at=now()",[day,findings]); console.log(JSON.stringify({day,status:"NOT_READY",findings})); return; }
  const [positionUsdt,rewardTreasury,liquidityAllocated,sellGross,sellFee,buyback,top100,nodeAirdrop,community,development,liquidityReceived,liquidityUsed,pendingUsdt,providedAlp,usedAlp,returnedAlp,emission,claimed,undistributed]=await Promise.all([
    scalar("usdtAmount","PositionCreated"),scalar("amount","RewardTreasuryReceived"),scalar("amount","LiquidityAllocationReceived"),scalar("grossAmount","SellFeeCollected"),scalar("feeAmount","SellFeeCollected"),scalar("amount","BuybackFeeReceived"),scalar("amount","Top100FeeReceived"),scalar("amount","NodeAirdropFeeReceived"),scalar("amount","CommunityFeeReceived"),scalar("amount","DevelopmentFeeReceived"),scalar("amount","LiquidityAllocationReceived"),scalar("usedUsdt","LiquiditySettled"),scalar("pendingUsdt","LiquidityPending"),scalar("providedAlp","LiquiditySettled"),scalar("usedAlp","LiquiditySettled"),scalar("returnedAlp","LiquiditySettled"),scalar("emissionAmount","EpochSettled"),scalar("amount","RewardClaimed"),scalar("amount","UndistributedEmission")
  ]);
  const checks=[
    check("position USDT = reward treasury + liquidity allocation",positionUsdt,rewardTreasury+liquidityAllocated),
    check("sell fee is 17% of gross",sellFee*100n,sellGross*17n),
    check("sell fee split is 5+1+4+5+2",sellFee,buyback+top100+nodeAirdrop+community+development),
    check("liquidity USDT received = used + pending",liquidityReceived,liquidityUsed+pendingUsdt),
    check("liquidity ALP provided = used + returned",providedAlp,usedAlp+returnedAlp),
    check("emission = claimed + undistributed",emission,claimed+undistributed),
  ];
  const requiredEvents=["PositionCreated","SellFeeCollected","LiquiditySettled","EpochSettled"];
  const eventCounts=Object.fromEntries(await Promise.all(requiredEvents.map(async eventName=>[eventName,Number((await db.query("select count(*)::int count from indexed_events where event_name=$1",[eventName])).rows[0].count)])));
  const status=Object.values(eventCounts).some(count=>count===0)?"NOT_READY":checks.every(item=>item.ok)?"PASS":"REVIEW_REQUIRED", findings={source:"indexed-chain-events",eventCounts,checks};
  await db.query("insert into reconciliation_runs(day,status,findings) values ($1,$2,$3) on conflict (day) do update set status=excluded.status,findings=excluded.findings,created_at=now()",[day,status,findings]);
  console.log(JSON.stringify({day,status,findings}));
}
void main().finally(() => db.end());

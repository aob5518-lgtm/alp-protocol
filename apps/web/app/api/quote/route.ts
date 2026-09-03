import {readFile} from "node:fs/promises";
import {resolve} from "node:path";
import {NextRequest, NextResponse} from "next/server";
import {createPublicClient, http, parseAbi} from "viem";
import {bscTestnet} from "viem/chains";

const poolAbi=parseAbi(["function quote(uint256 totalValueUSDT) view returns (uint256 partnerAmount, uint256 usdtAmount, uint256 priceE18)"]);

export async function GET(request: NextRequest) {
  try {
    const totalValue=request.nextUrl.searchParams.get("totalValue");
    if (!totalValue || !/^\d+$/.test(totalValue) || BigInt(totalValue) === 0n) return NextResponse.json({error:"totalValue must be a positive integer in USD wei"},{status:400});
    const book=JSON.parse(await readFile(resolve(process.cwd(),"../../deployments/bsc-testnet.json"),"utf8")) as {status:string;contracts:Record<string,string|null>};
    const pool=book.contracts.reliquePool ?? book.contracts.launchPool;
    if (book.status !== "deployed" || !pool) return NextResponse.json({error:"BSC Testnet deployment is not verified"},{status:409});
    const client=createPublicClient({chain:bscTestnet,transport:http(process.env.BSC_TESTNET_RPC_URL)});
    const [partnerAmount,usdtAmount,priceE18]=await client.readContract({address:pool as `0x${string}`,abi:poolAbi,functionName:"quote",args:[BigInt(totalValue)]});
    return NextResponse.json({partnerAmount:partnerAmount.toString(),usdtAmount:usdtAmount.toString(),priceE18:priceE18.toString(),pool},{headers:{"cache-control":"no-store"}});
  } catch { return NextResponse.json({error:"Unable to obtain an onchain launch quote"},{status:502}); }
}

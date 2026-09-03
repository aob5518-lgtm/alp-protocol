import {readFile} from "node:fs/promises";
import {Pool} from "pg";
import {createPublicClient, http} from "viem";
import {bscTestnet} from "viem/chains";

const db = new Pool({connectionString:process.env.DATABASE_URL});
const rpc = process.env.RPC_URL;
if (!rpc) throw new Error("RPC_URL is required");
const client = createPublicClient({chain:bscTestnet, transport:http(rpc)});
const addressBookPath = process.env.ADDRESS_BOOK_PATH ?? "../../deployments/bsc-testnet.json";

async function tick() {
  const addressBook = JSON.parse(await readFile(addressBookPath, "utf8"));
  if (addressBook.status !== "deployed") return console.log("Indexer waiting for a verified deployed address book.");
  const block = await client.getBlock({blockTag:"latest"});
  await db.query("insert into chain_blocks(chain_id,number,hash,parent_hash) values($1,$2,$3,$4) on conflict do nothing", [97, Number(block.number), block.hash, block.parentHash]);
  // Event ABI registration is intentionally address-book driven. Add only verified deployed contracts here;
  // projections are idempotent by (chainId, txHash, logIndex) and must roll back from the first divergent block.
  console.log(`Indexed checkpoint ${block.number} for ${Object.keys(addressBook.contracts).length} configured contracts`);
}
tick().catch(error => { console.error(error); process.exitCode = 1; });
setInterval(() => void tick().catch(console.error), 12_000);

import {mkdir, writeFile} from "node:fs/promises";
import {join} from "node:path";
import {Pool} from "pg";
import {encodeAbiParameters, keccak256, toHex, type Address, type Hex} from "viem";
import {aggregateUnlimitedTier, type PositionFact, type VolumeBase} from "./tier-snapshot.js";

const snapshotId = BigInt(process.env.TIER_SNAPSHOT_ID ?? "0"), snapshotBlock = BigInt(process.env.TIER_SNAPSHOT_BLOCK ?? "0");
if (!snapshotId || !snapshotBlock) throw new Error("TIER_SNAPSHOT_ID and TIER_SNAPSHOT_BLOCK are required");
const db = new Pool({connectionString:process.env.DATABASE_URL});
const pairHash = (left:Hex, right:Hex) => keccak256(left.toLowerCase() < right.toLowerCase() ? (`${left}${right.slice(2)}` as Hex) : (`${right}${left.slice(2)}` as Hex));
function root(leaves:Hex[]) { if (!leaves.length) return "0x".padEnd(66,"0") as Hex; let layer=[...leaves].sort(); while(layer.length>1) { const next:Hex[]=[]; for(let index=0;index<layer.length;index+=2) next.push(pairHash(layer[index],layer[index+1] ?? layer[index])); layer=next.sort(); } return layer[0]; }
async function main() {
  const [edges, positions] = await Promise.all([db.query("select wallet_address, sponsor_address from sponsor_edges where bound_block <= $1",[snapshotBlock.toString()]), db.query("select wallet_address,total_value,usdt_amount from positions where created_block <= $1 and status='ACTIVE'",[snapshotBlock.toString()])]);
  const sponsors = new Map(edges.rows.map(edge=>[edge.wallet_address.toLowerCase(),edge.sponsor_address.toLowerCase()]));
  const facts:PositionFact[] = positions.rows.map(row=>({wallet:row.wallet_address.toLowerCase(),totalPositionValue:BigInt(row.total_value),usdtContribution:BigInt(row.usdt_amount)}));
  const base=(process.env.TIER_VOLUME_BASE ?? "TOTAL_POSITION_VALUE") as VolumeBase; if (base !== "TOTAL_POSITION_VALUE" && base !== "USDT_CONTRIBUTION") throw new Error("invalid TIER_VOLUME_BASE");
  const rows=aggregateUnlimitedTier(sponsors,facts,base).sort((a,b)=>a.wallet.localeCompare(b.wallet));
  const leaves=rows.map(row=>keccak256(encodeAbiParameters([{type:"uint64"},{type:"uint64"},{type:"address"},{type:"uint256"},{type:"address"},{type:"uint256"},{type:"uint256"},{type:"uint8"}],[snapshotId,snapshotBlock,row.wallet as Address,row.totalNetworkVolume,row.largestBranch as Address,row.largestBranchVolume,row.smallDistrictVolume,row.tier])));
  const dataset={snapshotId:snapshotId.toString(),snapshotBlock:snapshotBlock.toString(),volumeBase:base,rows:rows.map(row=>({...row,totalNetworkVolume:row.totalNetworkVolume.toString(),largestBranchVolume:row.largestBranchVolume.toString(),smallDistrictVolume:row.smallDistrictVolume.toString()}))};
  const canonical=JSON.stringify(dataset), datasetHash=keccak256(toHex(canonical)), merkleRoot=root(leaves); const dir=join(process.cwd(),"artifacts","tier-snapshots",snapshotId.toString()); await mkdir(dir,{recursive:true});
  await writeFile(join(dir,"dataset.json"),canonical); await writeFile(join(dir,"dataset.csv"),["wallet,totalNetworkVolume,largestBranch,largestBranchVolume,smallDistrictVolume,tier",...dataset.rows.map(row=>Object.values(row).join(","))].join("\n"));
  await writeFile(join(dir,"manifest.json"),JSON.stringify({snapshotId:snapshotId.toString(),snapshotBlock:snapshotBlock.toString(),merkleRoot,datasetHash,leafCount:leaves.length,volumeBase:base},null,2)); console.log(JSON.stringify({merkleRoot,datasetHash,leafCount:leaves.length}));
}
void main().finally(()=>db.end());

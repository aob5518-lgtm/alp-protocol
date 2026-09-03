import {readFile} from "node:fs/promises";
import {join} from "node:path";
import {encodeAbiParameters, keccak256, type Address, type Hex} from "viem";

type ProofRow={snapshotId:string;snapshotBlock:string;totalNetworkVolume:string;largestBranch:string;largestBranchVolume:string;smallDistrictVolume:string;tier:number;proof:Hex[]};
const pairHash=(left:Hex,right:Hex)=>keccak256(left.toLowerCase()<right.toLowerCase()?(`${left}${right.slice(2)}` as Hex):(`${right}${left.slice(2)}` as Hex));
const snapshotId=process.argv[2]; if(!snapshotId) throw new Error("usage: verify-snapshot <snapshot-id>");
async function main() {
  const directory=join(process.cwd(),"artifacts","tier-snapshots",snapshotId);
  const manifest=JSON.parse(await readFile(join(directory,"manifest.json"),"utf8")) as {merkleRoot:Hex;volumeBase:string};
  if(manifest.volumeBase!=="TOTAL_POSITION_VALUE") throw new Error("unexpected volume base");
  const proofs=JSON.parse(await readFile(join(directory,"proofs.json"),"utf8")) as Record<string,ProofRow>;
  for(const [wallet,row] of Object.entries(proofs)) {
    let hash=keccak256(encodeAbiParameters([{type:"uint64"},{type:"uint64"},{type:"address"},{type:"uint256"},{type:"address"},{type:"uint256"},{type:"uint256"},{type:"uint8"}],[BigInt(row.snapshotId),BigInt(row.snapshotBlock),wallet as Address,BigInt(row.totalNetworkVolume),row.largestBranch as Address,BigInt(row.largestBranchVolume),BigInt(row.smallDistrictVolume),row.tier]));
    for(const sibling of row.proof) hash=pairHash(hash,sibling);
    if(hash!==manifest.merkleRoot) throw new Error(`invalid proof for ${wallet}`);
  }
  console.log(JSON.stringify({snapshotId,verifiedProofs:Object.keys(proofs).length,merkleRoot:manifest.merkleRoot}));
}
void main();

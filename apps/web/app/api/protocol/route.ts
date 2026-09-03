import {readFile} from "node:fs/promises";
import {resolve} from "node:path";
import {NextResponse} from "next/server";

/** Public, read-only deployment state. It never invents addresses for an undeployed network. */
export async function GET() {
  try {
    const file = resolve(process.cwd(), "../../deployments/bsc-testnet.json");
    const addressBook = JSON.parse(await readFile(file, "utf8"));
    return NextResponse.json({source:"deployment-address-book", ...addressBook}, {headers:{"cache-control":"no-store"}});
  } catch {
    return NextResponse.json({status:"address-book-unavailable", source:"deployment-address-book"}, {status:503, headers:{"cache-control":"no-store"}});
  }
}

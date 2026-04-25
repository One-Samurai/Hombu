import { NextRequest, NextResponse } from "next/server";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { PACKAGE_ID, T } from "@honbu/contract-types";

export async function POST(req: NextRequest) {
  const { address } = (await req.json()) as { address: string };
  if (!/^0x[0-9a-fA-F]{64}$/.test(address)) {
    return NextResponse.json({ error: "bad address" }, { status: 400 });
  }

  const adminKey = process.env.ADMIN_PRIVATE_KEY_BECH32;
  const adminCap = process.env.ADMIN_CAP_ID;
  if (!adminKey || !adminCap) return NextResponse.json({ error: "server not configured" }, { status: 500 });

  const client = new SuiClient({ url: getFullnodeUrl("testnet") });
  const signer = Ed25519Keypair.fromSecretKey(adminKey);

  // Idempotent: check if agent already has an AgentCap
  const owned = await client.getOwnedObjects({
    owner: address,
    filter: { StructType: T.AgentCap },
    options: { showType: true },
  });
  if (owned.data.length > 0) {
    return NextResponse.json({ capId: owned.data[0].data?.objectId, reused: true, digest: null });
  }

  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::fighter::create_agent_cap`,
    arguments: [tx.object(adminCap), tx.pure.address(address)],
  });
  const res = await client.signAndExecuteTransaction({
    transaction: tx, signer, options: { showObjectChanges: true },
  });
  const created = res.objectChanges?.find(
    (c: any) => c.type === "created" && c.objectType?.endsWith("::fighter::AgentCap")
  ) as any;
  return NextResponse.json({ capId: created?.objectId, reused: false, digest: res.digest });
}

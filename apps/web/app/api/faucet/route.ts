import { NextRequest, NextResponse } from "next/server";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

const DRIP_MIST = 50_000_000n; // 0.05 SUI

export async function POST(req: NextRequest) {
  try {
    const { address } = (await req.json()) as { address?: string };
    if (!address || !/^0x[0-9a-fA-F]{64}$/.test(address)) {
      return NextResponse.json({ error: "bad address" }, { status: 400 });
    }
    const adminKey = process.env.ADMIN_PRIVATE_KEY_BECH32;
    if (!adminKey) return NextResponse.json({ error: "admin key not set" }, { status: 500 });

    const client = new SuiClient({ url: getFullnodeUrl("testnet") });
    const signer = Ed25519Keypair.fromSecretKey(adminKey);

    const tx = new Transaction();
    const [coin] = tx.splitCoins(tx.gas, [DRIP_MIST]);
    tx.transferObjects([coin], address);

    const res = await client.signAndExecuteTransaction({
      transaction: tx, signer, options: { showEffects: false },
    });
    return NextResponse.json({ digest: res.digest, amount: DRIP_MIST.toString() });
  } catch (e: any) {
    return NextResponse.json({ error: `faucet: ${e?.message ?? e}` }, { status: 500 });
  }
}

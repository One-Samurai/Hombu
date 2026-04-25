import { NextRequest, NextResponse } from "next/server";

const FAUCET_URL = process.env.FAUCET_URL ?? "https://faucet.testnet.sui.io/v1/gas";

export async function POST(req: NextRequest) {
  try {
    const { address } = (await req.json()) as { address?: string };
    if (!address || !/^0x[0-9a-fA-F]{64}$/.test(address)) {
      return NextResponse.json({ error: "bad address" }, { status: 400 });
    }
    const r = await fetch(FAUCET_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ FixedAmountRequest: { recipient: address } }),
    });
    const text = await r.text();
    if (!r.ok) return NextResponse.json({ error: `faucet ${r.status}: ${text}` }, { status: 502 });
    return new NextResponse(text, { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (e: any) {
    return NextResponse.json({ error: `faucet: ${e?.message ?? e}` }, { status: 500 });
  }
}

import { NextRequest, NextResponse } from "next/server";

const UPSTREAM = process.env.SALT_UPSTREAM_URL ?? "https://salt.api.mystenlabs.com/get_salt";

export async function POST(req: NextRequest) {
  try {
    const body = await req.text();
    const r = await fetch(UPSTREAM, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
    });
    const text = await r.text();
    return new NextResponse(text, {
      status: r.status,
      headers: { "Content-Type": r.headers.get("Content-Type") ?? "application/json" },
    });
  } catch (e: any) {
    return NextResponse.json({ error: `salt proxy: ${e?.message ?? e}` }, { status: 502 });
  }
}

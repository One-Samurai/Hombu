import { NextRequest, NextResponse } from "next/server";
import { createHmac } from "node:crypto";

// Deterministic self-hosted salt for demo: HMAC-SHA256(secret, sub|aud) → low 128 bits as decimal.
// zkLogin salt must fit in BN254 scalar field; 128-bit value is safely below the modulus.
// Replace with KMS-backed lookup + KYC gate before mainnet.
function decodeJwtPayload(jwt: string): { sub?: string; aud?: string | string[] } {
  const part = jwt.split(".")[1];
  if (!part) throw new Error("invalid jwt");
  const b64 = part.replace(/-/g, "+").replace(/_/g, "/").padEnd(part.length + ((4 - (part.length % 4)) % 4), "=");
  return JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
}

export async function POST(req: NextRequest) {
  try {
    const secret = process.env.SALT_SERVER_SECRET;
    if (!secret) return NextResponse.json({ error: "SALT_SERVER_SECRET not set" }, { status: 500 });

    const { token } = (await req.json()) as { token?: string };
    if (!token) return NextResponse.json({ error: "missing token" }, { status: 400 });

    const { sub, aud } = decodeJwtPayload(token);
    if (!sub || !aud) return NextResponse.json({ error: "jwt missing sub/aud" }, { status: 400 });
    const audStr = Array.isArray(aud) ? aud[0] : aud;

    const mac = createHmac("sha256", secret).update(`${sub}|${audStr}`).digest();
    const salt = BigInt("0x" + mac.subarray(0, 16).toString("hex")).toString();

    return NextResponse.json({ salt });
  } catch (e: any) {
    return NextResponse.json({ error: `salt: ${e?.message ?? e}` }, { status: 500 });
  }
}

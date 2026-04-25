const PROVER_URL = process.env.NEXT_PUBLIC_PROVER_URL;

export async function fetchZkProof(params: {
  jwt: string;
  extendedEphemeralPublicKey: string;
  maxEpoch: number;
  jwtRandomness: string;
  salt: string;
  keyClaimName?: "sub";
}) {
  if (!PROVER_URL) throw new Error("NEXT_PUBLIC_PROVER_URL not set");
  const r = await fetch(PROVER_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...params, keyClaimName: params.keyClaimName ?? "sub" }),
  }).catch((e) => { throw new Error(`prover fetch failed (${PROVER_URL}): ${e.message}`); });
  if (!r.ok) throw new Error(`prover ${r.status} from ${PROVER_URL}: ${await r.text().catch(() => "")}`);
  return r.json();
}

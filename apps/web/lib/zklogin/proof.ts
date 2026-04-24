const PROVER_URL = process.env.NEXT_PUBLIC_PROVER_URL!;

export async function fetchZkProof(params: {
  jwt: string;
  extendedEphemeralPublicKey: string;
  maxEpoch: number;
  jwtRandomness: string;
  salt: string;
  keyClaimName?: "sub";
}) {
  const r = await fetch(PROVER_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...params, keyClaimName: params.keyClaimName ?? "sub" }),
  });
  if (!r.ok) throw new Error(`prover ${r.status}`);
  return r.json();
}

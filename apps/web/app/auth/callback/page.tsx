"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getExtendedEphemeralPublicKey } from "@mysten/zklogin";
import { useSession } from "@/lib/store";
import { keyFromSecret } from "@/lib/zklogin/ephemeral";
import { fetchSalt } from "@/lib/zklogin/salt";
import { fetchZkProof } from "@/lib/zklogin/proof";
import { deriveAddress } from "@/lib/zklogin/address";

export default function Callback() {
  const router = useRouter();
  const { set, maxEpoch, randomness, ephemeralSecret } = useSession();
  const [status, setStatus] = useState("Finishing login…");
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const frag = new URLSearchParams(window.location.hash.slice(1));
        const jwt = frag.get("id_token");
        if (!jwt) throw new Error("no id_token in fragment");
        if (!maxEpoch || !randomness || !ephemeralSecret)
          throw new Error("no ephemeral state (session lost — start over from /login)");

        setStatus("Fetching salt…");
        const userSalt = await fetchSalt(jwt);
        setStatus("Deriving address…");
        const address = deriveAddress(jwt, userSalt);
        const pk = getExtendedEphemeralPublicKey(keyFromSecret(ephemeralSecret).getPublicKey());
        setStatus("Fetching ZK proof…");
        const zkProof = await fetchZkProof({
          jwt, extendedEphemeralPublicKey: pk, maxEpoch, jwtRandomness: randomness, salt: userSalt,
        });

        set({ jwt, userSalt, address, zkProof });
        router.replace("/fighters/mint");
      } catch (e: any) {
        console.error("[callback]", e);
        setErr(e?.message ?? String(e));
      }
    })();
  }, []);

  if (err) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center gap-4 p-8">
        <h1 className="text-xl font-semibold text-red-600">Login failed</h1>
        <pre className="max-w-xl whitespace-pre-wrap text-sm text-neutral-700">{err}</pre>
        <button
          onClick={() => router.replace("/login")}
          className="rounded-md bg-black px-4 py-2 text-white"
        >
          Back to login
        </button>
      </main>
    );
  }
  return <main className="p-8">{status}</main>;
}

"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { getExtendedEphemeralPublicKey } from "@mysten/zklogin";
import { useSession } from "@/lib/store";
import { keyFromSecret } from "@/lib/zklogin/ephemeral";
import { fetchSalt } from "@/lib/zklogin/salt";
import { fetchZkProof } from "@/lib/zklogin/proof";
import { deriveAddress } from "@/lib/zklogin/address";
import { toast } from "sonner";

export default function Callback() {
  const router = useRouter();
  const { set, maxEpoch, randomness, ephemeralSecret } = useSession();

  useEffect(() => {
    (async () => {
      try {
        const frag = new URLSearchParams(window.location.hash.slice(1));
        const jwt = frag.get("id_token");
        if (!jwt) throw new Error("no id_token");
        if (!maxEpoch || !randomness || !ephemeralSecret) throw new Error("no ephemeral state");

        const userSalt = await fetchSalt(jwt);
        const address = deriveAddress(jwt, userSalt);
        const pk = getExtendedEphemeralPublicKey(keyFromSecret(ephemeralSecret).getPublicKey());
        const zkProof = await fetchZkProof({
          jwt, extendedEphemeralPublicKey: pk, maxEpoch, jwtRandomness: randomness, salt: userSalt,
        });

        set({ jwt, userSalt, address, zkProof });
        router.replace("/fighters/mint");
      } catch (e: any) {
        toast.error(`Login failed: ${e.message ?? e}`);
        router.replace("/login");
      }
    })();
  }, []);

  return <main className="p-8">Finishing login…</main>;
}

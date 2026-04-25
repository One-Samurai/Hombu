"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useSession } from "@/lib/store";
import { findFighter } from "@/lib/queries/myFighter";
import { findAgentCap } from "@/lib/queries/myAgentCap";
import { suiClient } from "@/lib/sui";
import { hashedIdFromJwtSub } from "@/lib/zklogin/hashedId";
import { buildMintFighter } from "@/lib/tx/mintFighter";
import { signAndExecuteZk } from "@/lib/zklogin/signer";
import { parseAbort } from "@/lib/errors";

export default function Mint() {
  const router = useRouter();
  const sess = useSession();
  const [ringName, setRingName] = useState("");
  const [weight, setWeight] = useState(70);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!sess.address) { router.replace("/login"); return; }
    (async () => {
      const fid = await findFighter(sess.address!);
      if (fid) { sess.set({ fighterId: fid }); router.replace("/slots"); }
    })();
  }, [sess.address]);

  async function onMint() {
    if (!sess.jwt || !sess.userSalt || !sess.address) return;
    setBusy(true);
    try {
      let capId = sess.agentCapId ?? await findAgentCap(sess.address);
      if (!capId) {
        const r = await fetch("/api/agent-cap", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ address: sess.address }),
        });
        const j = await r.json();
        if (!r.ok) throw new Error(j.error);
        capId = j.capId;
        // Wait for the user's fullnode to index the newly-created AgentCap
        // before we use it as input in the mint tx (read-after-write lag).
        if (j.digest) {
          await suiClient.waitForTransaction({ digest: j.digest, timeout: 30_000 });
        }
      }
      sess.set({ agentCapId: capId });

      const sub = JSON.parse(atob(sess.jwt.split(".")[1])).sub as string;
      const hashedId = await hashedIdFromJwtSub(sub, sess.userSalt);
      const tx = buildMintFighter({
        agentCapId: capId!,
        hashedId,
        ringName,
        weightClass: weight,
        nationalityCode: 392, // JP
      });
      const res = await signAndExecuteZk({
        tx, sender: sess.address,
        ephemeralSecret: sess.ephemeralSecret!,
        jwt: sess.jwt, userSalt: sess.userSalt,
        maxEpoch: sess.maxEpoch!, zkProof: sess.zkProof,
      });
      const created = (res.objectChanges ?? []).find(
        (c: any) => c.type === "created" && c.objectType?.endsWith("::fighter::Fighter")
      ) as any;
      sess.set({ fighterId: created?.objectId });
      toast.success("Fighter minted");
      router.replace("/slots");
    } catch (e: any) {
      toast.error(parseAbort(e.message ?? String(e)));
    } finally { setBusy(false); }
  }

  return (
    <main className="mx-auto max-w-md space-y-4 p-8">
      <h1 className="text-2xl font-bold">Create Fighter</h1>
      <p className="text-sm text-neutral-600">Ring name is public on-chain. Do not use your legal name.</p>
      <input
        value={ringName} onChange={(e) => setRingName(e.target.value)}
        placeholder="Ring name" className="w-full rounded border px-3 py-2"
      />
      <input
        type="number" value={weight} onChange={(e) => setWeight(Number(e.target.value))}
        placeholder="Weight (kg)" className="w-full rounded border px-3 py-2"
      />
      <button disabled={busy || !ringName} onClick={onMint}
        className="w-full rounded bg-black px-4 py-2 text-white disabled:opacity-50">
        {busy ? "Minting…" : "Mint Fighter"}
      </button>
    </main>
  );
}

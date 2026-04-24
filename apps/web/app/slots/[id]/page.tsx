"use client";
import { useRouter, useParams } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { useSession } from "@/lib/store";
import { buildBookSlot } from "@/lib/tx/bookSlot";
import { signAndExecuteZk } from "@/lib/zklogin/signer";
import { parseAbort } from "@/lib/errors";

export default function SlotDetail() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const sess = useSession();
  const [busy, setBusy] = useState(false);

  async function book() {
    if (!sess.fighterId || !sess.address) { router.replace("/fighters/mint"); return; }
    setBusy(true);
    try {
      const tx = buildBookSlot(id, sess.fighterId);
      await signAndExecuteZk({
        tx, sender: sess.address,
        ephemeralSecret: sess.ephemeralSecret!, jwt: sess.jwt!,
        userSalt: sess.userSalt!, maxEpoch: sess.maxEpoch!, zkProof: sess.zkProof,
      });
      toast.success("Booked!");
      router.replace("/bookings");
    } catch (e: any) {
      toast.error(parseAbort(e.message ?? String(e)));
    } finally { setBusy(false); }
  }

  return (
    <main className="mx-auto max-w-md space-y-4 p-8">
      <h1 className="text-2xl font-bold">Slot</h1>
      <p className="break-all text-sm text-neutral-500">{id}</p>
      <button onClick={book} disabled={busy}
        className="w-full rounded bg-black px-4 py-2 text-white disabled:opacity-50">
        {busy ? "Booking…" : "Book this slot"}
      </button>
    </main>
  );
}

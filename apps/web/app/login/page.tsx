"use client";
import { useState } from "react";
import { toast } from "sonner";
import { useSession } from "@/lib/store";
import { newEphemeralKey } from "@/lib/zklogin/ephemeral";

const CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;
const REDIRECT = process.env.NEXT_PUBLIC_REDIRECT_URL;

export default function Login() {
  const set = useSession((s) => s.set);
  const [busy, setBusy] = useState(false);
  async function go() {
    setBusy(true);
    try {
      if (!CLIENT_ID) throw new Error("NEXT_PUBLIC_GOOGLE_CLIENT_ID missing");
      if (!REDIRECT) throw new Error("NEXT_PUBLIC_REDIRECT_URL missing");
      const { nonce, maxEpoch, randomness, ephemeralSecret } = await newEphemeralKey();
      set({ maxEpoch, randomness, ephemeralSecret });
      const url =
        `https://accounts.google.com/o/oauth2/v2/auth?` +
        new URLSearchParams({
          client_id: CLIENT_ID,
          redirect_uri: REDIRECT,
          response_type: "id_token",
          scope: "openid email",
          nonce,
        }).toString();
      window.location.href = url;
    } catch (e: any) {
      console.error("[login]", e);
      toast.error(`Login failed: ${e.message ?? e}`);
      setBusy(false);
    }
  }
  return (
    <main className="flex min-h-screen items-center justify-center">
      <button onClick={go} disabled={busy} className="rounded-md bg-black px-5 py-2.5 text-white disabled:opacity-50">
        {busy ? "Opening Google…" : "Continue with Google"}
      </button>
    </main>
  );
}

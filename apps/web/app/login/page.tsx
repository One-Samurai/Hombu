"use client";
import { useSession } from "@/lib/store";
import { newEphemeralKey } from "@/lib/zklogin/ephemeral";

const CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID!;
const REDIRECT = process.env.NEXT_PUBLIC_REDIRECT_URL!;

export default function Login() {
  const set = useSession((s) => s.set);
  async function go() {
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
  }
  return (
    <main className="flex min-h-screen items-center justify-center">
      <button onClick={go} className="rounded-md bg-black px-5 py-2.5 text-white">
        Continue with Google
      </button>
    </main>
  );
}

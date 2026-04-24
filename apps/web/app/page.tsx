import Link from "next/link";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6 p-8">
      <h1 className="text-4xl font-bold">HONBU Fighter Hub</h1>
      <p className="text-neutral-600">Book training slots. Cut through the paperwork.</p>
      <Link href="/login" className="rounded-md bg-black px-5 py-2.5 text-white">
        Login with Google
      </Link>
    </main>
  );
}

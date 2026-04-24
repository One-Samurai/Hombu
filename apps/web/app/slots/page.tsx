"use client";
import { useQuery } from "@tanstack/react-query";
import { listOpenSlots } from "@/lib/queries/listSlots";
import { SlotCard } from "@/components/SlotCard";

export default function Slots() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["slots"], queryFn: listOpenSlots, staleTime: 15_000,
  });
  if (isLoading) return <main className="p-8">Loading…</main>;
  if (error) return <main className="p-8 text-red-600">Failed to load slots.</main>;
  return (
    <main className="mx-auto max-w-2xl space-y-3 p-8">
      <h1 className="text-2xl font-bold">Training Slots</h1>
      {data?.length === 0 && <p>No open slots.</p>}
      {data?.map((s) => <SlotCard key={s.id} s={s} />)}
    </main>
  );
}

import Link from "next/link";
import type { SlotView } from "@/lib/queries/listSlots";

export function SlotCard({ s }: { s: SlotView }) {
  const dt = new Date(s.startMs).toLocaleString();
  return (
    <Link href={`/slots/${s.id}`}
      className="block rounded-lg border bg-white p-4 hover:border-black">
      <div className="font-medium">{dt}</div>
      <div className="text-sm text-neutral-600">
        {s.durationMin} min · {s.bookedCount}/{s.capacity} booked
      </div>
    </Link>
  );
}

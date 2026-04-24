"use client";
import { useQuery } from "@tanstack/react-query";
import { useSession } from "@/lib/store";
import { listMyReceipts } from "@/lib/queries/myReceipts";
import { getBooking } from "@/lib/queries/getBooking";

const STATUS = ["BOOKED", "COMPLETED", "CANCELLED"];

export default function MyBookings() {
  const addr = useSession((s) => s.address);
  const { data } = useQuery({
    queryKey: ["my-bookings", addr],
    enabled: !!addr,
    queryFn: async () => {
      const receipts = await listMyReceipts(addr!);
      return Promise.all(receipts.map(async (r) => ({ ...r, booking: await getBooking(r.bookingId) })));
    },
  });
  if (!addr) return <main className="p-8">Please login.</main>;
  return (
    <main className="mx-auto max-w-2xl space-y-3 p-8">
      <h1 className="text-2xl font-bold">My Bookings</h1>
      {data?.length === 0 && <p>No bookings yet.</p>}
      {data?.map((r) => (
        <div key={r.receiptId} className="rounded-lg border bg-white p-4">
          <div className="font-medium">{new Date(r.booking.bookedAtMs).toLocaleString()}</div>
          <div className="text-sm text-neutral-600">
            Status: {STATUS[r.booking.status] ?? r.booking.status}
          </div>
          <div className="truncate text-xs text-neutral-400">slot {r.booking.slotId}</div>
        </div>
      ))}
    </main>
  );
}

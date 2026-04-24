import { suiClient } from "@/lib/sui";

export type BookingView = {
  id: string; slotId: string; fighterId: string;
  bookedAtMs: number; status: number;
};

export async function getBooking(id: string): Promise<BookingView> {
  const o = await suiClient.getObject({ id, options: { showContent: true } });
  const f = (o.data?.content as any)?.fields ?? {};
  return {
    id, slotId: f.slot_id, fighterId: f.fighter_id,
    bookedAtMs: Number(f.booked_at_ms), status: Number(f.status),
  };
}

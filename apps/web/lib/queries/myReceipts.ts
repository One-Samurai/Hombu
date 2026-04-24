import { suiClient } from "@/lib/sui";
import { T } from "@honbu/contract-types";

export type ReceiptView = { receiptId: string; bookingId: string };

export async function listMyReceipts(address: string): Promise<ReceiptView[]> {
  const r = await suiClient.getOwnedObjects({
    owner: address,
    filter: { StructType: T.BookingReceipt },
    options: { showContent: true, showType: true },
  });
  return r.data.map((o) => {
    const fields = (o.data?.content as any)?.fields ?? {};
    return { receiptId: o.data!.objectId, bookingId: fields.booking_id };
  });
}

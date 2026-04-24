import { suiClient } from "@/lib/sui";
import { T } from "@honbu/contract-types";

export type SlotView = {
  id: string; gymId: string; startMs: number; durationMin: number;
  capacity: number; bookedCount: number; status: number;
};

export async function listOpenSlots(): Promise<SlotView[]> {
  // Shared objects of a given type are queryable via GraphQL `objects`.
  // We use SuiClient `queryObjects` which wraps the GraphQL query.
  const gql = `
    query Slots($type: String!, $first: Int!) {
      objects(first: $first, filter: { type: $type }) {
        nodes { address contents { json } }
      }
    }`;
  const url = process.env.NEXT_PUBLIC_GRAPHQL_URL!;
  const r = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ query: gql, variables: { type: T.TrainingSlot, first: 50 } }),
  });
  const j = await r.json();
  const now = Date.now();
  return (j.data?.objects?.nodes ?? [])
    .map((n: any) => {
      const c = n.contents.json;
      return {
        id: n.address,
        gymId: c.gym_id,
        startMs: Number(c.start_ms),
        durationMin: Number(c.duration_min),
        capacity: Number(c.capacity),
        bookedCount: Number(c.booked_count),
        status: Number(c.status),
      };
    })
    .filter((s: SlotView) => s.status === 0 && s.startMs > now)
    .sort((a: SlotView, b: SlotView) => a.startMs - b.startMs);
}

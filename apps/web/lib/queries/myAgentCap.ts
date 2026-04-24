import { suiClient } from "@/lib/sui";
import { T } from "@honbu/contract-types";

export async function findAgentCap(address: string): Promise<string | undefined> {
  const r = await suiClient.getOwnedObjects({
    owner: address, filter: { StructType: T.AgentCap }, options: { showType: true },
  });
  return r.data[0]?.data?.objectId;
}

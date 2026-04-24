import { Transaction } from "@mysten/sui/transactions";
import { PACKAGE_ID } from "@honbu/contract-types";

export function buildBookSlot(slotId: string, fighterId: string) {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::booking::book_slot`,
    arguments: [tx.object(slotId), tx.object(fighterId), tx.object("0x6")],
  });
  return tx;
}

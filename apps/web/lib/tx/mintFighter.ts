import { Transaction } from "@mysten/sui/transactions";
import { PACKAGE_ID } from "@honbu/contract-types";

export function buildMintFighter(args: {
  agentCapId: string;
  hashedId: Uint8Array;
  ringName: string;
  weightClass: number;    // u8
  nationalityCode: number; // u16 (JP=392)
  profileBlobId?: string;
}) {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::fighter::register_fighter`,
    arguments: [
      tx.object(args.agentCapId),
      tx.pure.vector("u8", Array.from(args.hashedId)),
      tx.pure.string(args.ringName),
      tx.pure.u8(args.weightClass),
      tx.pure.u16(args.nationalityCode),
      args.profileBlobId
        ? tx.pure.option("string", args.profileBlobId)
        : tx.pure.option("string", null),
      tx.object("0x6"), // Clock
    ],
  });
  return tx;
}

import { ABORT } from "@honbu/contract-types";

export function parseAbort(errMsg: string): string {
  const m = errMsg.match(/MoveAbort\(.*?,\s*(\d+)\)/);
  if (!m) return errMsg;
  const code = Number(m[1]);
  switch (code) {
    case ABORT.ESlotFull: return "Slot is full";
    case ABORT.EWrongCity: return "Fighter city does not match gym";
    case ABORT.EPastSlot: return "Slot has already started";
    case ABORT.ETooLateToCancel: return "Cancel window closed (<24h to start)";
    case ABORT.EInvalidHashedId: return "Invalid hashed_id length";
    case ABORT.EAgentMismatch: return "Agent mismatch";
    default: return `MoveAbort(${code})`;
  }
}

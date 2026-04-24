export const PACKAGE_ID =
  "0x76969441e81eac68563043c20dc20e0020ac1ade2db1a906d3c86a6c4025c683";
export const GYM_ID =
  "0x945ec73c17a170f9918ef9b7fa16b1bde6039051b9244c695c2f68c262a60adc";

export const MOD = {
  fighter: `${PACKAGE_ID}::fighter`,
  venue: `${PACKAGE_ID}::venue`,
  booking: `${PACKAGE_ID}::booking`,
  admin: `${PACKAGE_ID}::admin`,
} as const;

export const T = {
  Fighter: `${MOD.fighter}::Fighter`,
  AgentCap: `${MOD.fighter}::AgentCap`,
  AdminCap: `${MOD.admin}::AdminCap`,
  Gym: `${MOD.venue}::Gym`,
  TrainingSlot: `${MOD.venue}::TrainingSlot`,
  Booking: `${MOD.booking}::Booking`,
  BookingReceipt: `${MOD.booking}::BookingReceipt`,
} as const;

// Abort codes (from Move sources)
export const ABORT = {
  EInvalidHashedId: 3,
  ESlotFull: 4,
  EWrongCity: 5,
  EPastSlot: 6,
  ETooLateToCancel: 7,
  EAgentMismatch: 20,
} as const;

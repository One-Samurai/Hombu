import { MOD } from "./index";
export const EV = {
  FighterRegistered: `${MOD.fighter}::FighterRegistered`,
  SlotCreated: `${MOD.venue}::SlotCreated`,
  SlotBooked: `${MOD.booking}::SlotBooked`,
  BookingCancelled: `${MOD.booking}::BookingCancelled`,
  BookingCompleted: `${MOD.booking}::BookingCompleted`,
} as const;

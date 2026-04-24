import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

export type SessionState = {
  jwt?: string;
  userSalt?: string;
  ephemeralSecret?: string;  // base64 of Ed25519 secret
  maxEpoch?: number;
  randomness?: string;
  zkProof?: unknown;
  address?: string;
  fighterId?: string;
  agentCapId?: string;
  set: (patch: Partial<SessionState>) => void;
  clear: () => void;
};

export const useSession = create<SessionState>()(
  persist(
    (set) => ({
      set: (patch) => set(patch),
      clear: () =>
        set({
          jwt: undefined, userSalt: undefined, ephemeralSecret: undefined,
          maxEpoch: undefined, randomness: undefined, zkProof: undefined,
          address: undefined, fighterId: undefined, agentCapId: undefined,
        }),
    }),
    { name: "honbu-session", storage: createJSONStorage(() => localStorage) }
  )
);

import { describe, it, expect, beforeEach } from "vitest";
import { useSession } from "@/lib/store";

describe("session store", () => {
  beforeEach(() => useSession.getState().clear());
  it("starts empty", () => {
    expect(useSession.getState().jwt).toBeUndefined();
    expect(useSession.getState().address).toBeUndefined();
  });
  it("persists and clears fields", () => {
    useSession.getState().set({ jwt: "x", address: "0xabc", userSalt: "1" });
    expect(useSession.getState().address).toBe("0xabc");
    useSession.getState().clear();
    expect(useSession.getState().jwt).toBeUndefined();
  });
});

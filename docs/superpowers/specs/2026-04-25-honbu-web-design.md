# HONBU Web — Day 4 Frontend Scaffold Spec

**Date:** 2026-04-25
**Scope:** Next.js MVP delivering zkLogin → mint Fighter → browse slots → book → my bookings.
**Out of scope (Day 5+):** Gym Admin page, Walrus upload, Display V2 registration, pitch deck.

## 1. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Framework | Next.js 15 App Router | SSR-friendly routes, shadcn compat |
| Deploy | Vercel | Push-to-deploy, OAuth callback URL trivial |
| Package layout | pnpm workspace: `apps/web` + `packages/contract-types` | TS types sharable with future admin app |
| Styling | Tailwind + shadcn/ui | Dialog/Button/Card/Toast match booking UX |
| Chain SDK | `@mysten/sui` + `@mysten/dapp-kit` + `@mysten/zklogin` | Official, GraphQL-ready |
| Data fetching | dapp-kit hooks on `@tanstack/query` | Built-in cache/invalidate |
| State | Zustand + `persist` middleware | zkLogin session survives reload |
| Auth | zkLogin — Google only | Single provider for demo |
| Salt | Mysten dev salt server | Hackathon-acceptable; README flags prod risk |
| Network | Sui testnet via **GraphQL endpoint** `https://sui-testnet.mystenlabs.com/graphql` | JSON-RPC deprecated 2026-04 |

## 2. Directory Layout

```
apps/web/
  app/
    layout.tsx                 Providers: SuiClientProvider (GraphQL), QueryClient, WalletProvider
    page.tsx                   Landing — CTA "Login with Google"
    login/page.tsx             Kick off Google OAuth with nonce = hash(ephKey, maxEpoch, randomness)
    auth/callback/page.tsx     Consume JWT → fetch salt → derive addr → fetch zk proof → persist
    fighters/mint/page.tsx     If no Fighter owned by addr → form → mint → redirect /slots
    slots/page.tsx             List open future TrainingSlots (GraphQL objects filter)
    slots/[id]/page.tsx        Detail + Book button
    bookings/page.tsx          List owned BookingReceipts → expand Booking detail on click
  lib/
    sui.ts                     SuiGraphQLClient + SuiClient for tx execution
    zklogin/
      ephemeral.ts             Ed25519 ephemeral keypair + maxEpoch
      salt.ts                  Mysten dev salt fetch + retry(1) + typed errors
      proof.ts                 ZK proof fetch from Mysten prover
      address.ts               jwtToAddress(jwt, salt)
      signer.ts                zkLoginSignature wrapper for tx
    store.ts                   Zustand: { jwt, userSalt, ephemeralKey, maxEpoch, zkProof, address, fighterId }
    tx/
      mintFighter.ts           PTB → honbu::fighter::register_fighter
      bookSlot.ts              PTB → honbu::booking::book_slot(slot, fighter, clock)
      cancelBooking.ts         PTB → honbu::booking::cancel_booking
    queries/
      listSlots.ts             GraphQL objects(filter: { type: '<pkg>::venue::TrainingSlot' })
      myFighter.ts             getOwnedObjects(addr, { StructType: Fighter }) → first()
      myReceipts.ts            getOwnedObjects(addr, { StructType: BookingReceipt })
      getBooking.ts            getObject(bookingId)
  config/
    env.ts                     NEXT_PUBLIC_PACKAGE_ID, GYM_ID, NETWORK, GOOGLE_CLIENT_ID, PROVER_URL, SALT_URL

packages/contract-types/
  index.ts                     PACKAGE_ID, module paths, event type strings, struct type strings
  events.ts                    SlotCreated, SlotBooked, BookingCancelled, BookingCompleted types
```

## 3. Data Flow — Golden Path

1. **Login** `/login` → generate ephemeralKey + maxEpoch (+2 epochs) + randomness → nonce → Google OAuth
2. **Callback** `/auth/callback` → JWT → fetch userSalt → `jwtToAddress(jwt, salt)` → fetch zk proof → persist all to Zustand
3. **Fighter check** — query `getOwnedObjects(addr, Fighter)`. If empty → redirect `/fighters/mint`
4. **Mint** — form `display_name` → PTB `register_fighter(registry, agent_cap, display_name, blob_id='', clock)` → sign with zkLoginSig → on success cache `fighterId`
5. **List slots** — `/slots` runs GraphQL `objects(filter: { type: '<pkg>::venue::TrainingSlot' }, first: 50)` → client filters `status == OPEN && start_ms > now_ms`
6. **Book** — `/slots/[id]` → PTB `book_slot(slot, fighter, clock)` → receipt lands in agent's owned objects
7. **My bookings** — `/bookings` → `getOwnedObjects(addr, BookingReceipt)` → for each, `getObject(receipt.booking_id)` (batched)

**Architect feedback applied:**
- ❌ Don't scan shared Bookings → ✅ query owned `BookingReceipt`
- ❌ Don't use events as primary list source → ✅ use `objects(filter)`; events reserved for Day 5 indexer

## 4. PTB Builders (sketch)

```ts
// bookSlot.ts
export function buildBookSlotTx(slotId: string, fighterId: string) {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::booking::book_slot`,
    arguments: [
      tx.object(slotId),
      tx.object(fighterId),
      tx.object.clock(),
    ],
  });
  return tx;
}
```

## 5. Error & Edge Handling

| Scenario | Behavior |
|---|---|
| Salt fetch 5xx/429 | Retry once; else Toast "Login service unavailable" + stay on /login |
| Prover 5xx | Toast + retry button |
| `maxEpoch` expired (epoch check on each tx) | Force re-login; clear Zustand |
| Booking abort: `ESlotFull` (4) | Toast "Slot is full" |
| Booking abort: `EWrongCity` (5) | Toast "Fighter city mismatch" |
| Booking abort: `EPastSlot` (6) | Toast "Slot already started" — also remove from list |
| Cancel abort: `ETooLateToCancel` | Toast "Cancel window closed (<24h)" |
| GraphQL endpoint down | Fallback message; no RPC fallback (JSON-RPC deprecated) |

Abort codes parsed from `tx.effects.status.error` using module name + code.

## 6. Security Considerations

- **No PII on chain** — Fighter `display_name` is user-typed; advise short handle, not real name (warning on mint form). `hashed_id` field stays empty in MVP.
- **Ephemeral key rotation** — maxEpoch = currentEpoch + 2 (~48h). On expiry, force re-login.
- **Salt handling** — never log, never send to third-party beyond Mysten salt server.
- **zkLoginSignature** — built client-side; private key never leaves browser.
- **Package ID pinning** — `NEXT_PUBLIC_PACKAGE_ID` locked in `.env.production`; reject tx if mismatch.

## 7. Testing

| Layer | Tool | Coverage |
|---|---|---|
| Unit | Vitest | PTB builders — input validation, object ref shape |
| Integration | dapp-kit test utils | queries against testnet package (read-only) |
| E2E | Playwright | Golden path — mock OAuth, hit real testnet |
| Monkey | manual | past slot, full slot, cancel edge, double-click, disconnect mid-tx |

## 8. Day-4 Exit Criteria

- [ ] `pnpm dev` in `apps/web` opens landing
- [ ] Login with Google → returns to `/fighters/mint` with derived address visible
- [ ] Mint produces Fighter object, redirects `/slots`
- [ ] `/slots` shows 3 seeded slots
- [ ] Book one slot → tx success → appears in `/bookings`
- [ ] Cancel outside window → abort mapped to Toast
- [ ] Vercel preview URL deployed
- [ ] README section: "run locally" + "prod salt warning"

## 9. Residual Risks (documented, accepted)

- **R1** Mysten dev salt server downtime → MVP cannot login. Mitigation: README, Phase 2 self-host.
- **R2** No Display V2 → wallet/explorer shows raw hex objects. Mitigation: Day 5 adds `display::new<T>`.
- **R3** GraphQL `objects(filter)` pagination for >50 slots. Mitigation: cursor pagination added when seed count grows.
- **R4** Single Google provider → Google outage = full outage. Accepted for demo.

## 10. References

- Seed data: `deployments/seed-testnet-2026-04-25.json`
- Deployed package: `deployments/testnet-2026-04-25.json`
- Move source: `move/honbu/sources/{fighter,venue,booking,admin}.move`
- Contract spec: `docs/specs/2026-04-25-honbu-spec.md`

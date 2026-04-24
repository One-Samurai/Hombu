# HONBU — Samurai Fighter Logistics OS — Technical Spec

**Date:** 2026-04-25
**Target:** Hackathon MVP (7 days)
**SUI Version:** v1.69.1 (Protocol 119) — testnet
**Move Edition:** 2024.beta

---

## 1. Executive Summary

HONBU is a B2B coordination layer for ONE Samurai fight logistics. Core on-chain primitive: **double-booking-proof training slot reservations** via Move's linear object model. Three roles — ONE Admin / Gym / Agent — share a single source of truth for fighter schedules without leaking PII.

**Golden path (MVP):** Gym lists slots → Agent books slot for Fighter → receipt proves reservation → 24h cancel window.

**APPI compliance:** Zero PII on-chain. Only `address`, `hashed_id` (keccak256 of off-chain record), and abstract resource objects.

---

## 2. Architecture Overview

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  ONE Admin   │   │   Gym User   │   │   Agent      │
│  (AdminCap)  │   │  (GymCap)    │   │ (AgentCap)   │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │
       ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────┐
│                HONBU Move Package                    │
│  ┌──────────┐   ┌──────────┐   ┌──────────────┐    │
│  │ fighter  │   │  venue   │   │   booking    │    │
│  │ (SBT)    │   │ (shared) │   │ (hot potato) │    │
│  └──────────┘   └──────────┘   └──────────────┘    │
└─────────────────────────────────────────────────────┘
       │                  │                  │
       ▼                  ▼                  ▼
 Walrus blobs       Postgres (PII)      Events → Indexer
```

---

## 3. Module Design

### 3.1 `honbu::fighter`

Represents an international fighter. Soulbound (non-transferable). Created by Agent via `AgentCap`.

```move
public struct Fighter has key {
    id: UID,
    hashed_id: vector<u8>,         // keccak256(off-chain passport record)
    ring_name: String,             // e.g., "Takeshi Yamamoto" — public
    weight_class: u8,              // enum: 0=strawweight ... 10=heavyweight
    nationality_code: u16,         // ISO 3166-1 numeric
    agent: address,                // managing agent address
    profile_blob_id: Option<String>, // Walrus blob ID (profile image)
    created_at_ms: u64,
    active: bool,
}

public struct AgentCap has key, store {
    id: UID,
    agent_id: ID,                  // links to Agent registry
}
```

**Ability rationale:**
- `Fighter: key` only (no `store`) → soulbound. Cannot be wrapped in other objects or `public_transfer`'d.
- `AgentCap: key + store` → can be held in wallets, transferred via admin flow.

### 3.2 `honbu::venue`

Represents Japanese gyms and their bookable training slots.

```move
public struct Gym has key {
    id: UID,
    name: String,
    city_code: u16,                // ISO city code
    gym_cap_id: ID,
    photo_blob_id: Option<String>, // Walrus
    active: bool,
}

public struct TrainingSlot has key {  // SHARED
    id: UID,
    gym_id: ID,
    start_ms: u64,
    duration_min: u16,
    capacity: u8,                  // max fighters in this slot
    booked_count: u8,
    status: u8,                    // 0=open, 1=full, 2=cancelled
}

public struct GymCap has key, store {
    id: UID,
    gym_id: ID,
}
```

**Why TrainingSlot is shared:**
Multiple agents must concurrently read and contend for the same slot. Owned objects would serialize through a single sender. Sui's consensus layer handles the MVCC-style write ordering for shared objects.

### 3.3 `honbu::booking`

The atomic link between Fighter and TrainingSlot.

```move
public struct Booking has key {
    id: UID,
    fighter_id: ID,
    slot_id: ID,
    agent: address,
    booked_at_ms: u64,
    status: u8,                    // 0=active, 1=cancelled, 2=completed
}

// Receipt held by Agent — proof of reservation
public struct BookingReceipt has key, store {
    id: UID,
    booking_id: ID,
    fighter_id: ID,
    slot_start_ms: u64,
}
```

---

## 4. Entry Functions

### 4.1 fighter module

```move
// ONE admin bootstraps an agent
public entry fun create_agent_cap(
    _admin: &AdminCap,
    agent_addr: address,
    ctx: &mut TxContext,
)

// Agent registers a new fighter
public entry fun register_fighter(
    cap: &AgentCap,
    hashed_id: vector<u8>,
    ring_name: String,
    weight_class: u8,
    nationality_code: u16,
    profile_blob_id: Option<String>,
    ctx: &mut TxContext,
)

// Agent updates profile image (Walrus blob)
public entry fun update_profile_blob(
    cap: &AgentCap,
    fighter: &mut Fighter,
    new_blob_id: String,
)

// Admin deactivates a fighter (retire/ban)
public entry fun deactivate_fighter(
    _admin: &AdminCap,
    fighter: &mut Fighter,
)
```

### 4.2 venue module

```move
public entry fun create_gym(
    _admin: &AdminCap,
    name: String,
    city_code: u16,
    gym_owner: address,
    ctx: &mut TxContext,
)

public entry fun create_slot(
    cap: &GymCap,
    gym: &Gym,
    start_ms: u64,
    duration_min: u16,
    capacity: u8,
    clock: &Clock,
    ctx: &mut TxContext,
)

public entry fun cancel_slot(
    cap: &GymCap,
    slot: &mut TrainingSlot,
    clock: &Clock,
)
```

### 4.3 booking module

```move
// Core: atomic book — modifies slot, mints receipt in same tx
public entry fun book_slot(
    cap: &AgentCap,
    fighter: &Fighter,
    slot: &mut TrainingSlot,
    clock: &Clock,
    ctx: &mut TxContext,
)

// Agent cancels (within 24h window)
public entry fun cancel_booking(
    cap: &AgentCap,
    booking: &mut Booking,
    receipt: BookingReceipt,      // consumed
    slot: &mut TrainingSlot,
    clock: &Clock,
)

// Gym marks completed after slot end
public entry fun mark_completed(
    cap: &GymCap,
    booking: &mut Booking,
    slot: &TrainingSlot,
    clock: &Clock,
)
```

---

## 5. Capability / Permission Matrix

| Function              | AdminCap | AgentCap | GymCap | Notes                              |
|-----------------------|:--------:|:--------:|:------:|------------------------------------|
| create_agent_cap      |    ✓     |          |        | Only ONE can onboard agents        |
| create_gym            |    ✓     |          |        | ONE vets partner gyms              |
| deactivate_fighter    |    ✓     |          |        | Retire / ban override              |
| register_fighter      |          |    ✓     |        | Agent manages own roster           |
| update_profile_blob   |          |    ✓*    |        | *Must match `fighter.agent`        |
| book_slot             |          |    ✓*    |        | *Must match `fighter.agent`        |
| cancel_booking        |          |    ✓*    |        | *Must match `booking.agent`        |
| create_slot           |          |          |   ✓*   | *Must match `gym.gym_cap_id`       |
| cancel_slot           |          |          |   ✓*   |                                    |
| mark_completed        |          |          |   ✓*   | Gym attests attendance             |

Capability possession alone is **insufficient** — each function also verifies the cap's `agent_id` / `gym_id` matches the target object. Prevents "stolen cap from unrelated agent" attacks.

---

## 6. Error Codes

```move
// fighter.move
const EInvalidAgentCap: u64 = 1;
const EFighterInactive: u64 = 2;
const EInvalidHashedId: u64 = 3;        // wrong length (!= 32 bytes)

// venue.move
const EGymCapMismatch: u64 = 10;
const ESlotInPast: u64 = 11;
const ESlotCancelled: u64 = 12;
const EInvalidCapacity: u64 = 13;
const EInvalidDuration: u64 = 14;

// booking.move
const EAgentMismatch: u64 = 20;         // cap.agent != fighter.agent
const ESlotFull: u64 = 21;
const ESlotNotOpen: u64 = 22;
const EFighterInactiveForBooking: u64 = 23;
const ECancelWindowClosed: u64 = 24;    // < 24h before start
const EBookingNotActive: u64 = 25;
const ESlotNotEnded: u64 = 26;
const EReceiptMismatch: u64 = 27;       // receipt.booking_id != booking.id
```

---

## 7. Events

```move
public struct FighterRegistered has copy, drop {
    fighter_id: ID, agent: address, hashed_id: vector<u8>, ts_ms: u64,
}

public struct GymCreated has copy, drop {
    gym_id: ID, gym_cap_id: ID, name: String, ts_ms: u64,
}

public struct SlotCreated has copy, drop {
    slot_id: ID, gym_id: ID, start_ms: u64, capacity: u8,
}

public struct SlotBooked has copy, drop {
    booking_id: ID, slot_id: ID, fighter_id: ID, agent: address, ts_ms: u64,
}

public struct BookingCancelled has copy, drop {
    booking_id: ID, slot_id: ID, ts_ms: u64,
}

public struct BookingCompleted has copy, drop {
    booking_id: ID, slot_id: ID, ts_ms: u64,
}
```

Indexer consumes `SlotCreated` + `SlotBooked` + `BookingCancelled` to maintain availability feed for frontend.

---

## 8. Shared vs Owned Decision Table

| Object           | Ownership | Rationale                                                         |
|------------------|-----------|-------------------------------------------------------------------|
| `Fighter`        | Owned by Agent | Soulbound SBT, mutated only by single agent                  |
| `Gym`            | Owned by Gym   | Low contention, single-writer metadata                       |
| `TrainingSlot`   | **Shared**     | Concurrent read/contend by many agents → needs consensus     |
| `Booking`        | **Shared**     | Both agent (cancel) and gym (mark_completed) mutate          |
| `BookingReceipt` | Owned by Agent | Proof artifact — agent's wallet                              |
| `AdminCap`       | Owned          | Held by ONE multisig                                          |
| `AgentCap`       | Owned          | Held by agent address                                         |
| `GymCap`         | Owned          | Held by gym operator                                          |

---

## 9. Attack Vectors (feed to `sui-red-team`)

1. **Double-booking race** — two agents call `book_slot` on same slot simultaneously.
   *Defense:* Sui consensus serializes shared-object writes; `booked_count < capacity` check + increment in same tx. Only one will succeed, other aborts with `ESlotFull`.

2. **Agent impersonation** — holder of `AgentCap` A tries to book using Fighter owned by Agent B.
   *Defense:* `assert!(cap.agent_id == fighter.agent)` + `assert!(tx_sender == fighter.agent)`.

3. **Cancel window bypass** — agent cancels 10 min before slot to dodge no-show penalty.
   *Defense:* `assert!(clock.now_ms + 24*3600*1000 <= slot.start_ms, ECancelWindowClosed)`.

4. **Receipt forgery** — agent fabricates `BookingReceipt` to claim attendance.
   *Defense:* Receipt minted **only** inside `book_slot`; no public constructor. Consumption in `cancel_booking` requires `receipt.booking_id == booking.id`.

5. **Stale slot booking** — book a slot whose start time is already past.
   *Defense:* `assert!(slot.start_ms > clock.now_ms, ESlotInPast)` at book time.

6. **Integer overflow on booked_count** — wrap `u8` if capacity abused.
   *Defense:* Explicit `assert!(slot.booked_count < slot.capacity)` before `+= 1`; Move 2024 aborts on overflow anyway.

7. **Admin key compromise** — single AdminCap loss = total takeover.
   *Defense (post-MVP):* AdminCap held by Sui multisig; for MVP document the risk and use dedicated testnet keypair.

---

## 10. Off-Chain Data Layer

| Data                          | Location       | Key                          |
|-------------------------------|----------------|------------------------------|
| Passport #, visa, phone, email | Postgres      | `user_hash = keccak256(...)` |
| Fighter profile photo          | Walrus        | `blob_id` stored on `Fighter`|
| Gym exterior photos            | Walrus        | `blob_id` on `Gym`           |
| Booking invoice PDFs           | Postgres blob | `booking_id` FK              |

Off-chain record links to on-chain via `hashed_id` — off-chain DB can prove knowledge of PII without revealing it on-chain.

---

## 11. Data Access Strategy

| Query                           | Tool                               |
|---------------------------------|------------------------------------|
| Live slot availability feed     | **GraphQL beta** (frontend)        |
| Individual object state         | **gRPC** (transaction builders)    |
| Historical analytics (future)   | Custom indexer (see `sui-indexer`) |

JSON-RPC is deprecated (removal April 2026) — **do not use**.

---

## 12. Testing Strategy

- **Unit (Move):** per-function happy path + each error code
- **Integration:** full golden path via `#[test_only]` scenario runner
- **Red team:** 7 attack vectors above, one test each
- **Gas benchmark:** `book_slot` baseline (target < 5M gas units)
- **Monkey testing (project rule):** random call sequencing of create_slot/book/cancel with random timestamps

---

## 13. Deployment Plan

1. Day 6: `sui-deployer` → testnet publish, record package ID + AdminCap object ID
2. Seed data: 3 demo agents, 5 demo gyms, 20 slots across next 2 weeks
3. Frontend `.env.testnet` wired to package ID
4. **No mainnet** for hackathon

---

## 14. Gas Optimization Notes

- `String` fields capped in docs (ring_name ≤ 64 bytes, gym name ≤ 128)
- No dynamic fields in MVP → predictable storage rebates
- Events use primitive types only (no nested structs) → cheaper emit

---

## 15. Out of Scope (Phase 2+)

- Pricing fields on `TrainingSlot` (deferred — add when payment policy materializes)
- Payment rails (JPY-stablecoin, DeepBook integration)
- Visa / flight tracking objects
- Fighter→Fan Passport cross-product (Proposal 2 integration)
- Multi-sig AdminCap upgrade path
- Upgradeability policy (UpgradeCap handling)

---

## Appendix A: Module Dependency

```
booking ──depends──► fighter
   │
   └──depends──► venue
```

## Appendix B: Versions

| Component         | Version          |
|-------------------|------------------|
| Sui framework     | v1.69.1          |
| Move edition      | 2024.beta        |
| @mysten/sui SDK   | ^1.x (latest)    |
| @mysten/dapp-kit  | ^0.16 (latest)   |
| Walrus            | testnet          |

module honbu::venue;

use std::string::String;
use sui::clock::Clock;
use sui::event;

use honbu::admin::AdminCap;

// ===== Errors =====
const EGymCapMismatch: u64 = 10;
const ESlotInPast: u64 = 11;
const ESlotCancelled: u64 = 12;
const EInvalidCapacity: u64 = 13;
const EInvalidDuration: u64 = 14;
const ESlotFull: u64 = 21;

// ===== Slot status =====
const STATUS_OPEN: u8 = 0;
const STATUS_FULL: u8 = 1;
const STATUS_CANCELLED: u8 = 2;

// ===== Structs =====

public struct Gym has key {
    id: UID,
    name: String,
    city_code: u16,
    gym_cap_id: ID,
    photo_blob_id: Option<String>,
    active: bool,
}

/// Shared object — contended by many agents during booking. Sui consensus
/// serializes concurrent writes, so the capacity/booked_count invariant holds.
public struct TrainingSlot has key {
    id: UID,
    gym_id: ID,
    start_ms: u64,
    duration_min: u16,
    capacity: u8,
    booked_count: u8,
    status: u8,
}

public struct GymCap has key, store {
    id: UID,
    gym_id: ID,
}

// ===== Events =====

public struct GymCreated has copy, drop {
    gym_id: ID,
    gym_cap_id: ID,
    name: String,
    ts_ms: u64,
}

public struct SlotCreated has copy, drop {
    slot_id: ID,
    gym_id: ID,
    start_ms: u64,
    capacity: u8,
}

public struct SlotCancelled has copy, drop {
    slot_id: ID,
    ts_ms: u64,
}

// ===== Entry functions =====

/// Admin onboards a new partner gym. GymCap is transferred to the gym operator.
public fun create_gym(
    _admin: &AdminCap,
    name: String,
    city_code: u16,
    gym_owner: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let cap_uid = object::new(ctx);
    let cap_id = cap_uid.to_inner();

    let gym = Gym {
        id: object::new(ctx),
        name,
        city_code,
        gym_cap_id: cap_id,
        photo_blob_id: option::none(),
        active: true,
    };
    let gym_id = object::id(&gym);

    let cap = GymCap { id: cap_uid, gym_id };

    event::emit(GymCreated {
        gym_id,
        gym_cap_id: cap_id,
        name: gym.name,
        ts_ms: clock.timestamp_ms(),
    });

    transfer::transfer(gym, gym_owner);
    transfer::public_transfer(cap, gym_owner);
}

/// Gym operator publishes a new bookable training slot.
public fun create_slot(
    cap: &GymCap,
    gym: &Gym,
    start_ms: u64,
    duration_min: u16,
    capacity: u8,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(cap.gym_id == object::id(gym), EGymCapMismatch);
    assert!(start_ms > clock.timestamp_ms(), ESlotInPast);
    assert!(capacity > 0, EInvalidCapacity);
    assert!(duration_min > 0, EInvalidDuration);

    let slot = TrainingSlot {
        id: object::new(ctx),
        gym_id: cap.gym_id,
        start_ms,
        duration_min,
        capacity,
        booked_count: 0,
        status: STATUS_OPEN,
    };

    event::emit(SlotCreated {
        slot_id: object::id(&slot),
        gym_id: cap.gym_id,
        start_ms,
        capacity,
    });

    transfer::share_object(slot);
}

/// Gym cancels a slot. Active bookings remain on-chain but slot.status blocks new ones.
public fun cancel_slot(
    cap: &GymCap,
    slot: &mut TrainingSlot,
    clock: &Clock,
) {
    assert!(cap.gym_id == slot.gym_id, EGymCapMismatch);
    assert!(slot.status != STATUS_CANCELLED, ESlotCancelled);
    slot.status = STATUS_CANCELLED;
    event::emit(SlotCancelled { slot_id: object::id(slot), ts_ms: clock.timestamp_ms() });
}

// ===== Accessors (used by booking module) =====

public fun slot_gym_id(s: &TrainingSlot): ID { s.gym_id }
public fun slot_start_ms(s: &TrainingSlot): u64 { s.start_ms }
public fun slot_duration_min(s: &TrainingSlot): u16 { s.duration_min }
public fun slot_capacity(s: &TrainingSlot): u8 { s.capacity }
public fun slot_booked_count(s: &TrainingSlot): u8 { s.booked_count }
public fun slot_status(s: &TrainingSlot): u8 { s.status }
public fun cap_gym_id(c: &GymCap): ID { c.gym_id }

// ===== Mutators (friend-like surface via package visibility) =====

/// Increment booked_count atomically. Aborts if capacity would be exceeded
/// or slot is not open. Called only by `booking` module within the package.
public(package) fun reserve_seat(slot: &mut TrainingSlot, now_ms: u64) {
    assert!(slot.status != STATUS_CANCELLED, ESlotCancelled);
    assert!(slot.start_ms > now_ms, ESlotInPast);
    assert!(slot.booked_count < slot.capacity, ESlotFull);
    slot.booked_count = slot.booked_count + 1;
    if (slot.booked_count == slot.capacity) {
        slot.status = STATUS_FULL;
    };
}

/// Release a seat (cancellation). Called only by `booking` module.
public(package) fun release_seat(slot: &mut TrainingSlot) {
    assert!(slot.booked_count > 0, EInvalidCapacity);
    slot.booked_count = slot.booked_count - 1;
    if (slot.status == STATUS_FULL) {
        slot.status = STATUS_OPEN;
    };
}

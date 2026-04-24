module honbu::booking;

use sui::clock::Clock;
use sui::event;

use honbu::fighter::{Self, Fighter, AgentCap};
use honbu::venue::{Self, TrainingSlot, GymCap};

// ===== Errors =====
const EAgentMismatch: u64 = 20;
const EFighterInactiveForBooking: u64 = 23;
const ECancelWindowClosed: u64 = 24;
const EBookingNotActive: u64 = 25;
const ESlotNotEnded: u64 = 26;
const EReceiptMismatch: u64 = 27;
const ESlotMismatch: u64 = 28;
const EGymMismatch: u64 = 29;

// ===== Status =====
const BOOKING_ACTIVE: u8 = 0;
const BOOKING_CANCELLED: u8 = 1;
const BOOKING_COMPLETED: u8 = 2;

// 24h in milliseconds
const CANCEL_WINDOW_MS: u64 = 86_400_000;

// ===== Structs =====

/// Shared — both agent (cancel) and gym (mark_completed) mutate it.
public struct Booking has key {
    id: UID,
    fighter_id: ID,
    slot_id: ID,
    agent: address,
    booked_at_ms: u64,
    status: u8,
}

/// Proof held by the agent. Minted only inside `book_slot`; no public constructor.
/// Consumed by value in `cancel_booking` to bind the cancellation to the original booking.
public struct BookingReceipt has key, store {
    id: UID,
    booking_id: ID,
    fighter_id: ID,
    slot_start_ms: u64,
}

// ===== Events =====

public struct SlotBooked has copy, drop {
    booking_id: ID,
    slot_id: ID,
    fighter_id: ID,
    agent: address,
    ts_ms: u64,
}

public struct BookingCancelled has copy, drop {
    booking_id: ID,
    slot_id: ID,
    ts_ms: u64,
}

public struct BookingCompleted has copy, drop {
    booking_id: ID,
    slot_id: ID,
    ts_ms: u64,
}

// ===== Entry functions =====

/// Core atomic booking. In a single tx: verify caps, decrement slot availability,
/// create Booking (shared), mint Receipt to agent. Any abort → whole tx reverts.
public fun book_slot(
    cap: &AgentCap,
    fighter_obj: &Fighter,
    slot: &mut TrainingSlot,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();
    let agent_addr = fighter::agent(fighter_obj);

    assert!(fighter::cap_agent(cap) == agent_addr, EAgentMismatch);
    assert!(sender == agent_addr, EAgentMismatch);
    assert!(fighter::is_active(fighter_obj), EFighterInactiveForBooking);

    let now = clock.timestamp_ms();
    venue::reserve_seat(slot, now); // enforces status OPEN, start in future, capacity.

    let fighter_id = object::id(fighter_obj);
    let slot_id = object::id(slot);

    let booking = Booking {
        id: object::new(ctx),
        fighter_id,
        slot_id,
        agent: agent_addr,
        booked_at_ms: now,
        status: BOOKING_ACTIVE,
    };
    let booking_id = object::id(&booking);

    let receipt = BookingReceipt {
        id: object::new(ctx),
        booking_id,
        fighter_id,
        slot_start_ms: venue::slot_start_ms(slot),
    };

    event::emit(SlotBooked {
        booking_id,
        slot_id,
        fighter_id,
        agent: agent_addr,
        ts_ms: now,
    });

    transfer::share_object(booking);
    transfer::public_transfer(receipt, agent_addr);
}

/// Agent cancels a booking (must be ≥24h before slot start). Receipt consumed.
public fun cancel_booking(
    cap: &AgentCap,
    booking: &mut Booking,
    receipt: BookingReceipt,
    slot: &mut TrainingSlot,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();
    assert!(fighter::cap_agent(cap) == booking.agent, EAgentMismatch);
    assert!(sender == booking.agent, EAgentMismatch);
    assert!(booking.status == BOOKING_ACTIVE, EBookingNotActive);
    assert!(receipt.booking_id == object::id(booking), EReceiptMismatch);
    assert!(booking.slot_id == object::id(slot), ESlotMismatch);

    let now = clock.timestamp_ms();
    assert!(now + CANCEL_WINDOW_MS <= venue::slot_start_ms(slot), ECancelWindowClosed);

    booking.status = BOOKING_CANCELLED;
    venue::release_seat(slot);

    event::emit(BookingCancelled {
        booking_id: object::id(booking),
        slot_id: object::id(slot),
        ts_ms: now,
    });

    // Consume receipt
    let BookingReceipt { id, .. } = receipt;
    id.delete();
}

/// Gym attests attendance after slot ends.
public fun mark_completed(
    cap: &GymCap,
    booking: &mut Booking,
    slot: &TrainingSlot,
    clock: &Clock,
) {
    assert!(venue::cap_gym_id(cap) == venue::slot_gym_id(slot), EGymMismatch);
    assert!(booking.slot_id == object::id(slot), ESlotMismatch);
    assert!(booking.status == BOOKING_ACTIVE, EBookingNotActive);

    let now = clock.timestamp_ms();
    let end_ms = venue::slot_start_ms(slot) + (venue::slot_duration_min(slot) as u64) * 60_000;
    assert!(now >= end_ms, ESlotNotEnded);

    booking.status = BOOKING_COMPLETED;

    event::emit(BookingCompleted {
        booking_id: object::id(booking),
        slot_id: object::id(slot),
        ts_ms: now,
    });
}

// ===== Test-only accessors =====

#[test_only]
public fun receipt_booking_id(r: &BookingReceipt): ID { r.booking_id }

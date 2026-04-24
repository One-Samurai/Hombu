#[test_only]
module honbu::honbu_tests;

use std::string;
use sui::clock::{Self, Clock};
use sui::test_scenario::{Self as ts, Scenario};

use honbu::admin::{Self, AdminCap};
use honbu::fighter::{Self, Fighter, AgentCap};
use honbu::venue::{Self, Gym, GymCap, TrainingSlot};
use honbu::booking::{Self, Booking, BookingReceipt};

// ===== Addresses =====
const ADMIN: address = @0xA11CE;
const AGENT: address = @0xA6E47;
const AGENT2: address = @0xB0B;
const GYM_OWNER: address = @0x61447;

// ===== Error codes (mirrors sources) =====
const EInvalidHashedId: u64 = 3;
const EGymCapMismatch: u64 = 10;
const ESlotInPast: u64 = 11;
const ESlotCancelled: u64 = 12;
const EInvalidCapacity: u64 = 13;
const EInvalidDuration: u64 = 14;
const EAgentMismatch: u64 = 20;
const ESlotFull: u64 = 21;
const EFighterInactiveForBooking: u64 = 23;
const ECancelWindowClosed: u64 = 24;
const EBookingNotActive: u64 = 25;
const ESlotNotEnded: u64 = 26;
const EReceiptMismatch: u64 = 27;
const ESlotMismatch: u64 = 28;

// ===== Time constants =====
const T_NOW: u64 = 1_700_000_000_000;     // baseline "now"
const SLOT_START: u64 = 1_700_200_000_000; // ~55h after T_NOW → cancellable
const HOUR_MS: u64 = 3_600_000;
const DAY_MS: u64 = 86_400_000;

// ===== Helpers =====

fun valid_hash(): vector<u8> {
    let mut v = vector::empty<u8>();
    let mut i = 0;
    while (i < 32) { v.push_back((i as u8)); i = i + 1; };
    v
}

fun new_clock(scenario: &mut Scenario, ts_ms: u64): Clock {
    let mut c = clock::create_for_testing(ts::ctx(scenario));
    clock::set_for_testing(&mut c, ts_ms);
    c
}

/// Bootstrap: AdminCap at ADMIN, AgentCap at AGENT, Gym + GymCap at GYM_OWNER.
fun bootstrap(scenario: &mut Scenario) {
    // Admin mints own cap.
    ts::next_tx(scenario, ADMIN);
    {
        let cap = admin::mint_for_testing(ts::ctx(scenario));
        transfer::public_transfer(cap, ADMIN);
    };

    // Admin creates agent cap for AGENT.
    ts::next_tx(scenario, ADMIN);
    {
        let admin_cap = ts::take_from_sender<AdminCap>(scenario);
        fighter::create_agent_cap(&admin_cap, AGENT, ts::ctx(scenario));
        ts::return_to_sender(scenario, admin_cap);
    };

    // Admin creates gym for GYM_OWNER.
    ts::next_tx(scenario, ADMIN);
    {
        let admin_cap = ts::take_from_sender<AdminCap>(scenario);
        let clk = new_clock(scenario, T_NOW);
        venue::create_gym(
            &admin_cap,
            string::utf8(b"Dojo Tokyo"),
            392, // JP
            GYM_OWNER,
            &clk,
            ts::ctx(scenario),
        );
        clock::destroy_for_testing(clk);
        ts::return_to_sender(scenario, admin_cap);
    };
}

fun register_default_fighter(scenario: &mut Scenario, sender: address) {
    ts::next_tx(scenario, sender);
    let cap = ts::take_from_sender<AgentCap>(scenario);
    let clk = new_clock(scenario, T_NOW);
    fighter::register_fighter(
        &cap,
        valid_hash(),
        string::utf8(b"Takeshi"),
        5,
        392,
        option::none(),
        &clk,
        ts::ctx(scenario),
    );
    clock::destroy_for_testing(clk);
    ts::return_to_sender(scenario, cap);
}

fun create_default_slot(scenario: &mut Scenario, capacity: u8, start_ms: u64): ID {
    ts::next_tx(scenario, GYM_OWNER);
    let gym_cap = ts::take_from_sender<GymCap>(scenario);
    let gym = ts::take_from_sender<Gym>(scenario);
    let clk = new_clock(scenario, T_NOW);
    venue::create_slot(&gym_cap, &gym, start_ms, 60, capacity, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_to_sender(scenario, gym);
    ts::return_to_sender(scenario, gym_cap);
    // Return a placeholder; tests take_shared<TrainingSlot> directly.
    object::id_from_address(@0x0)
}

// =========================================================
// Golden Path
// =========================================================

#[test]
fun golden_path_book_and_complete() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    register_default_fighter(scenario, AGENT);
    create_default_slot(scenario, 2, SLOT_START);

    // Agent books slot.
    ts::next_tx(scenario, AGENT);
    {
        let cap = ts::take_from_sender<AgentCap>(scenario);
        let fighter_obj = ts::take_from_sender<Fighter>(scenario);
        let mut slot = ts::take_shared<TrainingSlot>(scenario);
        let clk = new_clock(scenario, T_NOW);
        booking::book_slot(&cap, &fighter_obj, &mut slot, &clk, ts::ctx(scenario));
        assert!(venue::slot_booked_count(&slot) == 1, 100);
        clock::destroy_for_testing(clk);
        ts::return_shared(slot);
        ts::return_to_sender(scenario, fighter_obj);
        ts::return_to_sender(scenario, cap);
    };

    // Gym marks completed after slot end.
    ts::next_tx(scenario, GYM_OWNER);
    {
        let gym_cap = ts::take_from_sender<GymCap>(scenario);
        let mut booking_obj = ts::take_shared<Booking>(scenario);
        let slot = ts::take_shared<TrainingSlot>(scenario);
        // Past slot end = start + 60min + buffer
        let clk = new_clock(scenario, SLOT_START + 2 * HOUR_MS);
        booking::mark_completed(&gym_cap, &mut booking_obj, &slot, &clk);
        clock::destroy_for_testing(clk);
        ts::return_shared(slot);
        ts::return_shared(booking_obj);
        ts::return_to_sender(scenario, gym_cap);
    };

    ts::end(scenario_val);
}

#[test]
fun golden_path_book_and_cancel() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    register_default_fighter(scenario, AGENT);
    create_default_slot(scenario, 1, SLOT_START);

    // Book.
    ts::next_tx(scenario, AGENT);
    {
        let cap = ts::take_from_sender<AgentCap>(scenario);
        let fighter_obj = ts::take_from_sender<Fighter>(scenario);
        let mut slot = ts::take_shared<TrainingSlot>(scenario);
        let clk = new_clock(scenario, T_NOW);
        booking::book_slot(&cap, &fighter_obj, &mut slot, &clk, ts::ctx(scenario));
        // Capacity 1 → status now FULL (1).
        assert!(venue::slot_status(&slot) == 1, 101);
        clock::destroy_for_testing(clk);
        ts::return_shared(slot);
        ts::return_to_sender(scenario, fighter_obj);
        ts::return_to_sender(scenario, cap);
    };

    // Cancel ≥24h before start.
    ts::next_tx(scenario, AGENT);
    {
        let cap = ts::take_from_sender<AgentCap>(scenario);
        let receipt = ts::take_from_sender<BookingReceipt>(scenario);
        let mut booking_obj = ts::take_shared<Booking>(scenario);
        let mut slot = ts::take_shared<TrainingSlot>(scenario);
        let clk = new_clock(scenario, T_NOW); // ~55h before start
        booking::cancel_booking(&cap, &mut booking_obj, receipt, &mut slot, &clk, ts::ctx(scenario));
        assert!(venue::slot_booked_count(&slot) == 0, 102);
        assert!(venue::slot_status(&slot) == 0, 103); // back to OPEN
        clock::destroy_for_testing(clk);
        ts::return_shared(slot);
        ts::return_shared(booking_obj);
        ts::return_to_sender(scenario, cap);
    };

    ts::end(scenario_val);
}

// =========================================================
// fighter module edge cases
// =========================================================

#[test]
#[expected_failure(abort_code = EInvalidHashedId, location = honbu::fighter)]
fun register_fighter_rejects_short_hash() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);

    ts::next_tx(scenario, AGENT);
    let cap = ts::take_from_sender<AgentCap>(scenario);
    let clk = new_clock(scenario, T_NOW);
    fighter::register_fighter(
        &cap,
        b"short", // != 32 bytes
        string::utf8(b"X"),
        0,
        392,
        option::none(),
        &clk,
        ts::ctx(scenario),
    );
    clock::destroy_for_testing(clk);
    ts::return_to_sender(scenario, cap);
    ts::end(scenario_val);
}

#[test]
fun deactivate_fighter_flips_active_flag() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    register_default_fighter(scenario, AGENT);

    // Admin deactivates.
    ts::next_tx(scenario, ADMIN);
    {
        let admin_cap = ts::take_from_sender<AdminCap>(scenario);
        let mut fighter_obj = ts::take_from_address<Fighter>(scenario, AGENT);
        let clk = new_clock(scenario, T_NOW);
        fighter::deactivate_fighter(&admin_cap, &mut fighter_obj, &clk);
        assert!(!fighter::is_active(&fighter_obj), 200);
        clock::destroy_for_testing(clk);
        ts::return_to_address(AGENT, fighter_obj);
        ts::return_to_sender(scenario, admin_cap);
    };
    ts::end(scenario_val);
}

// =========================================================
// venue module edge cases
// =========================================================

#[test]
#[expected_failure(abort_code = ESlotInPast, location = honbu::venue)]
fun create_slot_rejects_past_start() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);

    ts::next_tx(scenario, GYM_OWNER);
    let gym_cap = ts::take_from_sender<GymCap>(scenario);
    let gym = ts::take_from_sender<Gym>(scenario);
    let clk = new_clock(scenario, T_NOW);
    venue::create_slot(&gym_cap, &gym, T_NOW - 1, 60, 2, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_to_sender(scenario, gym);
    ts::return_to_sender(scenario, gym_cap);
    ts::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = EInvalidCapacity, location = honbu::venue)]
fun create_slot_rejects_zero_capacity() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    ts::next_tx(scenario, GYM_OWNER);
    let gym_cap = ts::take_from_sender<GymCap>(scenario);
    let gym = ts::take_from_sender<Gym>(scenario);
    let clk = new_clock(scenario, T_NOW);
    venue::create_slot(&gym_cap, &gym, SLOT_START, 60, 0, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_to_sender(scenario, gym);
    ts::return_to_sender(scenario, gym_cap);
    ts::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = EInvalidDuration, location = honbu::venue)]
fun create_slot_rejects_zero_duration() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    ts::next_tx(scenario, GYM_OWNER);
    let gym_cap = ts::take_from_sender<GymCap>(scenario);
    let gym = ts::take_from_sender<Gym>(scenario);
    let clk = new_clock(scenario, T_NOW);
    venue::create_slot(&gym_cap, &gym, SLOT_START, 0, 2, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_to_sender(scenario, gym);
    ts::return_to_sender(scenario, gym_cap);
    ts::end(scenario_val);
}

#[test]
fun cancel_slot_sets_status_cancelled() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    create_default_slot(scenario, 2, SLOT_START);

    ts::next_tx(scenario, GYM_OWNER);
    {
        let gym_cap = ts::take_from_sender<GymCap>(scenario);
        let mut slot = ts::take_shared<TrainingSlot>(scenario);
        let clk = new_clock(scenario, T_NOW);
        venue::cancel_slot(&gym_cap, &mut slot, &clk);
        assert!(venue::slot_status(&slot) == 2, 300);
        clock::destroy_for_testing(clk);
        ts::return_shared(slot);
        ts::return_to_sender(scenario, gym_cap);
    };
    ts::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = ESlotCancelled, location = honbu::venue)]
fun cancel_slot_twice_aborts() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    create_default_slot(scenario, 2, SLOT_START);

    ts::next_tx(scenario, GYM_OWNER);
    let gym_cap = ts::take_from_sender<GymCap>(scenario);
    let mut slot = ts::take_shared<TrainingSlot>(scenario);
    let clk = new_clock(scenario, T_NOW);
    venue::cancel_slot(&gym_cap, &mut slot, &clk);
    venue::cancel_slot(&gym_cap, &mut slot, &clk); // expected_failure here
    clock::destroy_for_testing(clk);
    ts::return_shared(slot);
    ts::return_to_sender(scenario, gym_cap);
    ts::end(scenario_val);
}

// =========================================================
// booking module — error paths
// =========================================================

#[test]
#[expected_failure(abort_code = ESlotFull, location = honbu::venue)]
fun book_slot_aborts_when_full() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    register_default_fighter(scenario, AGENT);
    create_default_slot(scenario, 1, SLOT_START);

    // First booking fills capacity 1.
    ts::next_tx(scenario, AGENT);
    {
        let cap = ts::take_from_sender<AgentCap>(scenario);
        let f = ts::take_from_sender<Fighter>(scenario);
        let mut slot = ts::take_shared<TrainingSlot>(scenario);
        let clk = new_clock(scenario, T_NOW);
        booking::book_slot(&cap, &f, &mut slot, &clk, ts::ctx(scenario));
        clock::destroy_for_testing(clk);
        ts::return_shared(slot);
        ts::return_to_sender(scenario, f);
        ts::return_to_sender(scenario, cap);
    };

    // Second booking on same fighter → should hit ESlotFull.
    ts::next_tx(scenario, AGENT);
    let cap = ts::take_from_sender<AgentCap>(scenario);
    let f = ts::take_from_sender<Fighter>(scenario);
    let mut slot = ts::take_shared<TrainingSlot>(scenario);
    let clk = new_clock(scenario, T_NOW);
    booking::book_slot(&cap, &f, &mut slot, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_shared(slot);
    ts::return_to_sender(scenario, f);
    ts::return_to_sender(scenario, cap);
    ts::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = EAgentMismatch, location = honbu::booking)]
fun book_slot_rejects_wrong_agent() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);

    // Admin creates a second agent cap for AGENT2.
    ts::next_tx(scenario, ADMIN);
    {
        let admin_cap = ts::take_from_sender<AdminCap>(scenario);
        fighter::create_agent_cap(&admin_cap, AGENT2, ts::ctx(scenario));
        ts::return_to_sender(scenario, admin_cap);
    };

    register_default_fighter(scenario, AGENT);
    create_default_slot(scenario, 2, SLOT_START);

    // AGENT2 tries to book AGENT's fighter → EAgentMismatch.
    ts::next_tx(scenario, AGENT2);
    let cap2 = ts::take_from_sender<AgentCap>(scenario);
    let f = ts::take_from_address<Fighter>(scenario, AGENT);
    let mut slot = ts::take_shared<TrainingSlot>(scenario);
    let clk = new_clock(scenario, T_NOW);
    booking::book_slot(&cap2, &f, &mut slot, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_shared(slot);
    ts::return_to_address(AGENT, f);
    ts::return_to_sender(scenario, cap2);
    ts::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = EFighterInactiveForBooking, location = honbu::booking)]
fun book_slot_rejects_inactive_fighter() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    register_default_fighter(scenario, AGENT);
    create_default_slot(scenario, 2, SLOT_START);

    // Admin deactivates fighter.
    ts::next_tx(scenario, ADMIN);
    {
        let admin_cap = ts::take_from_sender<AdminCap>(scenario);
        let mut f = ts::take_from_address<Fighter>(scenario, AGENT);
        let clk = new_clock(scenario, T_NOW);
        fighter::deactivate_fighter(&admin_cap, &mut f, &clk);
        clock::destroy_for_testing(clk);
        ts::return_to_address(AGENT, f);
        ts::return_to_sender(scenario, admin_cap);
    };

    ts::next_tx(scenario, AGENT);
    let cap = ts::take_from_sender<AgentCap>(scenario);
    let f = ts::take_from_sender<Fighter>(scenario);
    let mut slot = ts::take_shared<TrainingSlot>(scenario);
    let clk = new_clock(scenario, T_NOW);
    booking::book_slot(&cap, &f, &mut slot, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_shared(slot);
    ts::return_to_sender(scenario, f);
    ts::return_to_sender(scenario, cap);
    ts::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = ECancelWindowClosed, location = honbu::booking)]
fun cancel_booking_inside_24h_window_aborts() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    register_default_fighter(scenario, AGENT);
    create_default_slot(scenario, 1, SLOT_START);

    ts::next_tx(scenario, AGENT);
    {
        let cap = ts::take_from_sender<AgentCap>(scenario);
        let f = ts::take_from_sender<Fighter>(scenario);
        let mut slot = ts::take_shared<TrainingSlot>(scenario);
        let clk = new_clock(scenario, T_NOW);
        booking::book_slot(&cap, &f, &mut slot, &clk, ts::ctx(scenario));
        clock::destroy_for_testing(clk);
        ts::return_shared(slot);
        ts::return_to_sender(scenario, f);
        ts::return_to_sender(scenario, cap);
    };

    // Try cancel 10 min before start (< 24h) → ECancelWindowClosed.
    ts::next_tx(scenario, AGENT);
    let cap = ts::take_from_sender<AgentCap>(scenario);
    let receipt = ts::take_from_sender<BookingReceipt>(scenario);
    let mut booking_obj = ts::take_shared<Booking>(scenario);
    let mut slot = ts::take_shared<TrainingSlot>(scenario);
    let clk = new_clock(scenario, SLOT_START - 10 * 60_000);
    booking::cancel_booking(&cap, &mut booking_obj, receipt, &mut slot, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_shared(slot);
    ts::return_shared(booking_obj);
    ts::return_to_sender(scenario, cap);
    ts::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = ESlotNotEnded, location = honbu::booking)]
fun mark_completed_before_slot_end_aborts() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap(scenario);
    register_default_fighter(scenario, AGENT);
    create_default_slot(scenario, 1, SLOT_START);

    ts::next_tx(scenario, AGENT);
    {
        let cap = ts::take_from_sender<AgentCap>(scenario);
        let f = ts::take_from_sender<Fighter>(scenario);
        let mut slot = ts::take_shared<TrainingSlot>(scenario);
        let clk = new_clock(scenario, T_NOW);
        booking::book_slot(&cap, &f, &mut slot, &clk, ts::ctx(scenario));
        clock::destroy_for_testing(clk);
        ts::return_shared(slot);
        ts::return_to_sender(scenario, f);
        ts::return_to_sender(scenario, cap);
    };

    // Gym marks completed before slot start → ESlotNotEnded.
    ts::next_tx(scenario, GYM_OWNER);
    let gym_cap = ts::take_from_sender<GymCap>(scenario);
    let mut booking_obj = ts::take_shared<Booking>(scenario);
    let slot = ts::take_shared<TrainingSlot>(scenario);
    let clk = new_clock(scenario, T_NOW);
    booking::mark_completed(&gym_cap, &mut booking_obj, &slot, &clk);
    clock::destroy_for_testing(clk);
    ts::return_shared(slot);
    ts::return_shared(booking_obj);
    ts::return_to_sender(scenario, gym_cap);
    ts::end(scenario_val);
}

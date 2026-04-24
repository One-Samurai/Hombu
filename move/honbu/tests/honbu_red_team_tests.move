#[test_only]
module honbu::honbu_red_team_tests;

// Adversarial attack tests — one per threat-model vector (docs/security/threat-model.md).
// Vector 7 (admin key compromise) is out of MVP scope; documented residual only.

use std::string;
use sui::clock::{Self, Clock};
use sui::test_scenario::{Self as ts, Scenario};

use honbu::admin::{Self, AdminCap};
use honbu::fighter::{Self, Fighter, AgentCap};
use honbu::venue::{Self, Gym, GymCap, TrainingSlot};
use honbu::booking::{Self, Booking, BookingReceipt};

// ===== Addresses =====
const ADMIN: address = @0xA11CE;
const AGENT_A: address = @0xA6E47A;
const AGENT_B: address = @0xA6E47B;
const GYM_OWNER: address = @0x61447;

// ===== Error codes (mirrors sources) =====
const ESlotInPast: u64 = 11;
const EAgentMismatch: u64 = 20;
const ESlotFull: u64 = 21;
const ECancelWindowClosed: u64 = 24;
const EReceiptMismatch: u64 = 27;

// ===== Time constants =====
const T_NOW: u64 = 1_700_000_000_000;
const SLOT_START: u64 = 1_700_200_000_000; // ~55h after T_NOW → cancellable
const HOUR_MS: u64 = 3_600_000;
const DAY_MS: u64 = 86_400_000;

// ===== Helpers =====

fun valid_hash(seed: u8): vector<u8> {
    let mut v = vector::empty<u8>();
    let mut i: u8 = 0;
    while (i < 32) { v.push_back(seed ^ i); i = i + 1; };
    v
}

fun new_clock(scenario: &mut Scenario, ts_ms: u64): Clock {
    let mut c = clock::create_for_testing(ts::ctx(scenario));
    clock::set_for_testing(&mut c, ts_ms);
    c
}

/// Bootstrap admin + gym + two agent caps (AGENT_A, AGENT_B).
fun bootstrap_two_agents(scenario: &mut Scenario) {
    ts::next_tx(scenario, ADMIN);
    {
        let cap = admin::mint_for_testing(ts::ctx(scenario));
        transfer::public_transfer(cap, ADMIN);
    };
    ts::next_tx(scenario, ADMIN);
    {
        let admin_cap = ts::take_from_sender<AdminCap>(scenario);
        fighter::create_agent_cap(&admin_cap, AGENT_A, ts::ctx(scenario));
        fighter::create_agent_cap(&admin_cap, AGENT_B, ts::ctx(scenario));
        ts::return_to_sender(scenario, admin_cap);
    };
    ts::next_tx(scenario, ADMIN);
    {
        let admin_cap = ts::take_from_sender<AdminCap>(scenario);
        let clk = new_clock(scenario, T_NOW);
        venue::create_gym(
            &admin_cap,
            string::utf8(b"Dojo Tokyo"),
            392,
            GYM_OWNER,
            &clk,
            ts::ctx(scenario),
        );
        clock::destroy_for_testing(clk);
        ts::return_to_sender(scenario, admin_cap);
    };
}

fun register_fighter_for(scenario: &mut Scenario, agent: address, seed: u8) {
    ts::next_tx(scenario, agent);
    let cap = ts::take_from_sender<AgentCap>(scenario);
    let clk = new_clock(scenario, T_NOW);
    fighter::register_fighter(
        &cap,
        valid_hash(seed),
        string::utf8(b"Fighter"),
        5,
        392,
        option::none(),
        &clk,
        ts::ctx(scenario),
    );
    clock::destroy_for_testing(clk);
    ts::return_to_sender(scenario, cap);
}

fun create_slot(scenario: &mut Scenario, capacity: u8, start_ms: u64) {
    ts::next_tx(scenario, GYM_OWNER);
    let gym_cap = ts::take_from_sender<GymCap>(scenario);
    let gym = ts::take_from_sender<Gym>(scenario);
    let clk = new_clock(scenario, T_NOW);
    venue::create_slot(&gym_cap, &gym, start_ms, 60, capacity, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_to_sender(scenario, gym);
    ts::return_to_sender(scenario, gym_cap);
}

// =========================================================
// #1 Double-booking race — two agents, capacity=1
// =========================================================
// Sui serializes shared-object writes; second reserve_seat sees booked_count == capacity → ESlotFull.
#[test]
#[expected_failure(abort_code = ESlotFull, location = honbu::venue)]
fun attack_1_double_booking_race() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap_two_agents(scenario);
    register_fighter_for(scenario, AGENT_A, 1);
    register_fighter_for(scenario, AGENT_B, 2);
    create_slot(scenario, 1, SLOT_START);

    // AGENT_A wins the race.
    ts::next_tx(scenario, AGENT_A);
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

    // AGENT_B arrives second → ESlotFull.
    ts::next_tx(scenario, AGENT_B);
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

// =========================================================
// #2 Cross-agent fighter control — AGENT_B's cap on AGENT_A's fighter
// =========================================================
#[test]
#[expected_failure(abort_code = EAgentMismatch, location = honbu::booking)]
fun attack_2_cross_agent_fighter_control() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap_two_agents(scenario);
    register_fighter_for(scenario, AGENT_A, 1);
    create_slot(scenario, 2, SLOT_START);

    // AGENT_B grabs AGENT_A's fighter and attempts to book with their own cap.
    ts::next_tx(scenario, AGENT_B);
    let cap_b = ts::take_from_sender<AgentCap>(scenario);
    let f_a = ts::take_from_address<Fighter>(scenario, AGENT_A);
    let mut slot = ts::take_shared<TrainingSlot>(scenario);
    let clk = new_clock(scenario, T_NOW);
    booking::book_slot(&cap_b, &f_a, &mut slot, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_shared(slot);
    ts::return_to_address(AGENT_A, f_a);
    ts::return_to_sender(scenario, cap_b);
    ts::end(scenario_val);
}

// =========================================================
// #3 Cancel window bypass — cancel at T-1ms inside the 24h window
// =========================================================
// Boundary: `now + CANCEL_WINDOW_MS <= slot_start`. One millisecond inside → abort.
#[test]
#[expected_failure(abort_code = ECancelWindowClosed, location = honbu::booking)]
fun attack_3_cancel_window_boundary() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap_two_agents(scenario);
    register_fighter_for(scenario, AGENT_A, 1);
    create_slot(scenario, 1, SLOT_START);

    ts::next_tx(scenario, AGENT_A);
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

    // Cancel at exactly SLOT_START - 24h + 1ms → inside window by 1ms.
    ts::next_tx(scenario, AGENT_A);
    let cap = ts::take_from_sender<AgentCap>(scenario);
    let receipt = ts::take_from_sender<BookingReceipt>(scenario);
    let mut booking_obj = ts::take_shared<Booking>(scenario);
    let mut slot = ts::take_shared<TrainingSlot>(scenario);
    let clk = new_clock(scenario, SLOT_START - DAY_MS + 1);
    booking::cancel_booking(&cap, &mut booking_obj, receipt, &mut slot, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_shared(slot);
    ts::return_shared(booking_obj);
    ts::return_to_sender(scenario, cap);
    ts::end(scenario_val);
}

// =========================================================
// #4 Receipt forgery — swap receipts between two bookings of same agent
// =========================================================
// BookingReceipt has no public constructor (type-level defense). Remaining runtime
// attack surface: reuse a different-booking receipt. Expect EReceiptMismatch.
#[test]
#[expected_failure(abort_code = EReceiptMismatch, location = honbu::booking)]
fun attack_4_receipt_swap() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap_two_agents(scenario);
    register_fighter_for(scenario, AGENT_A, 1);

    // First slot + booking.
    create_slot(scenario, 2, SLOT_START);
    ts::next_tx(scenario, AGENT_A);
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
    // Capture booking_A id and slot_A id after the first tx commits.
    ts::next_tx(scenario, AGENT_A);
    let booking_a_id;
    let slot_a_id;
    {
        let b = ts::take_shared<Booking>(scenario);
        booking_a_id = object::id(&b);
        ts::return_shared(b);
        let s = ts::take_shared<TrainingSlot>(scenario);
        slot_a_id = object::id(&s);
        ts::return_shared(s);
    };

    // Second slot + booking. Use take_shared_by_id to disambiguate.
    create_slot(scenario, 2, SLOT_START + HOUR_MS);
    ts::next_tx(scenario, AGENT_A);
    {
        let cap = ts::take_from_sender<AgentCap>(scenario);
        let f = ts::take_from_sender<Fighter>(scenario);
        // The new slot is the one whose id != slot_a_id. Grab by elimination.
        let s_first = ts::take_shared<TrainingSlot>(scenario);
        let mut slot = if (object::id(&s_first) == slot_a_id) {
            ts::return_shared(s_first);
            ts::take_shared<TrainingSlot>(scenario)
        } else {
            s_first
        };
        let clk = new_clock(scenario, T_NOW);
        booking::book_slot(&cap, &f, &mut slot, &clk, ts::ctx(scenario));
        clock::destroy_for_testing(clk);
        ts::return_shared(slot);
        ts::return_to_sender(scenario, f);
        ts::return_to_sender(scenario, cap);
    };

    // Attack: cancel booking_A with the OTHER receipt.
    ts::next_tx(scenario, AGENT_A);
    let cap = ts::take_from_sender<AgentCap>(scenario);
    let mut booking_a = ts::take_shared_by_id<Booking>(scenario, booking_a_id);
    let mut slot_a = ts::take_shared_by_id<TrainingSlot>(scenario, slot_a_id);
    // Inspect receipts and pick the one that does NOT match booking_a.
    let r1 = ts::take_from_sender<BookingReceipt>(scenario);
    let r2 = ts::take_from_sender<BookingReceipt>(scenario);
    let wrong = if (booking::receipt_booking_id(&r1) != booking_a_id) {
        ts::return_to_sender(scenario, r2);
        r1
    } else {
        ts::return_to_sender(scenario, r1);
        r2
    };
    let clk = new_clock(scenario, T_NOW);
    booking::cancel_booking(&cap, &mut booking_a, wrong, &mut slot_a, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_shared(slot_a);
    ts::return_shared(booking_a);
    ts::return_to_sender(scenario, cap);
    ts::end(scenario_val);
}

// =========================================================
// #5 Booking slot in the past — advance clock past slot.start_ms
// =========================================================
#[test]
#[expected_failure(abort_code = ESlotInPast, location = honbu::venue)]
fun attack_5_book_past_slot() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap_two_agents(scenario);
    register_fighter_for(scenario, AGENT_A, 1);
    create_slot(scenario, 2, SLOT_START);

    // Clock jumps past SLOT_START → reserve_seat aborts ESlotInPast.
    ts::next_tx(scenario, AGENT_A);
    let cap = ts::take_from_sender<AgentCap>(scenario);
    let f = ts::take_from_sender<Fighter>(scenario);
    let mut slot = ts::take_shared<TrainingSlot>(scenario);
    let clk = new_clock(scenario, SLOT_START + 1);
    booking::book_slot(&cap, &f, &mut slot, &clk, ts::ctx(scenario));
    clock::destroy_for_testing(clk);
    ts::return_shared(slot);
    ts::return_to_sender(scenario, f);
    ts::return_to_sender(scenario, cap);
    ts::end(scenario_val);
}

// =========================================================
// #6 Integer overflow on booked_count — capacity boundary enforcement
// =========================================================
// Defense: `booked_count < capacity` asserted BEFORE `booked_count + 1`. Any attempt
// to exceed aborts ESlotFull instead of u8 overflow. Pin this ordering via cap=1.
#[test]
#[expected_failure(abort_code = ESlotFull, location = honbu::venue)]
fun attack_6_booked_count_overflow_guard() {
    let mut scenario_val = ts::begin(ADMIN);
    let scenario = &mut scenario_val;
    bootstrap_two_agents(scenario);
    register_fighter_for(scenario, AGENT_A, 1);
    register_fighter_for(scenario, AGENT_B, 2);
    create_slot(scenario, 1, SLOT_START);

    // First booking fills capacity (booked_count = 1 = capacity, status → FULL).
    ts::next_tx(scenario, AGENT_A);
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

    // AGENT_B attempts to push booked_count past capacity → ESlotFull (not overflow).
    ts::next_tx(scenario, AGENT_B);
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

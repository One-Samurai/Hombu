module honbu::fighter;

use std::string::String;
use sui::clock::Clock;
use sui::event;

use honbu::admin::AdminCap;

// ===== Errors =====
const EInvalidHashedId: u64 = 3;
const EAgentMismatch: u64 = 20;

// ===== Structs =====

/// Soulbound fighter identity. `key` only (no `store`) → cannot be wrapped,
/// cannot be `public_transfer`'d, enforcing non-transferability at the type level.
public struct Fighter has key {
    id: UID,
    hashed_id: vector<u8>,
    ring_name: String,
    weight_class: u8,
    nationality_code: u16,
    agent: address,
    profile_blob_id: Option<String>,
    created_at_ms: u64,
    active: bool,
}

/// Capability held by an agent. Each cap is bound to a specific agent address;
/// possession alone is not sufficient — functions also verify `cap.agent == fighter.agent`.
public struct AgentCap has key, store {
    id: UID,
    agent: address,
}

// ===== Events =====

public struct FighterRegistered has copy, drop {
    fighter_id: ID,
    agent: address,
    hashed_id: vector<u8>,
    ts_ms: u64,
}

public struct AgentCapIssued has copy, drop {
    cap_id: ID,
    agent: address,
}

public struct FighterDeactivated has copy, drop {
    fighter_id: ID,
    ts_ms: u64,
}

// ===== Entry functions =====

/// ONE Admin bootstraps a new agent. Transfers the AgentCap directly to the agent.
public fun create_agent_cap(
    _admin: &AdminCap,
    agent_addr: address,
    ctx: &mut TxContext,
) {
    let cap = AgentCap { id: object::new(ctx), agent: agent_addr };
    event::emit(AgentCapIssued { cap_id: object::id(&cap), agent: agent_addr });
    transfer::public_transfer(cap, agent_addr);
}

/// Agent registers a new Fighter. PII lives off-chain; only the 32-byte hash lands here.
public fun register_fighter(
    cap: &AgentCap,
    hashed_id: vector<u8>,
    ring_name: String,
    weight_class: u8,
    nationality_code: u16,
    profile_blob_id: Option<String>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(hashed_id.length() == 32, EInvalidHashedId);

    let now = clock.timestamp_ms();
    let fighter = Fighter {
        id: object::new(ctx),
        hashed_id,
        ring_name,
        weight_class,
        nationality_code,
        agent: cap.agent,
        profile_blob_id,
        created_at_ms: now,
        active: true,
    };
    event::emit(FighterRegistered {
        fighter_id: object::id(&fighter),
        agent: cap.agent,
        hashed_id: fighter.hashed_id,
        ts_ms: now,
    });
    // Fighter has no `store` → use plain transfer to agent address.
    transfer::transfer(fighter, cap.agent);
}

/// Agent updates the Walrus blob ID pointing to the fighter's profile image.
public fun update_profile_blob(
    cap: &AgentCap,
    fighter: &mut Fighter,
    new_blob_id: String,
) {
    assert!(cap.agent == fighter.agent, EAgentMismatch);
    fighter.profile_blob_id = option::some(new_blob_id);
}

/// Admin deactivates a fighter (retirement / ban).
public fun deactivate_fighter(
    _admin: &AdminCap,
    fighter: &mut Fighter,
    clock: &Clock,
) {
    fighter.active = false;
    event::emit(FighterDeactivated {
        fighter_id: object::id(fighter),
        ts_ms: clock.timestamp_ms(),
    });
}

// ===== Public accessors (cross-module) =====

public fun agent(f: &Fighter): address { f.agent }
public fun is_active(f: &Fighter): bool { f.active }
public fun cap_agent(cap: &AgentCap): address { cap.agent }

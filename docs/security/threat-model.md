# HONBU Threat Model

## Attackers
- **Malicious agent** — valid AgentCap, tries to book fighters they don't own
- **Compromised gym operator** — valid GymCap, manipulates slots/bookings
- **External attacker** — no cap, tries to craft raw PTBs
- **Insider (ONE staff)** — admin key holder

## Attack Surface → Defense

| # | Vector                       | Defense                                                        | Test           |
|---|------------------------------|----------------------------------------------------------------|----------------|
| 1 | Double-booking race          | Shared-object serialization + capacity check                   | red-team #1    |
| 2 | Cross-agent fighter control  | `cap.agent_id == fighter.agent` assertion                      | red-team #2    |
| 3 | Cancel window bypass         | Clock-based 24h check                                          | red-team #3    |
| 4 | Receipt forgery              | No public constructor; consumed by value in cancel             | red-team #4    |
| 5 | Booking slot in the past     | `slot.start_ms > clock.now_ms` at book time                    | red-team #5    |
| 6 | Integer overflow booked_count| Move 2024 overflow abort + explicit bounds check               | red-team #6    |
| 7 | Admin key compromise         | Document risk; MVP uses isolated testnet key                   | —              |

## Non-Goals (MVP)
- Sybil resistance for agents (ONE vets off-chain)
- DoS via spam slot creation (GymCap gated)
- Front-running book_slot (economically irrelevant — no pricing on-chain)

## Known Residual Risks
- **Clock skew**: Sui `Clock` may drift up to a few seconds; 24h window not affected at tolerance level.
- **Off-chain PII leak**: Postgres compromise = full PII breach. Mitigation lives in infra layer (encryption at rest, row-level ACL) — out of scope for Move spec.

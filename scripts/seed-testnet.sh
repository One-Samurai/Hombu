#!/usr/bin/env bash
# Seed demo Gym + 3 TrainingSlots on testnet.
# Requires: sui CLI, active env = testnet, active addr = deployer.
set -euo pipefail

PKG=0x76969441e81eac68563043c20dc20e0020ac1ade2db1a906d3c86a6c4025c683
ADMIN_CAP=0x4d1d37126c269607f786ff5769e581df8f63b0195429a0a545d39e07bed2e788
CLOCK=0x6
OWNER=$(sui client active-address)
OUT=deployments/seed-testnet-$(date +%Y-%m-%d).json
GAS_BUDGET=50000000

echo "[seed] owner=$OWNER pkg=$PKG"

# 1) create_gym
echo "[seed] create_gym..."
GYM_JSON=$(sui client call \
  --package "$PKG" --module venue --function create_gym \
  --args "$ADMIN_CAP" "Shibuya Samurai Gym" 81 "$OWNER" "$CLOCK" \
  --gas-budget $GAS_BUDGET --json)

GYM_ID=$(echo "$GYM_JSON" | jq -r '.objectChanges[] | select(.objectType? | test("::venue::Gym$")) | .objectId')
GYM_CAP_ID=$(echo "$GYM_JSON" | jq -r '.objectChanges[] | select(.objectType? | test("::venue::GymCap$")) | .objectId')
GYM_DIGEST=$(echo "$GYM_JSON" | jq -r '.digest')
echo "[seed] Gym=$GYM_ID GymCap=$GYM_CAP_ID digest=$GYM_DIGEST"

# 2) create_slot × 3 (tomorrow, +2d, +3d at 19:00 JST = 10:00 UTC)
NOW_MS=$(($(date +%s) * 1000))
DAY_MS=$((24 * 60 * 60 * 1000))

SLOT_IDS=()
for i in 1 2 3; do
  START=$((NOW_MS + i * DAY_MS))
  echo "[seed] create_slot #$i start_ms=$START"
  SLOT_JSON=$(sui client call \
    --package "$PKG" --module venue --function create_slot \
    --args "$GYM_CAP_ID" "$GYM_ID" "$START" 60 4 "$CLOCK" \
    --gas-budget $GAS_BUDGET --json)
  SLOT_ID=$(echo "$SLOT_JSON" | jq -r '.objectChanges[] | select(.objectType? | test("::venue::TrainingSlot$")) | .objectId')
  echo "[seed]   -> slot=$SLOT_ID"
  SLOT_IDS+=("$SLOT_ID")
done

jq -n \
  --arg pkg "$PKG" \
  --arg gym "$GYM_ID" \
  --arg gymCap "$GYM_CAP_ID" \
  --arg owner "$OWNER" \
  --argjson slots "$(printf '%s\n' "${SLOT_IDS[@]}" | jq -R . | jq -s .)" \
  '{network:"testnet", packageId:$pkg, gymId:$gym, gymCapId:$gymCap, gymOwner:$owner, slotIds:$slots, seededAtMs: (now*1000|floor)}' \
  > "$OUT"

echo "[seed] wrote $OUT"
cat "$OUT"

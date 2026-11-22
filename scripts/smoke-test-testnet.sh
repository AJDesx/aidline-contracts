#!/usr/bin/env bash
# End-to-end smoke test for the Aidline contract on Stellar testnet.
#
# Verifies the contract lifecycle:
#   1. Create campaign
#   2. Donate into escrow
#   3. Approve milestone
#   4. Cancel campaign
#   5. Claim pro-rata refund
#
# Usage:
#   ./scripts/smoke-test-testnet.sh <contract_id> <creator_identity> <beneficiary_identity> <verifier_identity> <donor_identity> [token_contract_id]
#
# Or pass via environment variables:
#   AIDLINE_CONTRACT_ID=...
#   AIDLINE_CREATOR=...
#   AIDLINE_BENEFICIARY=...
#   AIDLINE_VERIFIER=...
#   AIDLINE_DONOR=...
#   AIDLINE_TOKEN_ID=... (optional)
#   NETWORK=testnet (optional, defaults to testnet)
#
# All identities must exist in the Stellar CLI keystore and be funded on testnet.
# The verifier must be a registered verifier on the contract and must differ
# from the creator and beneficiary.
set -euo pipefail

trap 'echo ""; echo "=== TESTNET SMOKE TEST FAILED ==="; exit 1' ERR

CONTRACT_ID="${1:-${AIDLINE_CONTRACT_ID:-}}"
CREATOR="${2:-${AIDLINE_CREATOR:-}}"
BENEFICIARY="${3:-${AIDLINE_BENEFICIARY:-}}"
VERIFIER="${4:-${AIDLINE_VERIFIER:-}}"
DONOR="${5:-${AIDLINE_DONOR:-}}"
TOKEN="${6:-${AIDLINE_TOKEN_ID:-}}"
NETWORK="${NETWORK:-testnet}"

if [ -z "$CONTRACT_ID" ] || [ -z "$CREATOR" ] || [ -z "$BENEFICIARY" ] || [ -z "$VERIFIER" ] || [ -z "$DONOR" ]; then
  echo "Usage: $0 <contract_id> <creator_identity> <beneficiary_identity> <verifier_identity> <donor_identity> [token_contract_id]"
  echo ""
  echo "Alternatively set environment variables:"
  echo "  AIDLINE_CONTRACT_ID, AIDLINE_CREATOR, AIDLINE_BENEFICIARY, AIDLINE_VERIFIER, AIDLINE_DONOR"
  exit 1
fi

echo "=== Aidline Testnet Smoke Test ==="
echo "Contract:    $CONTRACT_ID"
echo "Network:     $NETWORK"
echo "Creator:     $CREATOR"
echo "Beneficiary: $BENEFICIARY"
echo "Verifier:    $VERIFIER"
echo "Donor:       $DONOR"

CREATOR_ADDR=$(stellar keys address "$CREATOR")
BENEFICIARY_ADDR=$(stellar keys address "$BENEFICIARY")
VERIFIER_ADDR=$(stellar keys address "$VERIFIER")
DONOR_ADDR=$(stellar keys address "$DONOR")

if [ -z "$TOKEN" ]; then
  echo "Resolving token from contract..."
  TOKEN=$(stellar contract invoke --id "$CONTRACT_ID" --source "$CREATOR" --network "$NETWORK" -- token | tr -d '"')
fi
echo "Token:       $TOKEN"
echo ""

# 1. Create campaign
echo "[1/5] Creating campaign..."
DEADLINE=$(($(date +%s) + 604800)) # 7 days from now
# Two milestones of 10 XLM each (10_000_000 stroops each)
MILESTONES='[10000000, 10000000]'
CAMPAIGN_RAW=$(stellar contract invoke \
  --id "$CONTRACT_ID" \
  --source "$CREATOR" \
  --network "$NETWORK" \
  -- create_campaign \
  --creator "$CREATOR_ADDR" \
  --beneficiary "$BENEFICIARY_ADDR" \
  --verifier "$VERIFIER_ADDR" \
  --token "$TOKEN" \
  --kind Emergency \
  --metadata_uri "ipfs://smoke-test-campaign" \
  --deadline "$DEADLINE" \
  --milestones "$MILESTONES")

# Extract numeric campaign ID (trims quotes/whitespace)
CAMPAIGN_ID=$(echo "$CAMPAIGN_RAW" | tr -dc '0-9')
if [ -z "$CAMPAIGN_ID" ]; then
  echo "Error: Failed to obtain campaign ID from output: $CAMPAIGN_RAW"
  exit 1
fi
echo "  Campaign created with ID: $CAMPAIGN_ID"
echo "  Step 1 PASS"
echo ""

# 2. Donate to campaign
echo "[2/5] Donating to campaign..."
# Donate 15 XLM (15_000_000 stroops) into escrow
DONATE_RAW=$(stellar contract invoke \
  --id "$CONTRACT_ID" \
  --source "$DONOR" \
  --network "$NETWORK" \
  -- donate \
  --donor "$DONOR_ADDR" \
  --campaign_id "$CAMPAIGN_ID" \
  --amount 15000000)
echo "  Donation accepted: $DONATE_RAW"
echo "  Step 2 PASS"
echo ""

# 3. Approve milestone
echo "[3/5] Approving milestone 1..."
APPROVE_RAW=$(stellar contract invoke \
  --id "$CONTRACT_ID" \
  --source "$VERIFIER" \
  --network "$NETWORK" \
  -- approve_milestone \
  --campaign_id "$CAMPAIGN_ID" \
  --proof_uri "ipfs://smoke-test-proof-milestone-1")
echo "  Milestone approved, released: $APPROVE_RAW"
echo "  Step 3 PASS"
echo ""

# 4. Cancel campaign
echo "[4/5] Cancelling campaign..."
stellar contract invoke \
  --id "$CONTRACT_ID" \
  --source "$CREATOR" \
  --network "$NETWORK" \
  -- cancel_campaign \
  --caller "$CREATOR_ADDR" \
  --campaign_id "$CAMPAIGN_ID" >/dev/null
echo "  Campaign $CAMPAIGN_ID cancelled"
echo "  Step 4 PASS"
echo ""

# 5. Refund
echo "[5/5] Claiming pro-rata refund..."
REFUND_RAW=$(stellar contract invoke \
  --id "$CONTRACT_ID" \
  --source "$DONOR" \
  --network "$NETWORK" \
  -- refund \
  --donor "$DONOR_ADDR" \
  --campaign_id "$CAMPAIGN_ID")
echo "  Refund claimed: $REFUND_RAW"
echo "  Step 5 PASS"
echo ""

trap - ERR
echo "=== TESTNET SMOKE TEST PASSED ==="
exit 0

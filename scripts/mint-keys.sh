#!/usr/bin/env bash
# mint-keys.sh — provision per-team virtual keys with model ACLs and budgets.
# Usage: source .env && MASTER=$LITELLM_MASTER_KEY ./scripts/mint-keys.sh
set -euo pipefail

GW="${GW_URL:-http://127.0.0.1:4000}"
MASTER="${MASTER:?set MASTER to the LITELLM_MASTER_KEY from .env}"

mint() {
  local alias=$1
  local models=$2
  local budget=$3
  local note=$4
  curl -s -X POST "$GW/key/generate" \
    -H "Authorization: Bearer $MASTER" \
    -H "Content-Type: application/json" \
    -d "{\"key_alias\":\"$alias\",\"models\":$models,\"max_budget\":$budget,\"metadata\":{\"note\":\"$note\"}}" \
    | jq -r '.key'
}

echo "research   (mock + claude,  \$0.50): $(mint research-tier '["gateway-test","company-claude"]' 0.50 'research tier: mock and Claude')"
echo "restricted (mock only,      \$0.01): $(mint restricted-tier '["gateway-test"]' 0.01 'restricted tier: mock only, tiny budget')"
echo "app        (claude only,    \$1.00): $(mint app-tier '["company-claude"]' 1.00 'app tier: production Claude access')"

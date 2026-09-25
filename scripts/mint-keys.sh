#!/usr/bin/env bash
# mint-keys.sh — provision per-team virtual keys with model ACLs and budgets.
# This is the API-management layer: who may call which model, at what cap.
# Usage: source .env && MASTER=$LITELLM_MASTER_KEY ./scripts/mint-keys.sh
set -euo pipefail

GW="${GW_URL:-http://127.0.0.1:4000}"
MASTER="${MASTER:?set MASTER to the LITELLM_MASTER_KEY from .env}"

mint() { # $1=key_alias  $2=models(json array)  $3=max_budget(usd)  $4=note
  curl -sf -X POST "$GW/key/generate" \
    -H "Authorization: Bearer $MASTER" \
    -H "Content-Type: application/json" \
    -d "{\"key_alias\": \"$1\", \"models\": $2, \"max_budget\": $3, \"metadata\": {\"note\": \"$4\"}}" \
  | jq -r '.key'
}

echo "research   (mock + claude,  \$0.50): $(mint research   '[\"gateway-test\",\"company-claude\"]' 0.50 'research tier: can test mock and call Claude')"
echo "restricted (mock only,      \$0.01): $(mint restricted '[\"gateway-test\"]'                  0.01 'restricted tier: mock only, tiny budget')"
echo "app        (claude only,    \$1.00): $(mint app        '[\"company-claude\"]'                1.00 'app tier: production Claude access')"
echo
echo "Verify:  curl -s $GW/key/list -H \"Authorization: Bearer $MASTER\" | jq '.keys[] | {key_alias, models, max_budget}'"
echo "Audit:    each key's spend lands in LiteLLM_SpendLogs in Postgres."

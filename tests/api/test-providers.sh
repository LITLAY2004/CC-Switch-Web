#!/usr/bin/env bash
# Provider API contract tests.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

require_command curl

BACKUP_FILE=$(mktemp)
backup_config "$BACKUP_FILE"
trap 'restore_config "$BACKUP_FILE" >/dev/null 2>&1; rm -f "$BACKUP_FILE"' EXIT

USAGE_BASE=$(read_fixture_raw '.usageScripts.baseUrl')
BASE_PROVIDER_JSON=$(read_fixture '.providers.codex.base')
UPDATE_FIELDS=$(read_fixture '.providers.codex.update')

PROVIDER_ID=$(generate_id "codex-provider-a")
PROVIDER_ID_B=$(generate_id "codex-provider-b")

provider_payload=$(echo "$BASE_PROVIDER_JSON" | jq --arg id "$PROVIDER_ID" --arg url "$USAGE_BASE" '.id=$id | .settingsConfig.auth.baseUrl=$url')
provider_b_payload=$(echo "$BASE_PROVIDER_JSON" | jq --arg id "$PROVIDER_ID_B" --arg url "$USAGE_BASE" '.id=$id | .name="Codex Fallback Provider" | .settingsConfig.auth.baseUrl=$url')

initial_current=""
api_get "/providers/codex/current" >/dev/null
if [ "$LAST_STATUS" = "200" ]; then
  initial_current=$(echo "$LAST_BODY" | jq -r '.')
  log_info "Captured initial current provider: ${initial_current:-<empty>}"
else
  log_warn "Could not read current provider (status $LAST_STATUS); continuing with empty baseline"
fi

log_step "Add provider $PROVIDER_ID"
api_post "/providers/codex" "$provider_payload" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Create provider returns 200"
assert_contains "true" "$LAST_BODY" "Create provider returns true"

log_step "Add fallback provider $PROVIDER_ID_B"
api_post "/providers/codex" "$provider_b_payload" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Create fallback provider returns 200"

log_step "List providers"
api_get "/providers/codex" >/dev/null
assert_status_code 200 "$LAST_STATUS" "List providers succeeds"
assert_contains "$PROVIDER_ID" "$LAST_BODY" "List contains new provider"
assert_contains "$PROVIDER_ID_B" "$LAST_BODY" "List contains fallback provider"

log_step "Update provider $PROVIDER_ID"
updated_payload=$(echo "$provider_payload" | jq --argjson update "$UPDATE_FIELDS" '.name=$update.name // .name | .notes=$update.notes // .notes')
api_put "/providers/codex/$PROVIDER_ID" "$updated_payload" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Update provider succeeds"
assert_contains "true" "$LAST_BODY" "Update response is true"

log_step "Switch to provider $PROVIDER_ID"
api_post "/providers/codex/$PROVIDER_ID/switch" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Switch endpoint returns 200"

api_get "/providers/codex/current" >/dev/null
current_provider=$(echo "$LAST_BODY" | jq -r '.')
assert_equals "$PROVIDER_ID" "$current_provider" "Current provider updated"

log_step "Switch to fallback provider $PROVIDER_ID_B for cleanup"
api_post "/providers/codex/$PROVIDER_ID_B/switch" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Switch to fallback succeeds"

log_step "Delete provider $PROVIDER_ID"
api_delete "/providers/codex/$PROVIDER_ID" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Delete endpoint returns 200"
assert_contains "true" "$LAST_BODY" "Delete response is true"

api_get "/providers/codex" >/dev/null
assert_status_code 200 "$LAST_STATUS" "List providers after delete succeeds"
assert_contains "$PROVIDER_ID_B" "$LAST_BODY" "Fallback provider remains"

# Attempt to restore original current provider if it existed
api_get "/providers/codex/current" >/dev/null
if [ -n "$initial_current" ] && [ "$initial_current" != "null" ] && [ "$initial_current" != "$PROVIDER_ID_B" ]; then
  log_step "Switch back to original provider $initial_current"
  api_post "/providers/codex/$initial_current/switch" >/dev/null
  assert_status_code 200 "$LAST_STATUS" "Switch back to original succeeds"
fi

# Delete fallback provider if we are no longer on it
api_get "/providers/codex/current" >/dev/null
final_current=$(echo "$LAST_BODY" | jq -r '.')
if [ "$final_current" != "$PROVIDER_ID_B" ]; then
  log_step "Delete fallback provider $PROVIDER_ID_B"
  api_delete "/providers/codex/$PROVIDER_ID_B" >/dev/null
  assert_status_code 200 "$LAST_STATUS" "Delete fallback succeeds"
fi

print_summary
exit $?

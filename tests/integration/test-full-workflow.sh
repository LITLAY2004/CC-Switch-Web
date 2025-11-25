#!/usr/bin/env bash
# End-to-end provider workflow test.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

require_command curl

BACKUP_FILE=$(mktemp)
backup_config "$BACKUP_FILE"
trap 'restore_config "$BACKUP_FILE" >/dev/null 2>&1; rm -f "$BACKUP_FILE"' EXIT

USAGE_BASE=$(read_fixture_raw '.usageScripts.baseUrl')
BASE_PROVIDER=$(read_fixture '.providers.codex.base')
UPDATE_FIELDS=$(read_fixture '.providers.codex.update')

PRIMARY_ID=$(generate_id "workflow-primary")
FALLBACK_ID=$(generate_id "workflow-fallback")

primary_payload=$(echo "$BASE_PROVIDER" | jq --arg id "$PRIMARY_ID" --arg url "$USAGE_BASE" '.id=$id | .name="Workflow Primary" | .settingsConfig.auth.baseUrl=$url')
fallback_payload=$(echo "$BASE_PROVIDER" | jq --arg id "$FALLBACK_ID" --arg url "$USAGE_BASE" '.id=$id | .name="Workflow Fallback" | .settingsConfig.auth.baseUrl=$url')

log_step "List providers before changes"
api_get "/providers/codex" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Initial list succeeds"

log_step "Add primary provider"
api_post "/providers/codex" "$primary_payload" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Create primary provider"

log_step "Add fallback provider"
api_post "/providers/codex" "$fallback_payload" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Create fallback provider"

log_step "Switch to primary provider"
api_post "/providers/codex/$PRIMARY_ID/switch" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Switch to primary"

api_get "/providers/codex/current" >/dev/null
current=$(echo "$LAST_BODY" | jq -r '.')
assert_equals "$PRIMARY_ID" "$current" "Current provider is primary"

log_step "Update primary provider metadata"
updated_payload=$(echo "$primary_payload" | jq --argjson update "$UPDATE_FIELDS" '.name=$update.name // .name | .notes=$update.notes // .notes')
api_put "/providers/codex/$PRIMARY_ID" "$updated_payload" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Update primary provider"

log_step "Switch to fallback to allow deleting primary"
api_post "/providers/codex/$FALLBACK_ID/switch" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Switch to fallback"

log_step "Delete primary provider"
api_delete "/providers/codex/$PRIMARY_ID" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Delete primary provider"

api_get "/providers/codex" >/dev/null
assert_not_contains "$PRIMARY_ID" "$LAST_BODY" "Primary provider removed"

print_summary
exit $?

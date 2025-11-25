#!/usr/bin/env bash
# Persistence test using config export/import.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

require_command curl

BASE_BACKUP=$(mktemp)
backup_config "$BASE_BACKUP"
trap 'restore_config "$BASE_BACKUP" >/dev/null 2>&1; rm -f "$BASE_BACKUP"' EXIT

USAGE_BASE=$(read_fixture_raw '.usageScripts.baseUrl')
BASE_PROVIDER=$(read_fixture '.providers.codex.base')
PROVIDER_ID=$(generate_id "persist-provider")
provider_payload=$(echo "$BASE_PROVIDER" | jq --arg id "$PROVIDER_ID" --arg url "$USAGE_BASE" '.id=$id | .settingsConfig.auth.baseUrl=$url')

log_step "Capture initial provider list"
api_get "/providers/codex" >/dev/null
initial_status=$LAST_STATUS
initial_body="$LAST_BODY"
log_info "Initial list status: $initial_status"

log_step "Add provider to verify persistence"
api_post "/providers/codex" "$provider_payload" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Create provider for persistence test"

log_step "Export config snapshot after creation"
SNAPSHOT_FILE=$(mktemp)
http_request POST "/config/export"
assert_status_code 200 "$LAST_STATUS" "Export after creation"
echo "$LAST_BODY" >"$SNAPSHOT_FILE"
assert_contains "$PROVIDER_ID" "$LAST_BODY" "Snapshot includes new provider"

log_step "Restore original config"
restore_config "$BASE_BACKUP" >/dev/null

log_step "Verify provider state matches baseline"
api_get "/providers/codex" >/dev/null
assert_equals "$initial_status" "$LAST_STATUS" "List status restored"
if [ "$LAST_STATUS" = "200" ]; then
  assert_not_contains "$PROVIDER_ID" "$LAST_BODY" "Transient provider removed after restore"
else
  log_warn "Baseline list was not 200 (status $initial_status); skipping body comparison"
fi

print_summary
exit $?

#!/usr/bin/env bash
# Settings API tests.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

require_command curl

SETTINGS_PATH="/settings"

log_step "Fetch current settings"
api_get "$SETTINGS_PATH" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Fetch settings succeeds"
original_settings="$LAST_BODY"

update_settings=$(read_fixture '.settings.update')

log_step "Update settings"
api_put "$SETTINGS_PATH" "$update_settings" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Save settings returns 200"
assert_contains "true" "$LAST_BODY" "Save settings response is true"

log_step "Validate settings were saved"
api_get "$SETTINGS_PATH" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Fetch after update succeeds"
language=$(echo "$LAST_BODY" | jq -r '.language')
assert_equals "en" "$language" "Language persisted"
tray=$(echo "$LAST_BODY" | jq -r '.showInTray')
assert_equals "false" "$tray" "showInTray updated"

log_step "Restore original settings"
api_put "$SETTINGS_PATH" "$original_settings" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Restore settings succeeds"

print_summary
exit $?

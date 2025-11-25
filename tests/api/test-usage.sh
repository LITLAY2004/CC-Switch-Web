#!/usr/bin/env bash
# Usage script API tests (query + test endpoints).

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

require_command curl

BACKUP_FILE=$(mktemp)
backup_config "$BACKUP_FILE"
trap 'restore_config "$BACKUP_FILE" >/dev/null 2>&1; rm -f "$BACKUP_FILE"' EXIT

USAGE_BASE=$(read_fixture_raw '.usageScripts.baseUrl')
PROVIDER_ID=$(generate_id "usage-codex")

base_provider=$(read_fixture '.providers.codex.base' | jq --arg id "$PROVIDER_ID" --arg url "$USAGE_BASE" '.id=$id | .settingsConfig.auth.baseUrl=$url')
packy_code=$(read_fixture_raw '.usageScripts.packycode')

provider_with_usage=$(echo "$base_provider" | jq --arg code "$packy_code" --arg base "$USAGE_BASE" '
  .meta.usage_script = {
    enabled: true,
    language: "javascript",
    code: $code,
    timeout: 8,
    apiKey: "demo-key",
    baseUrl: $base
  }
')

log_step "Create provider with usage script"
api_post "/providers/codex" "$provider_with_usage" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Create provider with usage script"

log_step "Query usage using saved script"
api_post "/providers/codex/$PROVIDER_ID/usage" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Usage query returns 200"
query_success=$(echo "$LAST_BODY" | jq -r '.success')
assert_equals "true" "$query_success" "Usage query success flag"

log_step "Test usage scripts (PackyCode / 88code / Privnode)"
for name in packycode 88code privnode; do
  code=$(read_fixture_raw ".usageScripts.\"$name\"")
  payload=$(jq -n --arg script "$code" --arg base "$USAGE_BASE" '{scriptCode:$script, apiKey:"demo-key", baseUrl:$base, timeout:6}')
  api_post "/providers/gemini/${name}/usage/test" "$payload" >/dev/null
  assert_status_code 200 "$LAST_STATUS" "test_usage_script for $name"
  success=$(echo "$LAST_BODY" | jq -r '.success')
  assert_equals "true" "$success" "$name script success flag"
done

log_step "Error handling for invalid usage script"
bad_script='({ request: { url: "{{baseUrl}}", method: "INVALID" }, extractor: () => ({ used: 0 }) });'
bad_payload=$(jq -n --arg script "$bad_script" --arg base "$USAGE_BASE" '{scriptCode:$script, baseUrl:$base, timeout:5}')
api_post "/providers/gemini/invalid/usage/test" "$bad_payload" >/dev/null
assert_status_code 400 "$LAST_STATUS" "Invalid script returns 400"

print_summary
exit $?

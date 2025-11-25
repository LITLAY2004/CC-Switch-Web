#!/usr/bin/env bash
# MCP API tests.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

require_command curl

BACKUP_FILE=$(mktemp)
backup_config "$BACKUP_FILE"
trap 'restore_config "$BACKUP_FILE" >/dev/null 2>&1; rm -f "$BACKUP_FILE"' EXIT

SERVER_DATA=$(read_fixture '.mcp.server')
UPDATE_FIELDS=$(read_fixture '.mcp.update')

log_step "Create MCP server"
api_post "/mcp/servers" "$SERVER_DATA" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Create MCP server returns 200"
assert_contains "true" "$LAST_BODY" "Create MCP server response is true"

SERVER_ID=$(echo "$SERVER_DATA" | jq -r '.id')

log_step "List MCP servers"
api_get "/mcp/servers" >/dev/null
assert_status_code 200 "$LAST_STATUS" "List servers succeeds"
assert_contains "$SERVER_ID" "$LAST_BODY" "List contains new MCP server"

log_step "Update MCP server"
updated_payload=$(echo "$SERVER_DATA" | jq --argjson update "$UPDATE_FIELDS" '. + $update')
api_put "/mcp/servers/$SERVER_ID" "$updated_payload" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Update server succeeds"

log_step "Delete MCP server"
api_delete "/mcp/servers/$SERVER_ID" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Delete server succeeds"

api_get "/mcp/servers" >/dev/null
assert_status_code 200 "$LAST_STATUS" "List after delete succeeds"
assert_not_contains "$SERVER_ID" "$LAST_BODY" "Server removed from list"

print_summary
exit $?

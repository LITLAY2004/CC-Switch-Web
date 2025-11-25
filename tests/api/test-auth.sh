#!/usr/bin/env bash
# Authentication coverage for CC-Switch web API.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

require_command curl

log_step "Auth: request without credentials"
no_auth_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${API_BASE}/config/export")
assert_status_code 401 "$no_auth_status" "Unauthenticated requests are rejected"

log_step "Auth: request with wrong password"
bad_pwd_status=$(curl -s -o /dev/null -w "%{http_code}" -u "$USERNAME:wrong-password" -X POST "${API_BASE}/config/export")
assert_status_code 401 "$bad_pwd_status" "Wrong password is rejected"

log_step "Auth: request with correct credentials"
api_post "/config/export" >/dev/null
assert_status_code 200 "$LAST_STATUS" "Authorized request succeeds"

print_summary
exit $?

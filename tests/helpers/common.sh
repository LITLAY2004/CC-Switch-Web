#!/usr/bin/env bash
# Common helpers for CC-Switch web API bash tests.

set -o pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DATA_FILE="${TEST_DATA_FILE:-"$SCRIPT_DIR/test-data.json"}"

# Config (overridable via env)
SCHEME="${SCHEME:-http}"
HOST="${HOST:-${CC_SWITCH_HOST:-localhost}}"
PORT="${PORT:-${CC_SWITCH_PORT:-8080}}"
API_PREFIX="${API_PREFIX:-/api}"
API_BASE="${API_BASE:-$SCHEME://$HOST:$PORT$API_PREFIX}"
USERNAME="${USERNAME:-admin}"
PASSWORD_FILE="${PASSWORD_FILE:-$HOME/.cc-switch/web_password}"
PASSWORD="${PASSWORD:-$(cat "$PASSWORD_FILE" 2>/dev/null || true)}"
PASSWORD="${PASSWORD:-test}"
REQUEST_TIMEOUT="${REQUEST_TIMEOUT:-15}"
CURL_FLAGS=(${CURL_FLAGS:-})

# Colors (fallback to plain text if tput unavailable)
if command -v tput >/dev/null 2>&1; then
  GREEN="$(tput setaf 2)"
  RED="$(tput setaf 1)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  BOLD="$(tput bold)"
  NC="$(tput sgr0)"
else
  GREEN=""
  RED=""
  YELLOW=""
  BLUE=""
  BOLD=""
  NC=""
fi

# Stats
PASSED=0
FAILED=0
LAST_STATUS=0
LAST_BODY=""

require_command() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo >&2 "${RED}Missing required command: $cmd${NC}"
    exit 1
  fi
}

log_step() { echo -e "${BLUE}${BOLD}==>${NC} $*"; }
log_info() { echo -e "${BLUE}[*]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[x]${NC} $*"; }

pass() {
  echo -e "${GREEN}✓${NC} $*"
  ((PASSED++))
}

fail() {
  echo -e "${RED}✗${NC} $*"
  ((FAILED++))
}

# HTTP helpers
http_request() {
  local method=$1
  local path=$2
  local body=${3:-}

  local url="${API_BASE}${path}"
  local tmp
  tmp=$(mktemp)

  local args=(-sS -u "$USERNAME:$PASSWORD" -o "$tmp" -w "%{http_code}" -X "$method" "${CURL_FLAGS[@]}" --connect-timeout "$REQUEST_TIMEOUT" --max-time "$REQUEST_TIMEOUT")
  if [ -n "$body" ]; then
    args+=(-H "Content-Type: application/json" -d "$body")
  fi

  LAST_STATUS=$(curl "${args[@]}" "$url")
  LAST_BODY=$(cat "$tmp")
  rm -f "$tmp"
}

api_get() { http_request GET "$1"; echo "$LAST_BODY"; }
api_post() { http_request POST "$1" "${2:-}"; echo "$LAST_BODY"; }
api_put() { http_request PUT "$1" "${2:-}"; echo "$LAST_BODY"; }
api_delete() { http_request DELETE "$1"; echo "$LAST_BODY"; }

assert_status_code() {
  local expected=$1
  local actual=${2:-$LAST_STATUS}
  local context=${3:-}

  if [ "$actual" = "$expected" ]; then
    pass "Status $expected ${context:+($context)}"
  else
    fail "Expected status $expected, got $actual ${context:+($context)}"
  fi
}

assert_equals() {
  local expected=$1
  local actual=$2
  local context=${3:-}
  if [ "$expected" = "$actual" ]; then
    pass "$context"
  else
    fail "$context (expected '$expected', got '$actual')"
  fi
}

assert_contains() {
  local needle=$1
  local haystack=$2
  local context=${3:-}
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$context"
  else
    fail "$context (missing '$needle')"
  fi
}

assert_not_contains() {
  local needle=$1
  local haystack=$2
  local context=${3:-}
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "$context (unexpected '$needle')"
  else
    pass "$context"
  fi
}

print_summary() {
  echo ""
  echo "=================================="
  echo -e "Total: $((PASSED + FAILED))"
  echo -e "${GREEN}Passed: $PASSED${NC}"
  echo -e "${RED}Failed: $FAILED${NC}"
  echo "=================================="

  [ $FAILED -eq 0 ]
}

# Test data helpers (require jq)
require_command jq

read_fixture() {
  local jq_filter=$1
  jq -c "$jq_filter" "$TEST_DATA_FILE"
}

read_fixture_raw() {
  local jq_filter=$1
  jq -r "$jq_filter" "$TEST_DATA_FILE"
}

generate_id() {
  local prefix=$1
  printf "%s-%s-%s" "$prefix" "$(date +%s)" "$RANDOM"
}

# Config backup/restore to avoid polluting real data
backup_config() {
  local dest=$1
  http_request POST "/config/export"
  if [ "$LAST_STATUS" != "200" ]; then
    log_warn "Failed to export config (status $LAST_STATUS); continuing without backup"
    return 1
  fi
  echo "$LAST_BODY" >"$dest"
  log_info "Exported config to $dest"
}

restore_config() {
  local src=$1
  [ -f "$src" ] || return 0
  local payload
  payload=$(cat "$src")
  http_request POST "/config/import" "$payload"
  if [ "$LAST_STATUS" != "200" ]; then
    log_warn "Config restore from $src failed (status $LAST_STATUS)"
    return 1
  fi
  log_info "Config restored from $src (backup id: $(echo "$LAST_BODY" | jq -r '.backupId? // .backup_id? // "n/a"'))"
}

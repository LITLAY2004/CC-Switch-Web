#!/usr/bin/env bash
# Run all bash-based CC-Switch API/integration tests.

set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TEST_SCRIPTS=(
  "api/test-auth.sh"
  "api/test-providers.sh"
  "api/test-usage.sh"
  "api/test-settings.sh"
  "api/test-mcp.sh"
  "integration/test-full-workflow.sh"
  "integration/test-persistence.sh"
)

if [ "$#" -gt 0 ]; then
  TEST_SCRIPTS=("$@")
fi

OVERALL_FAILED=0
TOTAL=0
FAILED=0

for script in "${TEST_SCRIPTS[@]}"; do
  ((TOTAL++))
  echo ""
  echo "=================================="
  echo "Running $script"
  echo "=================================="
  if bash "$ROOT_DIR/$script"; then
    echo "-> $script passed"
  else
    echo "-> $script failed"
    OVERALL_FAILED=1
    ((FAILED++))
  fi
done

PASSED=$((TOTAL - FAILED))
echo ""
echo "=================================="
echo "Bash test report"
echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED"
echo "=================================="

exit $OVERALL_FAILED

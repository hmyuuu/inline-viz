#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_FAIL=0

echo "=============================="
echo "  inline-viz test suite"
echo "=============================="
echo ""

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  echo "--- $(basename "$test_file") ---"
  if bash "$test_file"; then
    echo "  → Suite PASSED"
  else
    echo "  → Suite FAILED"
    ((TOTAL_FAIL++))
  fi
  echo ""
done

if [[ $TOTAL_FAIL -eq 0 ]]; then
  echo "All test suites passed."
  exit 0
else
  echo "$TOTAL_FAIL test suite(s) failed."
  exit 1
fi

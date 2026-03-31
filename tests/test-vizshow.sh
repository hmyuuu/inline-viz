#!/usr/bin/env bash
# tests/test-vizshow.sh — Unit tests for vizshow
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIZSHOW="$SCRIPT_DIR/../scripts/vizshow"
PASS=0
FAIL=0

pass() { ((PASS++)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { ((FAIL++)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

# Create a tiny valid PNG for tests (1x1 red pixel)
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
TEST_IMG="$TMPDIR_TEST/test.png"
# Minimal valid PNG (1x1 white pixel)
printf '\x89PNG\r\n\x1a\n' > "$TEST_IMG"
printf '\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde' >> "$TEST_IMG"
printf '\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N' >> "$TEST_IMG"
printf '\x00\x00\x00\x00IEND\xaeB`\x82' >> "$TEST_IMG"

echo "=== vizshow tests ==="

# --- Test 1: Missing file exits 1 with "not found" ---
out=$("$VIZSHOW" "/no/such/file.png" 2>&1 || true)
code=$("$VIZSHOW" "/no/such/file.png" 2>&1; echo "EXIT:$?" ) || true
exit_code="${code##*EXIT:}"
if echo "$out" | grep -qi "not found"; then
  pass "missing file prints 'not found'"
else
  fail "missing file should print 'not found', got: $out"
fi
if [[ "$exit_code" == "1" ]]; then
  pass "missing file exits 1"
else
  fail "missing file should exit 1, got: $exit_code"
fi

# --- Test 2: --protocol file prints tag and exits 2 ---
out=$("$VIZSHOW" "$TEST_IMG" --protocol file 2>&1 || true)
code=$("$VIZSHOW" "$TEST_IMG" --protocol file 2>&1; echo "EXIT:$?") || true
exit_code="${code##*EXIT:}"
abs_path="$(cd "$(dirname "$TEST_IMG")" && pwd)/$(basename "$TEST_IMG")"
if echo "$out" | grep -q "\[vizshow:.*via file\]"; then
  pass "--protocol file prints [vizshow: ... via file]"
else
  fail "--protocol file should print tag, got: $out"
fi
if [[ "$exit_code" == "2" ]]; then
  pass "--protocol file exits 2"
else
  fail "--protocol file should exit 2, got: $exit_code"
fi

# --- Test 3: --quiet suppresses the tag line ---
out=$("$VIZSHOW" "$TEST_IMG" --protocol file --quiet 2>&1 || true)
if echo "$out" | grep -q "\[vizshow:"; then
  fail "--quiet should suppress [vizshow:] tag line"
else
  pass "--quiet suppresses tag line"
fi

# --- Test 4: default output includes [vizshow: ... via <protocol>] ---
out=$(TERM_PROGRAM="" KITTY_PID="" GHOSTTY_RESOURCES_DIR="" WEZTERM_EXECUTABLE="" \
  "$VIZSHOW" "$TEST_IMG" --protocol file 2>&1 || true)
if echo "$out" | grep -qE '\[vizshow: .+ via .+\]'; then
  pass "output includes [vizshow: <path> via <protocol>] tag"
else
  fail "output should include vizshow tag, got: $out"
fi

# --- Test 5: absolute path in tag ---
out=$("$VIZSHOW" "$TEST_IMG" --protocol file 2>&1 || true)
if echo "$out" | grep -q "\[vizshow: /"; then
  pass "tag contains absolute path"
else
  fail "tag should contain absolute path, got: $out"
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

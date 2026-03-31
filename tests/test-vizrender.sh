#!/usr/bin/env bash
# tests/test-vizrender.sh — Unit tests for vizrender
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIZRENDER="$SCRIPT_DIR/../scripts/vizrender"
PASS=0
FAIL=0

pass() { ((PASS++)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { ((FAIL++)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

# Create temp dir and a minimal .typ file for tests
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
TEST_TYP="$TMPDIR_TEST/hello.typ"
cat > "$TEST_TYP" <<'TYPST'
#set page(width: 200pt, height: 100pt, margin: 10pt)
Hello, vizrender!
TYPST

echo "=== vizrender tests ==="

# --- Test 1: Compile .typ to SVG (--no-display), verify SVG exists and structured output ---
out=$("$VIZRENDER" "$TEST_TYP" --no-display 2>&1 || true)
svg_file="${TMPDIR_TEST}/hello.svg"
if [[ -f "$svg_file" ]]; then
  pass "compile to SVG: file exists"
else
  fail "compile to SVG: $svg_file not found"
fi
if echo "$out" | grep -q '\[vizrender: source='; then
  pass "compile to SVG: output has source= tag"
else
  fail "compile to SVG: output missing source= tag, got: $out"
fi
if echo "$out" | grep -q '\[vizrender: rendered='; then
  pass "compile to SVG: output has rendered= tag"
else
  fail "compile to SVG: output missing rendered= tag, got: $out"
fi

# --- Test 2: Compile to PNG (--format png --no-display), verify PNG exists ---
png_out=$("$VIZRENDER" "$TEST_TYP" --format png --no-display 2>&1 || true)
png_file="${TMPDIR_TEST}/hello.png"
if [[ -f "$png_file" ]]; then
  pass "compile to PNG: file exists"
else
  fail "compile to PNG: $png_file not found"
fi

# --- Test 3: Compile to PDF (--format pdf --no-display), verify PDF exists ---
pdf_out=$("$VIZRENDER" "$TEST_TYP" --format pdf --no-display 2>&1 || true)
pdf_file="${TMPDIR_TEST}/hello.pdf"
if [[ -f "$pdf_file" ]]; then
  pass "compile to PDF: file exists"
else
  fail "compile to PDF: $pdf_file not found"
fi

# --- Test 4: Custom output path (--output custom.svg --no-display) ---
custom_out_path="$TMPDIR_TEST/custom-output.svg"
custom_out=$("$VIZRENDER" "$TEST_TYP" --output "$custom_out_path" --no-display 2>&1 || true)
if [[ -f "$custom_out_path" ]]; then
  pass "custom output path: file exists"
else
  fail "custom output path: $custom_out_path not found"
fi
if echo "$custom_out" | grep -q "custom-output.svg"; then
  pass "custom output path: rendered= references custom path"
else
  fail "custom output path: output should reference custom path, got: $custom_out"
fi

# --- Test 5: Missing input file prints "not found" error ---
missing_out=$("$VIZRENDER" "/no/such/file.typ" --no-display 2>&1 || true)
if echo "$missing_out" | grep -qi "not found"; then
  pass "missing input file prints 'not found'"
else
  fail "missing input file should print 'not found', got: $missing_out"
fi

# --- Test 6: Display mode produces displayed= tag in output ---
# Use --protocol file on vizshow (via environment) to avoid needing a real terminal
display_out=$("$VIZRENDER" "$TEST_TYP" 2>&1 || true)
if echo "$display_out" | grep -q '\[vizrender: displayed='; then
  pass "display mode: output has displayed= tag"
else
  fail "display mode: output missing displayed= tag, got: $display_out"
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

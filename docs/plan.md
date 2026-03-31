# Inline Viz Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that renders typst diagrams inline in the terminal and supports agent readback for iterative refinement.

**Architecture:** Three-layer stack — `vizshow` (terminal display), `vizrender` (typst compile + display), and typst template files (domain-specific viz libraries). All layers are bash scripts + typst files living in a Claude Code plugin under `plugins/inline-viz/`.

**Tech Stack:** Bash, typst 0.14.2, rsvg-convert (SVG→PNG), iTerm2/Kitty graphics protocols, CeTZ (typst drawing), pixel-family, qec-thrust, typdd (typst packages)

---

## File Map

```
plugins/inline-viz/
├── .claude-plugin/
│   └── plugin.json                # plugin manifest
├── skills/
│   └── inline-viz/
│       ├── SKILL.md               # skill document for agents
│       └── reference.md           # template API quick-reference
├── scripts/
│   ├── vizshow                    # Layer 1: terminal image display
│   └── vizrender                  # Layer 2: typst compile + display
├── templates/
│   ├── pixel-art.typ              # pixel-family wrapper (smoke test)
│   ├── qec.typ                    # QEC code visualization
│   ├── quantum-control.typ        # circuit + Bloch + pulses
│   ├── tensor-network.typ         # TN drawing
│   ├── bdd.typ                    # BDD visualization
│   ├── feynman.typ                # Feynman diagrams
│   ├── plot.typ                   # generic data plotting
│   └── paper-layout.typ           # multi-panel figures
└── tests/
    ├── test-vizshow.sh            # vizshow integration tests
    ├── test-vizrender.sh          # vizrender integration tests
    ├── test-pixel-art.typ         # smoke test typst file
    └── run-tests.sh               # test runner
```

---

### Task 1: Plugin Scaffold + Manifest

**Files:**
- Create: `plugins/inline-viz/.claude-plugin/plugin.json`

- [ ] **Step 1: Create plugin directory structure**

```bash
cd /Users/hmyuuu/workspace/skills
mkdir -p plugins/inline-viz/.claude-plugin
mkdir -p plugins/inline-viz/skills/inline-viz
mkdir -p plugins/inline-viz/scripts
mkdir -p plugins/inline-viz/templates
mkdir -p plugins/inline-viz/tests
```

- [ ] **Step 2: Write plugin.json**

Create `plugins/inline-viz/.claude-plugin/plugin.json`:

```json
{
  "name": "inline-viz",
  "description": "Inline terminal visualization for scientific diagrams via typst",
  "version": "0.1.0",
  "author": { "name": "hmyuuu" },
  "keywords": ["visualization", "typst", "terminal", "inline-image", "quantum", "tensor-network", "plotting"]
}
```

- [ ] **Step 3: Add to marketplace.json**

In `.claude-plugin/marketplace.json`, add to the `plugins` array:

```json
{
  "name": "inline-viz",
  "description": "Inline terminal visualization — render typst diagrams (quantum circuits, tensor networks, QEC codes, BDDs, plots) directly in iTerm2/Kitty/Ghostty",
  "version": "0.1.0",
  "author": { "name": "hmyuuu" },
  "source": "./plugins/inline-viz",
  "category": "visualization"
}
```

- [ ] **Step 4: Commit**

```bash
git add plugins/inline-viz/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(inline-viz): scaffold plugin and add to marketplace"
```

---

### Task 2: `vizshow` — Terminal Display Script (Layer 1)

**Files:**
- Create: `plugins/inline-viz/scripts/vizshow`
- Create: `plugins/inline-viz/tests/test-vizshow.sh`

- [ ] **Step 1: Write vizshow test script**

Create `plugins/inline-viz/tests/test-vizshow.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIZSHOW="$SCRIPT_DIR/../scripts/vizshow"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc (expected=$expected, actual=$actual)"
    ((FAIL++))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc (expected to contain '$needle')"
    ((FAIL++))
  fi
}

echo "=== vizshow tests ==="

# Test: missing file exits 1
echo "Test: missing file"
output=$("$VIZSHOW" /nonexistent/file.png 2>&1 || true)
assert_contains "error message for missing file" "not found" "$output"

# Test: creates a test PNG and displays with --protocol=file (always works)
echo "Test: fallback to file protocol"
TMPDIR_TEST=$(mktemp -d)
# Create a minimal 1x1 red PNG (67 bytes)
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' > "$TMPDIR_TEST/test.png"
output=$("$VIZSHOW" "$TMPDIR_TEST/test.png" --protocol file 2>&1)
assert_contains "prints file path" "[vizshow:" "$output"
assert_contains "shows protocol used" "file]" "$output"
exit_code=$("$VIZSHOW" "$TMPDIR_TEST/test.png" --protocol file > /dev/null 2>&1; echo $?)
assert_eq "fallback exit code is 2" "2" "$exit_code"

# Test: --quiet suppresses path output
echo "Test: --quiet flag"
output=$("$VIZSHOW" "$TMPDIR_TEST/test.png" --protocol file --quiet 2>&1)
if [[ "$output" != *"[vizshow:"* ]]; then
  echo "  PASS: --quiet suppresses vizshow tag"
  ((PASS++))
else
  echo "  FAIL: --quiet did not suppress vizshow tag"
  ((FAIL++))
fi

rm -rf "$TMPDIR_TEST"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
chmod +x plugins/inline-viz/tests/test-vizshow.sh
bash plugins/inline-viz/tests/test-vizshow.sh
```

Expected: FAIL — `vizshow` script does not exist yet.

- [ ] **Step 3: Write vizshow**

Create `plugins/inline-viz/scripts/vizshow`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# vizshow — display an image inline in the terminal
# Usage: vizshow <image-file> [--width N] [--height N] [--protocol P] [--fallback F] [--quiet]

usage() {
  echo "Usage: vizshow <image-file> [OPTIONS]"
  echo "Options:"
  echo "  --width N        Max width in terminal columns (default: auto)"
  echo "  --height N       Max height in terminal rows (default: auto)"
  echo "  --protocol P     Force: iterm2|kitty|timg|chafa|imgcat|icat|file"
  echo "  --fallback F     No protocol available: save|ascii (default: save)"
  echo "  --quiet          Suppress file path output"
  exit 1
}

# Parse arguments
IMAGE=""
WIDTH=""
HEIGHT=""
PROTOCOL=""
FALLBACK="save"
QUIET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --width)   WIDTH="$2"; shift 2 ;;
    --height)  HEIGHT="$2"; shift 2 ;;
    --protocol) PROTOCOL="$2"; shift 2 ;;
    --fallback) FALLBACK="$2"; shift 2 ;;
    --quiet)   QUIET=true; shift ;;
    --help|-h) usage ;;
    -*)        echo "Unknown option: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$IMAGE" ]]; then
        IMAGE="$1"; shift
      else
        echo "Unexpected argument: $1" >&2; exit 1
      fi
      ;;
  esac
done

if [[ -z "$IMAGE" ]]; then
  echo "Error: no image file specified" >&2
  usage
fi

if [[ ! -f "$IMAGE" ]]; then
  echo "Error: file not found: $IMAGE" >&2
  exit 1
fi

IMAGE="$(cd "$(dirname "$IMAGE")" && pwd)/$(basename "$IMAGE")"

# Auto-detect terminal width
if [[ -z "$WIDTH" ]]; then
  WIDTH="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
fi

# --- Protocol implementations ---

display_iterm2() {
  local file="$1" w="$2"
  local data
  data=$(base64 < "$file")
  printf '\033]1337;File=inline=1;width=%s:' "$w"
  printf '%s' "$data"
  printf '\a'
  echo ""
}

display_kitty() {
  local file="$1"
  # Kitty graphics protocol: chunked base64 PNG transfer
  local data
  data=$(base64 < "$file")
  local len=${#data}
  local chunk_size=4096
  local offset=0
  while [[ $offset -lt $len ]]; do
    local chunk="${data:$offset:$chunk_size}"
    offset=$((offset + chunk_size))
    if [[ $offset -ge $len ]]; then
      # Last chunk: m=0
      printf '\033_Ga=T,f=100,m=0;%s\033\\' "$chunk"
    else
      # More chunks: m=1
      printf '\033_Ga=T,f=100,m=1;%s\033\\' "$chunk"
    fi
  done
  echo ""
}

display_tool() {
  local tool="$1" file="$2" w="$3"
  case "$tool" in
    timg)   timg -W "${w}" "$file" ;;
    chafa)  chafa -s "${w}x" "$file" ;;
    imgcat) imgcat -W "${w}" "$file" ;;
    icat)   kitten icat --place "${w}x0@0x0" "$file" ;;
  esac
}

display_fallback() {
  local file="$1"
  if [[ "$FALLBACK" == "ascii" ]] && command -v chafa &>/dev/null; then
    chafa --format=symbols -s "${WIDTH}x" "$file"
  fi
  # For "save" fallback, we just print the path (handled below)
}

# --- Protocol detection ---

detect_and_display() {
  local file="$1"

  # Force protocol if specified
  if [[ -n "$PROTOCOL" ]]; then
    case "$PROTOCOL" in
      iterm2) display_iterm2 "$file" "$WIDTH"; return 0 ;;
      kitty)  display_kitty "$file"; return 0 ;;
      timg|chafa|imgcat|icat)
        if command -v "${PROTOCOL}" &>/dev/null || [[ "$PROTOCOL" == "icat" && -n "$(command -v kitten 2>/dev/null)" ]]; then
          display_tool "$PROTOCOL" "$file" "$WIDTH"; return 0
        else
          echo "Error: $PROTOCOL not found" >&2; exit 1
        fi
        ;;
      file) return 2 ;;
      *) echo "Error: unknown protocol: $PROTOCOL" >&2; exit 1 ;;
    esac
  fi

  # Auto-detect
  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    display_iterm2 "$file" "$WIDTH"
    PROTOCOL="iterm2"; return 0
  fi

  if [[ -n "${KITTY_PID:-}" ]]; then
    display_kitty "$file"
    PROTOCOL="kitty"; return 0
  fi

  if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
    display_kitty "$file"
    PROTOCOL="kitty"; return 0
  fi

  if [[ -n "${WEZTERM_EXECUTABLE:-}" ]]; then
    display_iterm2 "$file" "$WIDTH"
    PROTOCOL="iterm2"; return 0
  fi

  # Tool fallbacks
  for tool in timg chafa imgcat; do
    if command -v "$tool" &>/dev/null; then
      display_tool "$tool" "$file" "$WIDTH"
      PROTOCOL="$tool"; return 0
    fi
  done

  if command -v kitten &>/dev/null; then
    display_tool "icat" "$file" "$WIDTH"
    PROTOCOL="icat"; return 0
  fi

  # No protocol found
  display_fallback "$file"
  PROTOCOL="file"
  return 2
}

# --- Main ---

exit_code=0
detect_and_display "$IMAGE" || exit_code=$?

if [[ "$QUIET" != true ]]; then
  echo "[vizshow: $IMAGE via ${PROTOCOL}]"
fi

exit "$exit_code"
```

- [ ] **Step 4: Make executable and run tests**

```bash
chmod +x plugins/inline-viz/scripts/vizshow
bash plugins/inline-viz/tests/test-vizshow.sh
```

Expected: All tests PASS.

- [ ] **Step 5: Manual smoke test — display a real image**

```bash
# Create a simple test PNG via typst
echo '#set page(width: 100pt, height: 50pt, margin: 5pt)
#align(center + horizon, text(20pt, fill: blue)[Hello!])' > /tmp/test-vizshow.typ
typst compile /tmp/test-vizshow.typ /tmp/test-vizshow.png
plugins/inline-viz/scripts/vizshow /tmp/test-vizshow.png
```

Expected: "Hello!" appears inline in your terminal. The `[vizshow: ... via iterm2]` line prints below.

- [ ] **Step 6: Commit**

```bash
git add plugins/inline-viz/scripts/vizshow plugins/inline-viz/tests/test-vizshow.sh
git commit -m "feat(inline-viz): add vizshow terminal display script"
```

---

### Task 3: `vizrender` — Typst Render Engine (Layer 2)

**Files:**
- Create: `plugins/inline-viz/scripts/vizrender`
- Create: `plugins/inline-viz/tests/test-vizrender.sh`

- [ ] **Step 1: Write vizrender test script**

Create `plugins/inline-viz/tests/test-vizrender.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIZRENDER="$SCRIPT_DIR/../scripts/vizrender"

PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc (expected to contain '$needle')"
    ((FAIL++))
  fi
}

assert_file_exists() {
  local desc="$1" file="$2"
  if [[ -f "$file" ]]; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc (file not found: $file)"
    ((FAIL++))
  fi
}

echo "=== vizrender tests ==="

TMPDIR_TEST=$(mktemp -d)

# Test: compile .typ to SVG
echo "Test: compile to SVG"
cat > "$TMPDIR_TEST/hello.typ" << 'TYPST'
#set page(width: 100pt, height: 50pt, margin: 5pt)
#align(center + horizon, text(20pt)[Test])
TYPST

output=$("$VIZRENDER" "$TMPDIR_TEST/hello.typ" --no-display 2>&1)
assert_file_exists "SVG created" "$TMPDIR_TEST/hello.svg"
assert_contains "output shows source" "[vizrender: source=" "$output"
assert_contains "output shows rendered" "[vizrender: rendered=" "$output"

# Test: compile to PNG
echo "Test: compile to PNG"
output=$("$VIZRENDER" "$TMPDIR_TEST/hello.typ" --format png --no-display 2>&1)
assert_file_exists "PNG created" "$TMPDIR_TEST/hello.png"

# Test: compile to PDF
echo "Test: compile to PDF"
output=$("$VIZRENDER" "$TMPDIR_TEST/hello.typ" --format pdf --no-display 2>&1)
assert_file_exists "PDF created" "$TMPDIR_TEST/hello.pdf"

# Test: custom output path
echo "Test: custom output path"
output=$("$VIZRENDER" "$TMPDIR_TEST/hello.typ" --output "$TMPDIR_TEST/custom.svg" --no-display 2>&1)
assert_file_exists "custom output path" "$TMPDIR_TEST/custom.svg"

# Test: missing typst file exits with error
echo "Test: missing input file"
output=$("$VIZRENDER" "$TMPDIR_TEST/nonexistent.typ" --no-display 2>&1 || true)
assert_contains "error for missing file" "not found" "$output"

# Test: --display produces PNG for terminal + structured output
echo "Test: display mode produces PNG"
output=$("$VIZRENDER" "$TMPDIR_TEST/hello.typ" --display 2>&1)
assert_contains "displayed path" "[vizrender: displayed=" "$output"

rm -rf "$TMPDIR_TEST"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x plugins/inline-viz/tests/test-vizrender.sh
bash plugins/inline-viz/tests/test-vizrender.sh
```

Expected: FAIL — `vizrender` does not exist yet.

- [ ] **Step 3: Write vizrender**

Create `plugins/inline-viz/scripts/vizrender`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# vizrender — compile typst to SVG/PNG/PDF and optionally display inline
# Usage: vizrender <input.typ> [OPTIONS]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIZSHOW="$SCRIPT_DIR/vizshow"

usage() {
  echo "Usage: vizrender <input.typ> [OPTIONS]"
  echo "Options:"
  echo "  --format F       Output: svg|png|pdf (default: svg)"
  echo "  --display        Display inline via vizshow (default)"
  echo "  --no-display     Render only, don't display"
  echo "  --output PATH    Custom output path"
  echo "  --width N        Pass --width to vizshow"
  echo "  --open           Open in system viewer instead of terminal"
  exit 1
}

# Parse arguments
INPUT=""
FORMAT="svg"
DISPLAY=true
OUTPUT=""
WIDTH=""
OPEN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)     FORMAT="$2"; shift 2 ;;
    --display)    DISPLAY=true; shift ;;
    --no-display) DISPLAY=false; shift ;;
    --output)     OUTPUT="$2"; shift 2 ;;
    --width)      WIDTH="$2"; shift 2 ;;
    --open)       OPEN=true; shift ;;
    --help|-h)    usage ;;
    -*)           echo "Unknown option: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$INPUT" ]]; then
        INPUT="$1"; shift
      else
        echo "Unexpected argument: $1" >&2; exit 1
      fi
      ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "Error: no input file specified" >&2
  usage
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: file not found: $INPUT" >&2
  exit 1
fi

INPUT="$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")"
INPUT_DIR="$(dirname "$INPUT")"
INPUT_BASE="$(basename "$INPUT" .typ)"

# Resolve template-dir for typst --input
TEMPLATE_DIR="${SCRIPT_DIR}/../templates"
if [[ -d "$TEMPLATE_DIR" ]]; then
  TEMPLATE_DIR="$(cd "$TEMPLATE_DIR" && pwd)"
fi

# Determine output path
if [[ -n "$OUTPUT" ]]; then
  RENDERED="$OUTPUT"
else
  RENDERED="${INPUT_DIR}/${INPUT_BASE}.${FORMAT}"
fi

# --- Compile ---

if ! typst compile \
  --input template-dir="$TEMPLATE_DIR" \
  "$INPUT" "$RENDERED" 2>&1; then
  echo "Error: typst compile failed" >&2
  exit 1
fi

echo "[vizrender: ${INPUT} → ${RENDERED}]"
echo "[vizrender: source=${INPUT}]"
echo "[vizrender: rendered=${RENDERED}]"

# --- Display ---

if [[ "$OPEN" == true ]]; then
  open "$RENDERED"
  exit 0
fi

if [[ "$DISPLAY" == true ]]; then
  # For terminal display, we need a raster image (PNG)
  DISPLAY_FILE="$RENDERED"

  if [[ "$FORMAT" == "svg" ]]; then
    # Convert SVG → PNG for terminal display
    DISPLAY_FILE="${INPUT_DIR}/${INPUT_BASE}.png"

    if command -v rsvg-convert &>/dev/null; then
      rsvg-convert "$RENDERED" -o "$DISPLAY_FILE"
    elif command -v magick &>/dev/null; then
      magick convert "$RENDERED" "$DISPLAY_FILE"
    else
      # Fallback: compile directly to PNG
      typst compile "$INPUT" "$DISPLAY_FILE"
    fi
  elif [[ "$FORMAT" == "pdf" ]]; then
    # Convert PDF → PNG for terminal display
    DISPLAY_FILE="${INPUT_DIR}/${INPUT_BASE}.png"
    if command -v rsvg-convert &>/dev/null; then
      # rsvg can't do PDF; compile directly to PNG
      typst compile "$INPUT" "$DISPLAY_FILE"
    else
      typst compile "$INPUT" "$DISPLAY_FILE"
    fi
  fi

  VIZSHOW_ARGS=("$DISPLAY_FILE")
  if [[ -n "$WIDTH" ]]; then
    VIZSHOW_ARGS+=(--width "$WIDTH")
  fi

  "$VIZSHOW" "${VIZSHOW_ARGS[@]}" || true
  echo "[vizrender: displayed=${DISPLAY_FILE}]"
fi
```

- [ ] **Step 4: Make executable and run tests**

```bash
chmod +x plugins/inline-viz/scripts/vizrender
bash plugins/inline-viz/tests/test-vizrender.sh
```

Expected: All tests PASS.

- [ ] **Step 5: Manual end-to-end smoke test**

```bash
echo '#set page(width: 200pt, height: 100pt, margin: 10pt)
#align(center + horizon)[
  #text(24pt, fill: purple)[vizrender works!]
]' > /tmp/test-vizrender.typ

plugins/inline-viz/scripts/vizrender /tmp/test-vizrender.typ
```

Expected: Purple "vizrender works!" text appears inline. Structured output prints source/rendered/displayed paths.

- [ ] **Step 6: Commit**

```bash
git add plugins/inline-viz/scripts/vizrender plugins/inline-viz/tests/test-vizrender.sh
git commit -m "feat(inline-viz): add vizrender typst compile + display engine"
```

---

### Task 4: Test Runner + Integration Tests

**Files:**
- Create: `plugins/inline-viz/tests/run-tests.sh`

- [ ] **Step 1: Write test runner**

Create `plugins/inline-viz/tests/run-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
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
```

- [ ] **Step 2: Run full test suite**

```bash
chmod +x plugins/inline-viz/tests/run-tests.sh
bash plugins/inline-viz/tests/run-tests.sh
```

Expected: Both test-vizshow.sh and test-vizrender.sh pass.

- [ ] **Step 3: Commit**

```bash
git add plugins/inline-viz/tests/run-tests.sh
git commit -m "feat(inline-viz): add test runner"
```

---

### Task 5: Pixel Art Template — Smoke Test (Layer 3)

**Files:**
- Create: `plugins/inline-viz/templates/pixel-art.typ`
- Create: `plugins/inline-viz/tests/test-pixel-art.typ`

- [ ] **Step 1: Write pixel-art template**

Create `plugins/inline-viz/templates/pixel-art.typ`:

```typst
#import "@preview/pixel-family:0.1.0": *

/// Compose pixel art characters in a horizontal scene.
/// - characters: array of content (e.g., alice(size: 2cm), bob(size: 2cm))
/// - spacing: horizontal gap between characters (default: 1cm)
/// - caption: optional text below the scene
#let scene(characters, spacing: 1cm, caption: none) = {
  set page(width: auto, height: auto, margin: 12pt)
  align(center,
    stack(dir: ltr, spacing: spacing, ..characters)
  )
  if caption != none {
    v(8pt)
    align(center, text(11pt, caption))
  }
}
```

- [ ] **Step 2: Write smoke test typst file**

Create `plugins/inline-viz/tests/test-pixel-art.typ`:

```typst
#import "@preview/pixel-family:0.1.0": *

#set page(width: auto, height: auto, margin: 12pt)

#align(center)[
  #stack(dir: ltr, spacing: 1cm,
    alice(size: 2cm),
    bob(size: 2cm),
  )
  #v(8pt)
  #text(11pt)[Alice and Bob]
]
```

- [ ] **Step 3: Compile and display the smoke test**

```bash
plugins/inline-viz/scripts/vizrender plugins/inline-viz/tests/test-pixel-art.typ
```

Expected: Alice and Bob pixel art characters appear inline in terminal. SVG and PNG files created alongside the .typ file.

- [ ] **Step 4: Verify agent readback — read the SVG**

```bash
head -20 plugins/inline-viz/tests/test-pixel-art.svg
```

Expected: SVG XML output visible — agent can grep this for structure.

- [ ] **Step 5: Commit**

```bash
git add plugins/inline-viz/templates/pixel-art.typ plugins/inline-viz/tests/test-pixel-art.typ
git commit -m "feat(inline-viz): add pixel-art template and smoke test"
```

---

### Task 6: SKILL.md — Skill Document

**Files:**
- Create: `plugins/inline-viz/skills/inline-viz/SKILL.md`
- Create: `plugins/inline-viz/skills/inline-viz/reference.md`

- [ ] **Step 1: Write SKILL.md**

Create `plugins/inline-viz/skills/inline-viz/SKILL.md`:

```markdown
---
name: inline-viz
description: >
  Use when the user asks to visualize, plot, diagram, or render
  any scientific figure inline in the terminal. Supports quantum
  circuits, tensor networks, QEC codes, BDDs, Feynman diagrams,
  Bloch spheres, data plots, paper layouts, and pixel art.
---

# Inline Visualization

Render typst diagrams inline in the terminal. Agent can read back output for iterative refinement.

## Quick Start

```bash
# 1. Write a .typ file
cat > /tmp/hello.typ << 'EOF'
#import "@preview/pixel-family:0.1.0": *
#set page(width: auto, height: auto, margin: 12pt)
#alice(size: 3cm)
EOF

# 2. Render and display
${CLAUDE_PLUGIN_ROOT}/scripts/vizrender /tmp/hello.typ
```

Output includes file paths for readback:
```
[vizrender: source=/tmp/hello.typ]
[vizrender: rendered=/tmp/hello.svg]
[vizrender: displayed=/tmp/hello.png]
```

## Core Workflow

1. **Write** a `.typ` file (using a template or from scratch)
2. **Render**: `${CLAUDE_PLUGIN_ROOT}/scripts/vizrender input.typ`
3. **Parse output** for `source=`, `rendered=`, `displayed=` paths
4. **Readback** (choose based on need):
   - Read `.typ` source → structural understanding, parameter modification
   - Grep `.svg` XML → find specific nodes, labels, positions
   - Read `.png` via Read tool → visual verification (uses vision tokens)

## Templates

Import via `sys.inputs.template-dir` (automatically set by vizrender):

| Template | Import | Use For |
|----------|--------|---------|
| pixel-art | `#import sys.inputs.template-dir + "/pixel-art.typ": *` | Pixel art character scenes |
| qec | `#import sys.inputs.template-dir + "/qec.typ": *` | QEC surface/toric/color codes |
| quantum-control | `#import sys.inputs.template-dir + "/quantum-control.typ": *` | Circuit + Bloch + pulse panels |
| tensor-network | `#import sys.inputs.template-dir + "/tensor-network.typ": *` | MPS, honeycomb, MERA, iPEPS |
| bdd | `#import sys.inputs.template-dir + "/bdd.typ": *` | Binary decision diagrams |
| feynman | `#import sys.inputs.template-dir + "/feynman.typ": *` | Feynman diagrams |
| plot | `#import sys.inputs.template-dir + "/plot.typ": *` | Data plots (line, scatter, heatmap) |
| paper-layout | `#import sys.inputs.template-dir + "/paper-layout.typ": *` | Multi-panel figure arrangement |

Writing `.typ` from scratch (without templates) works for simple or custom diagrams. Templates add convenience functions for common patterns.

## Readback Decision Guide

- **Modifying parameters** → read `.typ` source, change values, re-render
- **Checking structure** → grep `.svg` for element names, positions, labels
- **Verifying appearance** → read `.png` with Read tool (vision), costs tokens
- **Iterating on layout** → source readback first, vision for final check

## Iteration Pattern

```
User: "move figure B to the left"
Agent: [reads .typ source]
       [modifies grid layout]
       [vizrender updated.typ]
       [reads .png to verify change looks right]
       "Done — panel B is now on the left."
```

## Live Update Pattern

```
# Slow updates (30s+): agent controls the loop
loop:
  data = fetch_from_mcp()
  write data → plot.typ
  vizrender plot.typ

# Fast updates (1-5s): use typst watch
vizrender plot.typ --watch &
loop:
  data = fetch_from_mcp()
  write data → plot.typ          # vizrender auto-recompiles
  vizshow output.png             # re-display latest
```

## Display-Only (no typst)

Show any existing image inline:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/vizshow image.png
```

## Troubleshooting

- **typst not found**: Install via `brew install typst` or `cargo install typst-cli`
- **No image in terminal**: Check terminal supports iTerm2/Kitty graphics protocol. Use `--protocol file` to just save the file.
- **SVG→PNG fails**: Install `librsvg` (`brew install librsvg`) or ImageMagick. Fallback: `vizrender` compiles directly to PNG.
```

- [ ] **Step 2: Write reference.md**

Create `plugins/inline-viz/skills/inline-viz/reference.md`:

```markdown
# Inline Viz — Template API Reference

## Scripts

| Script | Usage | Key Options |
|--------|-------|-------------|
| `vizshow` | `${CLAUDE_PLUGIN_ROOT}/scripts/vizshow <image>` | `--width N`, `--protocol P`, `--quiet` |
| `vizrender` | `${CLAUDE_PLUGIN_ROOT}/scripts/vizrender <file.typ>` | `--format svg\|png\|pdf`, `--no-display`, `--width N`, `--open` |

## pixel-art.typ

```typst
#import sys.inputs.template-dir + "/pixel-art.typ": *
scene((alice(size: 2cm), bob(size: 2cm)), caption: "Hello")
```

## qec.typ

```typst
#import sys.inputs.template-dir + "/qec.typ": *
qec-surface(5, errors: ((2,1), (3,3)), corrections: (((2,1),(3,3)),))
```

## quantum-control.typ

```typst
#import sys.inputs.template-dir + "/quantum-control.typ": *
control-panel(
  trajectory: ((0, 0, 0), (0.5, 1.57, 0.1), (1.0, 1.57, 0.2)),
  pulses: ((0, 125, 0), (5, 120, 10), (10, 100, 15), (15, 50, 8), (20, 0, 0)),
)
```

## bdd.typ

```typst
#import sys.inputs.template-dir + "/bdd.typ": *
bdd-compare("(a & b) | c", orderings: (("a", "b", "c"), ("c", "b", "a")))
```
```

- [ ] **Step 3: Commit**

```bash
git add plugins/inline-viz/skills/inline-viz/SKILL.md plugins/inline-viz/skills/inline-viz/reference.md
git commit -m "feat(inline-viz): add SKILL.md and template reference"
```

---

### Task 7: QEC Template

**Files:**
- Create: `plugins/inline-viz/templates/qec.typ`

- [ ] **Step 1: Write qec.typ template**

Create `plugins/inline-viz/templates/qec.typ`:

```typst
#import "@preview/qec-thrust:0.1.2": *
#import "@preview/cetz:0.4.0": canvas, draw

/// Draw a surface code with optional error and correction overlays.
/// - size: lattice distance (e.g., 5 for distance-5)
/// - errors: array of (x, y) coordinates where errors occurred
/// - corrections: array of ((x1,y1),(x2,y2)) pairs for correction chains
/// - highlight-logical: if true, highlight logical error path in orange
/// - ..args: passed through to qec-thrust surface-code()
#let qec-surface(
  size,
  errors: (),
  corrections: (),
  highlight-logical: false,
  point-radius: 0.15,
  boundary-bulge: 0.3,
) = {
  set page(width: auto, height: auto, margin: 12pt)
  canvas({
    import draw: *

    // Draw the base surface code lattice
    surface-code((0, 0), size: size,
      point-radius: point-radius,
      boundary-bulge: boundary-bulge)

    // Overlay error markers (red circles)
    for e in errors {
      circle(
        (e.at(0) * 1.0, e.at(1) * 1.0),
        radius: 0.25,
        fill: rgb("#ff000040"),
        stroke: rgb("#ff0000") + 2pt,
      )
    }

    // Overlay correction chains (blue lines)
    for c in corrections {
      let start = c.at(0)
      let end = c.at(1)
      line(
        (start.at(0) * 1.0, start.at(1) * 1.0),
        (end.at(0) * 1.0, end.at(1) * 1.0),
        stroke: rgb("#3b82f6") + 2.5pt,
      )
    }

    // Highlight logical error path
    if highlight-logical {
      // Draw a horizontal line across the lattice (X logical)
      line(
        (-0.5, calc.floor(size / 2) * 1.0),
        (size * 1.0 + 0.5, calc.floor(size / 2) * 1.0),
        stroke: rgb("#f59e0b") + 3pt,
      )
    }
  })
}

/// Mark syndrome measurement outcomes on the lattice.
/// - syndromes: array of (x, y, type) where type is "X" or "Z"
#let mark-syndromes(syndromes) = {
  for s in syndromes {
    let color = if s.at(2) == "X" { rgb("#ef4444") } else { rgb("#3b82f6") }
    draw.circle(
      (s.at(0) * 1.0, s.at(1) * 1.0),
      radius: 0.2,
      fill: color,
      stroke: none,
    )
  }
}
```

- [ ] **Step 2: Test with a sample QEC visualization**

```bash
cat > /tmp/test-qec.typ << 'TYPST'
#import "@preview/qec-thrust:0.1.2": *
#import "@preview/cetz:0.4.0": canvas, draw

#set page(width: auto, height: auto, margin: 12pt)

#canvas({
  import draw: *
  surface-code((0, 0), size: 3, point-radius: 0.15)
})
TYPST

plugins/inline-viz/scripts/vizrender /tmp/test-qec.typ
```

Expected: A distance-3 surface code lattice appears inline.

- [ ] **Step 3: Commit**

```bash
git add plugins/inline-viz/templates/qec.typ
git commit -m "feat(inline-viz): add QEC surface code template"
```

---

### Task 8: BDD Template

**Files:**
- Create: `plugins/inline-viz/templates/bdd.typ`

- [ ] **Step 1: Write bdd.typ template**

Create `plugins/inline-viz/templates/bdd.typ`:

```typst
#import "@preview/typdd:0.1.0": *

/// Render a single BDD from a boolean expression.
/// - expr: boolean expression string (e.g., "(a & b) | c")
/// - style: rendering style ("classic", "paper", "presentation", "curved")
/// - labels: dict mapping variable names to display labels
/// - ..args: passed through to typdd bdd()
#let bdd-single(expr, style: "paper", labels: (:), ..args) = {
  set page(width: auto, height: auto, margin: 12pt)
  bdd(expr, style: style, labels: labels, ..args)
}

/// Render two BDDs side by side with different variable orderings for comparison.
/// - expr: boolean expression string
/// - orderings: array of two ordering arrays (e.g., (("a","b","c"), ("c","b","a")))
/// - style: rendering style
/// - labels: dict mapping variable names to display labels
#let bdd-compare(expr, orderings: (), style: "paper", labels: (:)) = {
  set page(width: auto, height: auto, margin: 12pt)
  let diagrams = orderings.map(order => {
    box(
      stroke: 0.5pt + luma(200),
      inset: 8pt,
      radius: 4pt,
      [
        #align(center, text(9pt, fill: luma(100))[Order: #order.join(" > ")])
        #v(4pt)
        #bdd(expr, style: style, labels: labels, order: order)
      ]
    )
  })
  align(center,
    stack(dir: ltr, spacing: 1.5cm, ..diagrams)
  )
}
```

- [ ] **Step 2: Test with a sample BDD**

```bash
cat > /tmp/test-bdd.typ << 'TYPST'
#import "@preview/typdd:0.1.0": *

#set page(width: auto, height: auto, margin: 12pt)
#bdd("(a & b) | (a & c) | (b & c)", style: "paper")
TYPST

plugins/inline-viz/scripts/vizrender /tmp/test-bdd.typ
```

Expected: A BDD for the majority function appears inline.

- [ ] **Step 3: Commit**

```bash
git add plugins/inline-viz/templates/bdd.typ
git commit -m "feat(inline-viz): add BDD template with comparison mode"
```

---

### Task 9: Remaining Templates (Stubs)

**Files:**
- Create: `plugins/inline-viz/templates/quantum-control.typ`
- Create: `plugins/inline-viz/templates/tensor-network.typ`
- Create: `plugins/inline-viz/templates/feynman.typ`
- Create: `plugins/inline-viz/templates/plot.typ`
- Create: `plugins/inline-viz/templates/paper-layout.typ`

These templates are more complex and depend on CeTZ drawing primitives. They should be implemented as working stubs that agents can use immediately — with the full API filled in as needed.

- [ ] **Step 1: Write quantum-control.typ**

Create `plugins/inline-viz/templates/quantum-control.typ`:

```typst
#import "@preview/cetz:0.4.0": canvas, draw, plot

/// Draw a Bloch sphere with a state trajectory.
/// - trajectory: array of (theta, phi, time) tuples in radians
/// - radius: sphere radius (default: 2cm)
#let bloch-sphere(trajectory, radius: 2) = {
  canvas({
    import draw: *

    // Sphere outline (circle + axes)
    circle((0, 0), radius: radius, stroke: luma(200) + 0.5pt, fill: none)
    // X axis
    line((-radius, 0), (radius, 0), stroke: luma(180) + 0.5pt)
    // Z axis
    line((0, -radius), (0, radius), stroke: luma(180) + 0.5pt)
    // Labels
    content((0, radius + 0.3), $|0 angle.r$)
    content((0, -radius - 0.3), $|1 angle.r$)
    content((radius + 0.3, 0), $|+ angle.r$)
    content((-radius - 0.3, 0), $|- angle.r$)

    // Plot trajectory as connected points
    if trajectory.len() > 1 {
      for i in range(trajectory.len() - 1) {
        let t1 = trajectory.at(i)
        let t2 = trajectory.at(i + 1)
        // Project spherical coords to 2D (simple front projection)
        let x1 = radius * calc.sin(t1.at(0)) * calc.cos(t1.at(1))
        let y1 = radius * calc.cos(t1.at(0))
        let x2 = radius * calc.sin(t2.at(0)) * calc.cos(t2.at(1))
        let y2 = radius * calc.cos(t2.at(0))
        // Color gradient: blue → red over time
        let frac = i / (trajectory.len() - 1)
        let r = calc.round(frac * 255)
        let b = calc.round((1 - frac) * 255)
        line((x1, y1), (x2, y2), stroke: rgb(r, 0, b) + 1.5pt)
      }
    }
  })
}

/// Multi-panel optimal control visualization.
/// - trajectory: Bloch sphere trajectory (array of (theta, phi, time))
/// - pulses: control pulse data (array of (time, Omega_I, Omega_Q))
/// - fidelity-sweep: fidelity vs detuning (array of (delta, fidelity))
#let control-panel(
  trajectory: (),
  pulses: (),
  fidelity-sweep: (),
) = {
  set page(width: auto, height: auto, margin: 12pt)

  grid(
    columns: 2,
    gutter: 16pt,
    [
      #align(center, text(10pt, weight: "bold")[Bloch Sphere])
      #bloch-sphere(trajectory)
    ],
    if pulses.len() > 0 [
      #align(center, text(10pt, weight: "bold")[Control Pulses])
      #canvas({
        plot.plot(size: (5, 3), x-label: $t$ + " (ns)", y-label: $Omega$ + " (MHz)", {
          plot.add(pulses.map(p => (p.at(0), p.at(1))), label: $Omega_I$)
          plot.add(pulses.map(p => (p.at(0), p.at(2))), label: $Omega_Q$, style: (stroke: rgb("#f59e0b")))
        })
      })
    ],
  )
}
```

- [ ] **Step 2: Write tensor-network.typ**

Create `plugins/inline-viz/templates/tensor-network.typ`:

```typst
#import "@preview/cetz:0.4.0": canvas, draw

/// Draw an MPS chain with labeled bond dimensions.
/// - n-sites: number of sites
/// - bond-dims: array of bond dimensions (length n-sites - 1)
/// - phys-labels: array of physical index labels (default: s_1, s_2, ...)
/// - tensor-radius: radius of tensor nodes
#let mps(n-sites, bond-dims: (), phys-labels: (), tensor-radius: 0.3) = {
  set page(width: auto, height: auto, margin: 12pt)
  let spacing = 1.5
  canvas({
    import draw: *
    for i in range(n-sites) {
      let x = i * spacing
      // Tensor node
      circle((x, 0), radius: tensor-radius, fill: rgb("#dbeafe"), stroke: rgb("#3b82f6") + 1pt)
      // Physical leg
      line((x, 0), (x, -1), stroke: 0.8pt)
      let label = if phys-labels.len() > i { phys-labels.at(i) } else { $s_(#(i+1))$ }
      content((x, -1.3), text(8pt, label))
      // Bond to next tensor
      if i < n-sites - 1 {
        line((x + tensor-radius, 0), ((i + 1) * spacing - tensor-radius, 0), stroke: 1pt)
        let chi = if bond-dims.len() > i { str(bond-dims.at(i)) } else { "" }
        if chi != "" {
          content(((x + (i + 1) * spacing) / 2, 0.35), text(7pt, fill: rgb("#6b7280"), $chi = #chi$))
        }
      }
    }
  })
}

/// Draw a honeycomb lattice with colored bond types.
/// - rows: number of rows
/// - cols: number of columns
/// - couplings: dict with keys "x", "y", "z" mapping to coupling strengths
/// - colors: dict with keys "x", "y", "z" mapping to colors
#let honeycomb(rows: 3, cols: 3, couplings: (x: 1, y: 1, z: 0.5), colors: (x: rgb("#ef4444"), y: rgb("#3b82f6"), z: rgb("#22c55e"))) = {
  set page(width: auto, height: auto, margin: 16pt)
  canvas({
    import draw: *
    // Honeycomb geometry — each hexagon has 6 vertices
    // Bond types alternate around the hexagon: x, y, z, x, y, z
    let dx = 1.5
    let dy = calc.sqrt(3) / 2 * 1.0

    for row in range(rows) {
      for col in range(cols) {
        let cx = col * 3 * dx + calc.rem(row, 2) * 1.5 * dx
        let cy = row * dy * 2

        // Draw hexagon edges with bond-type coloring
        let angles = (0, 60, 120, 180, 240, 300)
        let bond-types = ("x", "y", "z", "x", "y", "z")
        for i in range(6) {
          let a1 = angles.at(i) * calc.pi / 180
          let a2 = angles.at(calc.rem(i + 1, 6)) * calc.pi / 180
          let x1 = cx + calc.cos(a1)
          let y1 = cy + calc.sin(a1)
          let x2 = cx + calc.cos(a2)
          let y2 = cy + calc.sin(a2)
          let bt = bond-types.at(i)
          let strength = couplings.at(bt)
          line((x1, y1), (x2, y2),
            stroke: colors.at(bt) + (strength * 2pt))
        }

        // Vertex dots
        for i in range(6) {
          let a = angles.at(i) * calc.pi / 180
          circle((cx + calc.cos(a), cy + calc.sin(a)),
            radius: 0.12, fill: luma(60), stroke: none)
        }
      }
    }

    // Legend
    let lx = cols * 3 * dx + 1
    for (i, (bt, label)) in (("x", $K_x$), ("y", $K_y$), ("z", $K_z$)).enumerate() {
      let ly = i * 0.6
      line((lx, ly), (lx + 0.6, ly), stroke: colors.at(bt) + 2pt)
      content((lx + 1.2, ly), text(8pt, [#label = #couplings.at(bt)]))
    }
  })
}
```

- [ ] **Step 3: Write feynman.typ**

Create `plugins/inline-viz/templates/feynman.typ`:

```typst
#import "@preview/cetz:0.4.0": canvas, draw

/// Draw a fermion propagator (straight line with arrow).
#let fermion-line(start, end, label: none) = {
  draw.line(start, end, stroke: 1pt, mark: (end: ">", fill: black))
  if label != none {
    let mid = ((start.at(0) + end.at(0)) / 2, (start.at(1) + end.at(1)) / 2 + 0.3)
    draw.content(mid, text(8pt, label))
  }
}

/// Draw a photon propagator (wavy line approximated with sine-like segments).
#let photon-line(start, end, label: none, amplitude: 0.15, periods: 6) = {
  let dx = end.at(0) - start.at(0)
  let dy = end.at(1) - start.at(1)
  let len = calc.sqrt(dx * dx + dy * dy)
  let steps = periods * 8
  let points = range(steps + 1).map(i => {
    let t = i / steps
    let wave = amplitude * calc.sin(t * periods * 2 * calc.pi)
    // Perpendicular offset
    let nx = -dy / len * wave
    let ny = dx / len * wave
    (start.at(0) + dx * t + nx, start.at(1) + dy * t + ny)
  })
  for i in range(points.len() - 1) {
    draw.line(points.at(i), points.at(i + 1), stroke: 0.8pt)
  }
  if label != none {
    let mid = ((start.at(0) + end.at(0)) / 2, (start.at(1) + end.at(1)) / 2 + 0.35)
    draw.content(mid, text(8pt, label))
  }
}

/// Draw a gluon propagator (curly/coiled line).
#let gluon-line(start, end, label: none, amplitude: 0.2, periods: 5) = {
  let dx = end.at(0) - start.at(0)
  let dy = end.at(1) - start.at(1)
  let len = calc.sqrt(dx * dx + dy * dy)
  let steps = periods * 12
  let points = range(steps + 1).map(i => {
    let t = i / steps
    let phase = t * periods * 2 * calc.pi
    let wave = amplitude * (1 - calc.cos(phase)) * calc.sin(phase * 0.5)
    let nx = -dy / len * wave
    let ny = dx / len * wave
    (start.at(0) + dx * t + nx, start.at(1) + dy * t + ny)
  })
  for i in range(points.len() - 1) {
    draw.line(points.at(i), points.at(i + 1), stroke: 0.8pt)
  }
  if label != none {
    let mid = ((start.at(0) + end.at(0)) / 2, (start.at(1) + end.at(1)) / 2 + 0.35)
    draw.content(mid, text(8pt, label))
  }
}

/// Draw a scalar propagator (dashed line).
#let scalar-line(start, end, label: none) = {
  draw.line(start, end, stroke: (paint: black, thickness: 1pt, dash: "dashed"))
  if label != none {
    let mid = ((start.at(0) + end.at(0)) / 2, (start.at(1) + end.at(1)) / 2 + 0.3)
    draw.content(mid, text(8pt, label))
  }
}

/// Draw a vertex dot.
#let vertex(pos) = {
  draw.circle(pos, radius: 0.08, fill: black, stroke: none)
}

/// Convenience: draw a complete Feynman diagram from a description.
/// - vertices: dict mapping names to (x, y) positions
/// - propagators: array of (from, to, type, label) where type is "fermion"|"photon"|"gluon"|"scalar"
#let feynman-diagram(vertices: (:), propagators: (), page-size: auto) = {
  set page(width: page-size, height: page-size, margin: 16pt)
  canvas({
    import draw: *
    // Draw propagators
    for p in propagators {
      let from = vertices.at(p.at(0))
      let to = vertices.at(p.at(1))
      let ptype = p.at(2)
      let label = if p.len() > 3 { p.at(3) } else { none }
      if ptype == "fermion" { fermion-line(from, to, label: label) }
      else if ptype == "photon" { photon-line(from, to, label: label) }
      else if ptype == "gluon" { gluon-line(from, to, label: label) }
      else if ptype == "scalar" { scalar-line(from, to, label: label) }
    }
    // Draw vertices
    for (name, pos) in vertices {
      vertex(pos)
    }
  })
}
```

- [ ] **Step 4: Write plot.typ**

Create `plugins/inline-viz/templates/plot.typ`:

```typst
#import "@preview/cetz:0.4.0": canvas, plot

/// Simple line plot with auto-scaled axes.
/// - data: array of (x, y) tuples
/// - x-label: x-axis label
/// - y-label: y-axis label
/// - title: plot title
/// - size: (width, height) in cm
#let line-plot(data, x-label: $x$, y-label: $y$, title: none, size: (8, 5)) = {
  set page(width: auto, height: auto, margin: 12pt)
  if title != none {
    align(center, text(11pt, weight: "bold", title))
    v(4pt)
  }
  canvas({
    plot.plot(size: size, x-label: x-label, y-label: y-label, {
      plot.add(data)
    })
  })
}

/// Scatter plot.
/// - data: array of (x, y) tuples
/// - x-label, y-label, title, size: same as line-plot
#let scatter(data, x-label: $x$, y-label: $y$, title: none, size: (8, 5)) = {
  set page(width: auto, height: auto, margin: 12pt)
  if title != none {
    align(center, text(11pt, weight: "bold", title))
    v(4pt)
  }
  canvas({
    plot.plot(size: size, x-label: x-label, y-label: y-label, {
      plot.add(data, mark: "o", style: (stroke: none))
    })
  })
}

/// Multi-series line plot.
/// - series: array of (data, label) where data is array of (x, y)
/// - x-label, y-label, title, size: same as line-plot
#let multi-plot(series, x-label: $x$, y-label: $y$, title: none, size: (8, 5)) = {
  set page(width: auto, height: auto, margin: 12pt)
  if title != none {
    align(center, text(11pt, weight: "bold", title))
    v(4pt)
  }
  canvas({
    plot.plot(size: size, x-label: x-label, y-label: y-label, {
      for s in series {
        plot.add(s.at(0), label: s.at(1))
      }
    })
  })
}
```

- [ ] **Step 5: Write paper-layout.typ**

Create `plugins/inline-viz/templates/paper-layout.typ`:

```typst
/// Multi-panel figure arrangement with labels.
/// - panels: array of (label, content) pairs, e.g., (("a", [#image(...)]), ("b", [...]))
/// - columns: number of columns (default: 2)
/// - gutter: gap between panels (default: 12pt)
#let figure-panel(panels, columns: 2, gutter: 12pt) = {
  set page(width: auto, height: auto, margin: 12pt)
  let cells = panels.map(p => {
    let (label, content) = p
    box(
      inset: 4pt,
      [
        #text(10pt, weight: "bold")[(#label)]
        #v(2pt)
        #content
      ]
    )
  })
  grid(
    columns: range(columns).map(_ => auto),
    gutter: gutter,
    ..cells
  )
}
```

- [ ] **Step 6: Test one template from each category**

```bash
# Tensor network MPS
cat > /tmp/test-tn.typ << 'TYPST'
#import "@preview/cetz:0.4.0": canvas, draw
#set page(width: auto, height: auto, margin: 12pt)
// Simple MPS test — 4 sites with bond dims
#let spacing = 1.5
#let r = 0.3
#let bonds = (4, 8, 4)
#canvas({
  import draw: *
  for i in range(4) {
    let x = i * spacing
    circle((x, 0), radius: r, fill: rgb("#dbeafe"), stroke: rgb("#3b82f6") + 1pt)
    line((x, 0), (x, -1), stroke: 0.8pt)
    content((x, -1.3), text(8pt, $s_(#(i+1))$))
    if i < 3 {
      line((x + r, 0), ((i + 1) * spacing - r, 0), stroke: 1pt)
      content(((x + (i + 1) * spacing) / 2, 0.35), text(7pt, fill: rgb("#6b7280"), $chi = #(bonds.at(i))$))
    }
  }
})
TYPST
plugins/inline-viz/scripts/vizrender /tmp/test-tn.typ

# Plot
cat > /tmp/test-plot.typ << 'TYPST'
#import "@preview/cetz:0.4.0": canvas, plot
#set page(width: auto, height: auto, margin: 12pt)
#canvas({
  plot.plot(size: (8, 5), x-label: $t$, y-label: $f(t)$, {
    plot.add(range(20).map(i => {
      let x = i * 0.5
      (x, calc.sin(x))
    }))
  })
})
TYPST
plugins/inline-viz/scripts/vizrender /tmp/test-plot.typ
```

Expected: An MPS diagram and a sine wave plot appear inline.

- [ ] **Step 7: Commit**

```bash
git add plugins/inline-viz/templates/quantum-control.typ \
        plugins/inline-viz/templates/tensor-network.typ \
        plugins/inline-viz/templates/feynman.typ \
        plugins/inline-viz/templates/plot.typ \
        plugins/inline-viz/templates/paper-layout.typ
git commit -m "feat(inline-viz): add remaining viz templates (quantum-control, TN, Feynman, plot, paper-layout)"
```

---

### Task 10: Marketplace Integration + Final Test

**Files:**
- Modify: `.claude-plugin/marketplace.json` (already done in Task 1)

- [ ] **Step 1: Run full test suite**

```bash
cd /Users/hmyuuu/workspace/skills
bash plugins/inline-viz/tests/run-tests.sh
```

Expected: All tests pass.

- [ ] **Step 2: Test plugin loading with --plugin-dir**

```bash
claude --plugin-dir plugins/inline-viz
# Then inside Claude Code: /inline-viz:inline-viz
# Verify the skill loads and is described correctly
```

- [ ] **Step 3: End-to-end demo — pixel art**

Inside Claude Code with the plugin loaded, say:
> "Show me Alice and Bob as pixel art"

The agent should:
1. Write a .typ file using pixel-family
2. Call `${CLAUDE_PLUGIN_ROOT}/scripts/vizrender` on it
3. Display characters inline
4. Print structured output with file paths

- [ ] **Step 4: End-to-end demo — BDD**

> "Show me the BDD for the carry function: (a & b) | (a & c) | (b & c)"

The agent should use typdd to render the BDD inline.

- [ ] **Step 5: Commit final state and push**

```bash
cd /Users/hmyuuu/workspace/skills
git add -A plugins/inline-viz/
git status
git commit -m "feat(inline-viz): complete v0.1.0 plugin with all templates and tests"
```

- [ ] **Step 6: Verify marketplace entry**

Check that `.claude-plugin/marketplace.json` includes the inline-viz entry (should already be there from Task 1). Bump marketplace version if desired.

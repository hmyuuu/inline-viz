# Inline Viz Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that renders typst diagrams inline in the terminal and supports agent readback for iterative refinement.

**Architecture:** Three-layer stack — `vizshow` (terminal display), `vizrender` (typst compile + display), and typst template files (domain-specific viz libraries). Standalone repo at `/Users/hmyuuu/workspace/inline-viz/`, referenced from `hmyuuu-skills` marketplace via GitHub source.

**Tech Stack:** Bash, typst 0.14.2, rsvg-convert (SVG→PNG), iTerm2/Kitty graphics protocols, CeTZ (typst drawing), pixel-family, qec-thrust, typdd (typst packages)

---

## File Map

```
inline-viz/                        # standalone git repo
├── .claude-plugin/
│   └── plugin.json                # plugin manifest (already created)
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
├── tests/
│   ├── test-vizshow.sh            # vizshow integration tests
│   ├── test-vizrender.sh          # vizrender integration tests
│   ├── test-pixel-art.typ         # smoke test typst file
│   └── run-tests.sh              # test runner
└── docs/
    ├── design.md                  # design spec
    └── plan.md                    # this file
```

---

### Task 1: `vizshow` — Terminal Display Script (Layer 1)

**Files:**
- Create: `scripts/vizshow`
- Create: `tests/test-vizshow.sh`

**Acceptance Criteria:**
- [ ] `vizshow /path/to/image.png` displays the image inline in iTerm2 (or current terminal)
- [ ] `vizshow nonexistent.png` exits with code 1 and prints "not found" error
- [ ] `vizshow image.png --protocol file` exits with code 2 and prints `[vizshow: /path via file]`
- [ ] `vizshow image.png --quiet` suppresses the `[vizshow: ...]` line
- [ ] Output always ends with `[vizshow: /absolute/path/to/file.png via <protocol>]` (unless --quiet)
- [ ] Protocol auto-detection works: $TERM_PROGRAM → iTerm2, $KITTY_PID → Kitty, $GHOSTTY_RESOURCES_DIR → Kitty, $WEZTERM_EXECUTABLE → iTerm2
- [ ] Falls back to timg/chafa/imgcat/kitten if env vars not set
- [ ] `tests/test-vizshow.sh` passes with 0 failures

- [ ] **Step 1: Write test script**

Create `tests/test-vizshow.sh`:

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

# Test: fallback to file protocol
echo "Test: fallback to file protocol"
TMPDIR_TEST=$(mktemp -d)
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

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x tests/test-vizshow.sh
bash tests/test-vizshow.sh
```

Expected: FAIL — `vizshow` does not exist yet.

- [ ] **Step 3: Write vizshow**

Create `scripts/vizshow`:

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
  local data
  data=$(base64 < "$file")
  local len=${#data}
  local chunk_size=4096
  local offset=0
  while [[ $offset -lt $len ]]; do
    local chunk="${data:$offset:$chunk_size}"
    offset=$((offset + chunk_size))
    if [[ $offset -ge $len ]]; then
      printf '\033_Ga=T,f=100,m=0;%s\033\\' "$chunk"
    else
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
}

detect_and_display() {
  local file="$1"

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

  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    display_iterm2 "$file" "$WIDTH"; PROTOCOL="iterm2"; return 0
  fi
  if [[ -n "${KITTY_PID:-}" ]]; then
    display_kitty "$file"; PROTOCOL="kitty"; return 0
  fi
  if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
    display_kitty "$file"; PROTOCOL="kitty"; return 0
  fi
  if [[ -n "${WEZTERM_EXECUTABLE:-}" ]]; then
    display_iterm2 "$file" "$WIDTH"; PROTOCOL="iterm2"; return 0
  fi

  for tool in timg chafa imgcat; do
    if command -v "$tool" &>/dev/null; then
      display_tool "$tool" "$file" "$WIDTH"; PROTOCOL="$tool"; return 0
    fi
  done
  if command -v kitten &>/dev/null; then
    display_tool "icat" "$file" "$WIDTH"; PROTOCOL="icat"; return 0
  fi

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
chmod +x scripts/vizshow
bash tests/test-vizshow.sh
```

Expected: All tests PASS.

- [ ] **Step 5: Manual smoke test**

```bash
echo '#set page(width: 100pt, height: 50pt, margin: 5pt)
#align(center + horizon, text(20pt, fill: blue)[Hello!])' > /tmp/test-vizshow.typ
typst compile /tmp/test-vizshow.typ /tmp/test-vizshow.png
scripts/vizshow /tmp/test-vizshow.png
```

Expected: "Hello!" appears inline. `[vizshow: ... via iterm2]` prints below.

- [ ] **Step 6: Commit**

```bash
git add scripts/vizshow tests/test-vizshow.sh
git commit -m "feat: add vizshow terminal display script"
```

---

### Task 2: `vizrender` — Typst Render Engine (Layer 2)

**Files:**
- Create: `scripts/vizrender`
- Create: `tests/test-vizrender.sh`

**Acceptance Criteria:**
- [ ] `vizrender input.typ` compiles to SVG, converts to PNG, displays inline, prints structured output
- [ ] `vizrender input.typ --no-display` compiles to SVG without displaying
- [ ] `vizrender input.typ --format png` compiles directly to PNG
- [ ] `vizrender input.typ --format pdf` compiles to PDF
- [ ] `vizrender input.typ --output /path/out.svg` writes to custom path
- [ ] Structured output contains `[vizrender: source=...]`, `[vizrender: rendered=...]`, `[vizrender: displayed=...]`
- [ ] `--input template-dir=<path>` is passed to typst so templates can use `sys.inputs.template-dir`
- [ ] Missing input file exits with error
- [ ] `tests/test-vizrender.sh` passes with 0 failures

- [ ] **Step 1: Write test script**

Create `tests/test-vizrender.sh`:

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

cat > "$TMPDIR_TEST/hello.typ" << 'TYPST'
#set page(width: 100pt, height: 50pt, margin: 5pt)
#align(center + horizon, text(20pt)[Test])
TYPST

# Test: compile to SVG
echo "Test: compile to SVG"
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

# Test: missing input file
echo "Test: missing input file"
output=$("$VIZRENDER" "$TMPDIR_TEST/nonexistent.typ" --no-display 2>&1 || true)
assert_contains "error for missing file" "not found" "$output"

# Test: display mode produces structured output with displayed path
echo "Test: display mode"
output=$("$VIZRENDER" "$TMPDIR_TEST/hello.typ" --display 2>&1)
assert_contains "displayed path" "[vizrender: displayed=" "$output"

rm -rf "$TMPDIR_TEST"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x tests/test-vizrender.sh
bash tests/test-vizrender.sh
```

Expected: FAIL — `vizrender` does not exist yet.

- [ ] **Step 3: Write vizrender**

Create `scripts/vizrender`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# vizrender — compile typst to SVG/PNG/PDF and optionally display inline

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
  DISPLAY_FILE="$RENDERED"

  if [[ "$FORMAT" == "svg" ]]; then
    DISPLAY_FILE="${INPUT_DIR}/${INPUT_BASE}.png"
    if command -v rsvg-convert &>/dev/null; then
      rsvg-convert "$RENDERED" -o "$DISPLAY_FILE"
    elif command -v magick &>/dev/null; then
      magick convert "$RENDERED" "$DISPLAY_FILE"
    else
      typst compile "$INPUT" "$DISPLAY_FILE"
    fi
  elif [[ "$FORMAT" == "pdf" ]]; then
    DISPLAY_FILE="${INPUT_DIR}/${INPUT_BASE}.png"
    typst compile "$INPUT" "$DISPLAY_FILE"
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
chmod +x scripts/vizrender
bash tests/test-vizrender.sh
```

Expected: All tests PASS.

- [ ] **Step 5: Manual end-to-end smoke test**

```bash
echo '#set page(width: 200pt, height: 100pt, margin: 10pt)
#align(center + horizon)[
  #text(24pt, fill: purple)[vizrender works!]
]' > /tmp/test-vizrender.typ
scripts/vizrender /tmp/test-vizrender.typ
```

Expected: Purple text appears inline. Structured output prints paths.

- [ ] **Step 6: Commit**

```bash
git add scripts/vizrender tests/test-vizrender.sh
git commit -m "feat: add vizrender typst compile + display engine"
```

---

### Task 3: Test Runner

**Files:**
- Create: `tests/run-tests.sh`

**Acceptance Criteria:**
- [ ] `bash tests/run-tests.sh` discovers and runs all `test-*.sh` files
- [ ] Reports overall pass/fail
- [ ] Exits 0 only if all suites pass

- [ ] **Step 1: Write test runner**

Create `tests/run-tests.sh`:

```bash
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
```

- [ ] **Step 2: Run full test suite**

```bash
chmod +x tests/run-tests.sh
bash tests/run-tests.sh
```

Expected: Both test suites pass.

- [ ] **Step 3: Commit**

```bash
git add tests/run-tests.sh
git commit -m "feat: add test runner"
```

---

### Task 4: Pixel Art Template — Smoke Test (Layer 3)

**Files:**
- Create: `templates/pixel-art.typ`
- Create: `tests/test-pixel-art.typ`

**Acceptance Criteria:**
- [ ] `vizrender tests/test-pixel-art.typ` displays pixel art characters inline in terminal
- [ ] SVG output is generated and contains valid SVG XML
- [ ] Agent can read back the SVG file (file exists, non-empty, valid XML structure)
- [ ] Template `scene()` function composes multiple characters with optional caption

- [ ] **Step 1: Write pixel-art template**

Create `templates/pixel-art.typ`:

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

- [ ] **Step 2: Write smoke test .typ file**

Create `tests/test-pixel-art.typ`:

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

- [ ] **Step 3: Compile and display**

```bash
scripts/vizrender tests/test-pixel-art.typ
```

Expected: Alice and Bob pixel art characters appear inline.

- [ ] **Step 4: Verify SVG readback**

```bash
head -5 tests/test-pixel-art.svg
wc -c tests/test-pixel-art.svg
```

Expected: Valid SVG XML, non-trivial file size.

- [ ] **Step 5: Commit**

```bash
git add templates/pixel-art.typ tests/test-pixel-art.typ
git commit -m "feat: add pixel-art template and smoke test"
```

---

### Task 5: SKILL.md — Skill Document

**Files:**
- Create: `skills/inline-viz/SKILL.md`
- Create: `skills/inline-viz/reference.md`

**Acceptance Criteria:**
- [ ] SKILL.md has valid YAML frontmatter with `name: inline-viz` and `description` starting with "Use when"
- [ ] Contains sections: Quick Start, Core Workflow, Templates, Readback Patterns, Iteration, Live Update, Display-Only, Troubleshooting
- [ ] Quick Start example is copy-pasteable and works
- [ ] Template table lists all 8 templates with import paths
- [ ] reference.md has concise API reference for each template

- [ ] **Step 1: Write SKILL.md**

Create `skills/inline-viz/SKILL.md`:

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

Writing `.typ` from scratch works for simple or custom diagrams.

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
  write data → plot.typ
  vizshow output.png
```

## Display-Only (no typst)

Show any existing image inline:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/vizshow image.png
```

## Troubleshooting

- **typst not found**: Install via `brew install typst` or `cargo install typst-cli`
- **No image in terminal**: Check terminal supports iTerm2/Kitty graphics protocol. Use `--protocol file` to just save.
- **SVG→PNG fails**: Install `librsvg` (`brew install librsvg`) or ImageMagick. Fallback: vizrender compiles directly to PNG.
```

- [ ] **Step 2: Write reference.md**

Create `skills/inline-viz/reference.md`:

```markdown
# Inline Viz — Template API Reference

## Scripts

| Script | Usage | Key Options |
|--------|-------|-------------|
| `vizshow` | `${CLAUDE_PLUGIN_ROOT}/scripts/vizshow <image>` | `--width N`, `--protocol P`, `--quiet` |
| `vizrender` | `${CLAUDE_PLUGIN_ROOT}/scripts/vizrender <file.typ>` | `--format svg\|png\|pdf`, `--no-display`, `--width N`, `--open` |

## pixel-art.typ

```typst
scene((alice(size: 2cm), bob(size: 2cm)), caption: "Hello")
```

## qec.typ

```typst
qec-surface(5, errors: ((2,1), (3,3)), corrections: (((2,1),(3,3)),))
```

## quantum-control.typ

```typst
control-panel(
  trajectory: ((0, 0, 0), (0.5, 1.57, 0.1), (1.0, 1.57, 0.2)),
  pulses: ((0, 125, 0), (5, 120, 10), (10, 100, 15), (15, 50, 8), (20, 0, 0)),
)
```

## tensor-network.typ

```typst
mps(6, bond-dims: (4, 8, 12, 8, 4))
honeycomb(rows: 3, cols: 3, couplings: (x: 1, y: 1, z: 0.5))
```

## bdd.typ

```typst
bdd-single("(a & b) | c", style: "paper")
bdd-compare("(a & b) | c", orderings: (("a", "b", "c"), ("c", "b", "a")))
```

## feynman.typ

```typst
feynman-diagram(
  vertices: (v1: (0,0), v2: (2,0), v3: (1,1.5)),
  propagators: (("v1","v2","fermion",$p$), ("v2","v3","photon",$gamma$), ("v3","v1","fermion",$p'$)),
)
```

## plot.typ

```typst
line-plot(data, x-label: $t$, y-label: $f(t)$, title: "Signal")
scatter(data, x-label: $x$, y-label: $y$)
multi-plot((series1, series2), x-label: $t$)
```

## paper-layout.typ

```typst
figure-panel((("a", [panel-a-content]), ("b", [panel-b-content])), columns: 2)
```
```

- [ ] **Step 3: Commit**

```bash
git add skills/inline-viz/SKILL.md skills/inline-viz/reference.md
git commit -m "feat: add SKILL.md and template API reference"
```

---

### Task 6: QEC Template

**Files:**
- Create: `templates/qec.typ`

**Acceptance Criteria:**
- [ ] `qec-surface(3)` renders a distance-3 surface code lattice
- [ ] `qec-surface(5, errors: ((2,1), (3,3)))` shows red circle overlays at error positions
- [ ] `corrections` parameter draws blue lines between paired syndromes
- [ ] `highlight-logical: true` draws an orange line across the lattice
- [ ] Output compiles without errors via `vizrender`

- [ ] **Step 1: Write qec.typ**

Create `templates/qec.typ` — see design spec for full implementation (wraps `@preview/qec-thrust:0.1.2` with `mark-errors()`, `show-matching()`, `highlight-logical()` overlay functions using CeTZ).

- [ ] **Step 2: Test**

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
scripts/vizrender /tmp/test-qec.typ
```

Expected: Distance-3 surface code lattice appears inline.

- [ ] **Step 3: Commit**

```bash
git add templates/qec.typ
git commit -m "feat: add QEC surface code template"
```

---

### Task 7: BDD Template

**Files:**
- Create: `templates/bdd.typ`

**Acceptance Criteria:**
- [ ] `bdd-single("(a & b) | c")` renders a single BDD
- [ ] `bdd-compare(expr, orderings: (order1, order2))` renders two BDDs side by side
- [ ] Variable labels are customizable via `labels` parameter
- [ ] Output compiles without errors via `vizrender`

- [ ] **Step 1: Write bdd.typ**

Create `templates/bdd.typ` — wraps `@preview/typdd` with `bdd-single()` and `bdd-compare()` functions. See design spec for implementation.

- [ ] **Step 2: Test**

```bash
cat > /tmp/test-bdd.typ << 'TYPST'
#import "@preview/typdd:0.1.0": *
#set page(width: auto, height: auto, margin: 12pt)
#bdd("(a & b) | (a & c) | (b & c)", style: "paper")
TYPST
scripts/vizrender /tmp/test-bdd.typ
```

Expected: BDD for majority function appears inline.

- [ ] **Step 3: Commit**

```bash
git add templates/bdd.typ
git commit -m "feat: add BDD template with comparison mode"
```

---

### Task 8: Remaining Templates

**Files:**
- Create: `templates/quantum-control.typ`
- Create: `templates/tensor-network.typ`
- Create: `templates/feynman.typ`
- Create: `templates/plot.typ`
- Create: `templates/paper-layout.typ`

**Acceptance Criteria:**
- [ ] `quantum-control.typ`: `bloch-sphere(trajectory)` renders a Bloch sphere with trajectory; `control-panel()` renders multi-panel layout
- [ ] `tensor-network.typ`: `mps(n, bond-dims: (...))` renders MPS chain with labeled bonds; `honeycomb()` renders honeycomb lattice with 3 colored bond types
- [ ] `feynman.typ`: `feynman-diagram(vertices, propagators)` renders diagram with correct line styles (wavy/curly/straight/dashed)
- [ ] `plot.typ`: `line-plot(data)` renders a line plot with auto-scaled axes
- [ ] `paper-layout.typ`: `figure-panel(panels, columns: 2)` renders labeled multi-panel figure
- [ ] All templates compile without errors via `vizrender`
- [ ] At least one manual test per template produces visible output inline

- [ ] **Step 1: Write all five templates**

See design spec for full implementations. Key functions per template:

- `quantum-control.typ`: `bloch-sphere()`, `control-panel(trajectory, pulses, fidelity-sweep)`
- `tensor-network.typ`: `mps()`, `honeycomb(rows, cols, couplings, colors)`
- `feynman.typ`: `fermion-line()`, `photon-line()`, `gluon-line()`, `scalar-line()`, `vertex()`, `feynman-diagram()`
- `plot.typ`: `line-plot()`, `scatter()`, `multi-plot()`
- `paper-layout.typ`: `figure-panel()`

- [ ] **Step 2: Test tensor network MPS**

```bash
cat > /tmp/test-tn.typ << 'TYPST'
#import "@preview/cetz:0.4.0": canvas, draw
#set page(width: auto, height: auto, margin: 12pt)
#let spacing = 1.5
#let r = 0.3
#let bonds = (4, 8, 12, 8, 4)
#canvas({
  import draw: *
  for i in range(6) {
    let x = i * spacing
    circle((x, 0), radius: r, fill: rgb("#dbeafe"), stroke: rgb("#3b82f6") + 1pt)
    line((x, 0), (x, -1), stroke: 0.8pt)
    content((x, -1.3), text(8pt, $s_(#(i+1))$))
    if i < 5 {
      line((x + r, 0), ((i + 1) * spacing - r, 0), stroke: 1pt)
      content(((x + (i + 1) * spacing) / 2, 0.35), text(7pt, fill: rgb("#6b7280"), $chi = #(bonds.at(i))$))
    }
  }
})
TYPST
scripts/vizrender /tmp/test-tn.typ
```

Expected: 6-site MPS with bond dimensions appears inline.

- [ ] **Step 3: Test plot**

```bash
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
scripts/vizrender /tmp/test-plot.typ
```

Expected: Sine wave plot appears inline.

- [ ] **Step 4: Commit**

```bash
git add templates/quantum-control.typ templates/tensor-network.typ \
        templates/feynman.typ templates/plot.typ templates/paper-layout.typ
git commit -m "feat: add remaining viz templates"
```

---

### Task 9: Final Integration + Push

**Files:**
- None new

**Acceptance Criteria:**
- [ ] `bash tests/run-tests.sh` passes all suites
- [ ] `claude --plugin-dir .` loads the plugin and `/inline-viz:inline-viz` skill is accessible
- [ ] End-to-end: agent writes .typ → vizrender → image appears inline → structured output printed
- [ ] All changes committed and pushed to `hmyuuu/inline-viz`

- [ ] **Step 1: Run full test suite**

```bash
bash tests/run-tests.sh
```

Expected: All tests pass.

- [ ] **Step 2: Test plugin loading**

```bash
claude --plugin-dir .
# Then: /inline-viz:inline-viz
```

Verify skill loads and description is shown.

- [ ] **Step 3: End-to-end demo — pixel art**

Inside Claude Code with the plugin loaded:
> "Show me Alice and Bob as pixel art"

Agent should write .typ, call vizrender, display inline.

- [ ] **Step 4: Push**

```bash
git push origin main
```

- [ ] **Step 5: Verify marketplace reference**

In `/Users/hmyuuu/workspace/skills/.claude-plugin/marketplace.json`, confirm the inline-viz entry points to `hmyuuu/inline-viz` GitHub repo. Commit and push marketplace changes if not already done.

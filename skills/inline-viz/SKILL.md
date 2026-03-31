---
name: inline-viz
description: >
  Use when the user asks to visualize, plot, diagram, or render
  any scientific figure inline in the terminal. Supports quantum
  circuits, tensor networks, QEC codes, BDDs, Feynman diagrams,
  Bloch spheres, data plots, paper layouts, and pixel art.
---

# Inline Visualization

Render typst diagrams inline in the terminal. A PostToolUse hook automatically displays the image after vizrender runs — the user sees it directly in their terminal.

## Quick Start

```bash
# 1. Write a .typ file
cat > /tmp/hello.typ << 'EOF'
#import "@preview/pixel-family:0.1.0": *
#set page(width: auto, height: auto, margin: 12pt)
#alice(size: 3cm)
EOF

# 2. Render and display (hook shows it inline automatically)
${CLAUDE_PLUGIN_ROOT}/scripts/vizrender /tmp/hello.typ
```

Output includes file paths:
```
[vizrender: source=/tmp/hello.typ]
[vizrender: rendered=/tmp/hello.svg]
[vizrender: displayed=/tmp/hello.png]
```

The PostToolUse hook detects `[vizrender: displayed=...]` and calls vizshow to render the image directly in the user's terminal.

## IMPORTANT: Writing .typ Files

**Always write .typ files using Bash** (`cat > file.typ << 'EOF' ... EOF`), **never the Write tool.** These are temporary rendering files, not project source code. Using Bash avoids "file already exists" errors and lets you write + render in a single Bash call:

```bash
cat > /tmp/diagram.typ << 'EOF'
#set page(width: auto, height: auto, margin: 12pt)
// your typst content here
EOF
${CLAUDE_PLUGIN_ROOT}/scripts/vizrender /tmp/diagram.typ
```

## Core Workflow

1. **Write** a `.typ` file via Bash (cat heredoc) — never use the Write tool
2. **Render**: `${CLAUDE_PLUGIN_ROOT}/scripts/vizrender input.typ`
3. The **hook** displays the image inline automatically — you don't need to do anything extra
4. **Reason from .typ source** for iteration — you already know the structure because you wrote it
5. **Only use vision readback** (Read the .png) when you cannot reason about layout from the source alone (e.g., judging aesthetic spacing, verifying visual overlap, confirming color contrast)

## How Display Works

vizrender compiles .typ → SVG → PNG and prints structured output. Since Claude Code captures Bash output as text (escape sequences don't render), a **PostToolUse hook** intercepts the output, extracts the displayed file path, and calls vizshow directly to the terminal. This bypasses Claude Code's output capture.

- **You do NOT need to call vizshow separately** — the hook handles it
- **You do NOT need to read the PNG** to confirm it displayed — trust the hook
- **`--open` flag**: use `vizrender input.typ --open` to open in system viewer as an alternative

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

## Readback: When to Use What

**Default: reason from source.** You wrote the .typ file — you know the structure.

- **Modifying parameters** → you already have the .typ in context, just edit and re-render
- **Checking structure** → grep the .svg XML if you need positions/counts you didn't generate
- **Vision readback** (Read .png) → **only when you cannot reason from source**: aesthetic judgment, verifying visual overlap, confirming colors render correctly, checking that labels are legible at the rendered size

## Iteration Pattern

```
User: "move figure B to the left"
Agent: [already knows the .typ structure — it wrote it]
       [modifies grid layout in .typ]
       [vizrender updated.typ]    ← hook shows it to user
       "Done — panel B is now on the left."
```

No need to read the PNG back — you know what you changed.

## Live Update Pattern

```
# Slow updates (30s+): agent controls the loop
loop:
  data = fetch_from_mcp()
  write data → plot.typ
  vizrender plot.typ              ← hook shows each update

# Fast updates (1-5s): use typst watch
vizrender plot.typ --watch &
loop:
  data = fetch_from_mcp()
  write data → plot.typ
  vizshow output.png              ← manual display for fast mode
```

## Display-Only (no typst)

Show any existing image inline:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/vizshow image.png
```

The hook also catches `[vizshow: ...]` output and re-displays if the escape sequences were captured.

## Troubleshooting

- **typst not found**: Install via `brew install typst` or `cargo install typst-cli`
- **Image doesn't appear**: The PostToolUse hook may not be loaded. Verify with `/hooks`. Use `vizrender input.typ --open` as fallback to open in system viewer.
- **SVG→PNG fails**: Install `librsvg` (`brew install librsvg`) or ImageMagick. Fallback: vizrender compiles directly to PNG.

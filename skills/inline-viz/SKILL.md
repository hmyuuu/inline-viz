---
name: inline-viz
description: >
  Use when the user asks to visualize, plot, diagram, or render
  any scientific figure inline in the terminal. Supports quantum
  circuits, tensor networks, QEC codes, BDDs, Feynman diagrams,
  Bloch spheres, data plots, paper layouts, and pixel art.
---

# Inline Visualization

Render typst diagrams and display them via a floating preview window. The window auto-updates on each render.

## Behavior

Render immediately. No preamble, no narration. Just write the .typ and call vizrender. The image is the response.

## IMPORTANT: Writing .typ Files

**Always write .typ files using Bash** (`cat > file.typ << 'EOF' ... EOF`), **never the Write tool.** These are temporary rendering files. Using Bash avoids "file already exists" errors and lets you write + render in a single call:

```bash
cat > /tmp/diagram.typ << 'EOF'
#set page(width: auto, height: auto, margin: 12pt)
// your typst content here
EOF
${CLAUDE_PLUGIN_ROOT}/scripts/vizrender /tmp/diagram.typ
```

## Quick Start

```bash
# 1. Write a .typ file and render (one Bash call)
cat > /tmp/hello.typ << 'EOF'
#import "@preview/pixel-family:0.1.0": *
#set page(width: auto, height: auto, margin: 12pt)
#alice(size: 3cm)
EOF
${CLAUDE_PLUGIN_ROOT}/scripts/vizrender /tmp/hello.typ
```

Output includes file paths:
```
[vizrender: source=/tmp/hello.typ]
[vizrender: rendered=/tmp/hello.svg]
[vizrender: displayed=/tmp/hello.png]
```

## How Display Works

vizrender compiles .typ → SVG → PNG. Display is automatic:

- **tmux**: auto-opens a vizwatch split pane on first render (kitty/iTerm2 graphics protocol, auto-updates)
- **zellij**: auto-opens a vizwatch floating pane on first render
- **otherwise**: opens the image with `open` (Preview.app on macOS)
- **`--open` flag**: always opens in system viewer
- **`--no-display`**: compile only, no display

## Core Workflow

1. **Write** a `.typ` file via Bash (cat heredoc) — never use the Write tool
2. **Render**: `${CLAUDE_PLUGIN_ROOT}/scripts/vizrender input.typ`
3. The image appears automatically (tmux/zellij split pane, or Preview.app)
4. **Reason from .typ source** for iteration — you already know the structure because you wrote it
5. **Only use vision readback** (Read the .png) when you cannot reason about layout from the source alone (e.g., judging aesthetic spacing, verifying visual overlap, confirming color contrast)

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
       [vizrender updated.typ]    ← floating window updates
       "Done — panel B is now on the left."
```

## Live Update Pattern

```
# Slow updates (30s+): agent controls the loop
loop:
  data = fetch_from_mcp()
  write data → plot.typ
  vizrender plot.typ              ← floating window updates each time

# Fast updates (1-5s): same pattern, floating window handles refresh
```

## Display-Only (no typst)

Show any existing image:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/vizrender --open existing.png
```

## Troubleshooting

- **typst not found**: Install via `brew install typst` or `cargo install typst-cli`
- **Floating window not updating**: Check vizwatch is running (`${CLAUDE_PLUGIN_ROOT}/scripts/vizwatch`)
- **No viewer at all**: Use `vizrender input.typ --open` to open in Preview.app
- **SVG→PNG fails**: Install `librsvg` (`brew install librsvg`) or ImageMagick

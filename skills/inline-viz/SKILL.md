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

# Inline Viz — Quick Reference

## Scripts

| Script | Usage | Key Options |
|--------|-------|-------------|
| `vizshow` | `${CLAUDE_PLUGIN_ROOT}/scripts/vizshow <image>` | `--width N`, `--protocol P`, `--quiet` |
| `vizrender` | `${CLAUDE_PLUGIN_ROOT}/scripts/vizrender <file.typ>` | `--format svg\|png\|pdf`, `--no-display`, `--open` |

## Packages

```typst
#import "@preview/pixel-family:0.1.0": *       // pixel art
#import "@preview/cetz:0.4.2": canvas, draw    // drawing
#import "@preview/cetz-plot:0.1.2": *           // plots
#import "@local/typdd:0.1.0": *                 // BDD
```

## Patterns

Pixel art:
```typst
#set page(width: auto, height: auto, margin: 12pt)
#align(center)[#stack(dir: ltr, spacing: 1cm, alice(size: 2cm), bob(size: 2cm))]
```

Data plot:
```typst
#import "@preview/cetz:0.4.2": canvas
#import "@preview/cetz-plot:0.1.2": *
#set page(width: auto, height: auto, margin: 12pt)
#canvas({ plot.plot(size: (8,5), x-label: $x$, y-label: $y$, {
  plot.add(data)
})})
```

BDD:
```typst
#import "@local/typdd:0.1.0": *
#set page(width: auto, height: auto, margin: 12pt)
#bdd("(a & b) | (a & c) | (b & c)", style: "paper")
```

Template files at `${CLAUDE_PLUGIN_ROOT}/templates/` contain more examples — read them for API reference when needed.

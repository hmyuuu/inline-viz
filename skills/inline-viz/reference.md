# Inline Viz — Template API Reference

## Scripts

| Script | Usage | Key Options |
|--------|-------|-------------|
| `vizshow` | `${CLAUDE_PLUGIN_ROOT}/scripts/vizshow <image>` | `--width N`, `--protocol P`, `--quiet` |
| `vizrender` | `${CLAUDE_PLUGIN_ROOT}/scripts/vizrender <file.typ>` | `--format svg|png|pdf`, `--no-display`, `--width N`, `--open` |

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

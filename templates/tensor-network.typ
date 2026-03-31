#import "@preview/cetz:0.4.2": canvas, draw

/// Draw an MPS chain with labeled bond dimensions.
#let mps(n-sites, bond-dims: (), phys-labels: (), tensor-radius: 0.3) = {
  set page(width: auto, height: auto, margin: 12pt)
  let spacing = 1.5
  canvas({
    import draw: *
    for i in range(n-sites) {
      let x = i * spacing
      circle((x, 0), radius: tensor-radius, fill: rgb("#dbeafe"), stroke: rgb("#3b82f6") + 1pt)
      line((x, 0), (x, -1), stroke: 0.8pt)
      let label = if phys-labels.len() > i { phys-labels.at(i) } else { $s_(#(i+1))$ }
      content((x, -1.3), text(8pt, label))
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
#let honeycomb(rows: 3, cols: 3, couplings: (x: 1, y: 1, z: 0.5), colors: (x: rgb("#ef4444"), y: rgb("#3b82f6"), z: rgb("#22c55e"))) = {
  set page(width: auto, height: auto, margin: 16pt)
  canvas({
    import draw: *
    let dx = 1.5
    let dy = calc.sqrt(3) / 2 * 1.0
    for row in range(rows) {
      for col in range(cols) {
        let cx = col * 3 * dx + calc.rem(row, 2) * 1.5 * dx
        let cy = row * dy * 2
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
          line((x1, y1), (x2, y2), stroke: colors.at(bt) + (strength * 2pt))
        }
        for i in range(6) {
          let a = angles.at(i) * calc.pi / 180
          circle((cx + calc.cos(a), cy + calc.sin(a)), radius: 0.12, fill: luma(60), stroke: none)
        }
      }
    }
  })
}

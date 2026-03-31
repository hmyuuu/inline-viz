#import "@preview/cetz:0.4.2": canvas, draw

#let fermion-line(start, end, label: none) = {
  draw.line(start, end, stroke: 1pt, mark: (end: ">", fill: black))
  if label != none {
    let mid = ((start.at(0) + end.at(0)) / 2, (start.at(1) + end.at(1)) / 2 + 0.3)
    draw.content(mid, text(8pt, label))
  }
}

#let photon-line(start, end, label: none, amplitude: 0.15, periods: 6) = {
  let dx = end.at(0) - start.at(0)
  let dy = end.at(1) - start.at(1)
  let len = calc.sqrt(dx * dx + dy * dy)
  if len == 0 { return }
  let steps = periods * 8
  let points = range(steps + 1).map(i => {
    let t = i / steps
    let wave = amplitude * calc.sin(t * periods * 2 * calc.pi)
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

#let gluon-line(start, end, label: none, amplitude: 0.2, periods: 5) = {
  let dx = end.at(0) - start.at(0)
  let dy = end.at(1) - start.at(1)
  let len = calc.sqrt(dx * dx + dy * dy)
  if len == 0 { return }
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

#let scalar-line(start, end, label: none) = {
  draw.line(start, end, stroke: (paint: black, thickness: 1pt, dash: "dashed"))
  if label != none {
    let mid = ((start.at(0) + end.at(0)) / 2, (start.at(1) + end.at(1)) / 2 + 0.3)
    draw.content(mid, text(8pt, label))
  }
}

#let vertex(pos) = {
  draw.circle(pos, radius: 0.08, fill: black, stroke: none)
}

/// Draw a complete Feynman diagram.
#let feynman-diagram(vertices: (:), propagators: (), page-size: auto) = {
  set page(width: page-size, height: page-size, margin: 16pt)
  canvas({
    import draw: *
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
    for (name, pos) in vertices { vertex(pos) }
  })
}

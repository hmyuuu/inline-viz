#import "@preview/cetz:0.4.2": canvas, draw
#import "@preview/cetz-plot:0.1.2": plot

/// Draw a Bloch sphere with a state trajectory.
/// - trajectory: array of (theta, phi, time) tuples in radians
/// - radius: sphere radius (default: 2)
#let bloch-sphere(trajectory, radius: 2) = {
  canvas({
    import draw: *
    circle((0, 0), radius: radius, stroke: luma(200) + 0.5pt, fill: none)
    line((-radius, 0), (radius, 0), stroke: luma(180) + 0.5pt)
    line((0, -radius), (0, radius), stroke: luma(180) + 0.5pt)
    content((0, radius + 0.3), $|0 chevron.r$)
    content((0, -radius - 0.3), $|1 chevron.r$)
    content((radius + 0.3, 0), $|+ chevron.r$)
    content((-radius - 0.3, 0), $|- chevron.r$)
    if trajectory.len() > 1 {
      for i in range(trajectory.len() - 1) {
        let t1 = trajectory.at(i)
        let t2 = trajectory.at(i + 1)
        let x1 = radius * calc.sin(t1.at(0)) * calc.cos(t1.at(1))
        let y1 = radius * calc.cos(t1.at(0))
        let x2 = radius * calc.sin(t2.at(0)) * calc.cos(t2.at(1))
        let y2 = radius * calc.cos(t2.at(0))
        let frac = i / (trajectory.len() - 1)
        let r = int(calc.round(frac * 255))
        let b = int(calc.round((1 - frac) * 255))
        line((x1, y1), (x2, y2), stroke: rgb(r, 0, b) + 1.5pt)
      }
    }
  })
}

/// Multi-panel optimal control visualization.
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

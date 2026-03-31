#import "@preview/cetz:0.4.2": canvas, draw

/// Internal: draw a surface code lattice using cetz primitives.
/// pos: (x, y) origin tuple
/// size: integer distance (grid is size × size data qubits)
/// point-radius: radius of data qubit dots
/// boundary-bulge: extra spacing for boundary stabilizer indicators
#let _surface-code-draw(pos, size: 3, point-radius: 0.15, boundary-bulge: 0.3) = {
  import draw: *
  let ox = pos.at(0)
  let oy = pos.at(1)

  // Edges (horizontal)
  for xi in range(size - 1) {
    for yi in range(size) {
      line(
        (ox + xi * 1.0, oy + yi * 1.0),
        (ox + (xi + 1) * 1.0, oy + yi * 1.0),
        stroke: rgb("#94a3b8") + 1.5pt,
      )
    }
  }
  // Edges (vertical)
  for xi in range(size) {
    for yi in range(size - 1) {
      line(
        (ox + xi * 1.0, oy + yi * 1.0),
        (ox + xi * 1.0, oy + (yi + 1) * 1.0),
        stroke: rgb("#94a3b8") + 1.5pt,
      )
    }
  }

  // X stabilizers (plaquettes, blue faces)
  for xi in range(size - 1) {
    for yi in range(size - 1) {
      rect(
        (ox + xi * 1.0 + 0.08, oy + yi * 1.0 + 0.08),
        (ox + (xi + 1) * 1.0 - 0.08, oy + (yi + 1) * 1.0 - 0.08),
        fill: rgb("#3b82f625"),
        stroke: rgb("#3b82f6") + 0.75pt,
      )
    }
  }

  // Boundary X stabilizers (top/bottom half-plaquettes)
  for xi in range(size - 1) {
    // bottom boundary
    rect(
      (ox + xi * 1.0 + 0.08, oy - boundary-bulge),
      (ox + (xi + 1) * 1.0 - 0.08, oy - 0.08),
      fill: rgb("#3b82f620"),
      stroke: rgb("#3b82f6") + 0.5pt,
    )
    // top boundary
    rect(
      (ox + xi * 1.0 + 0.08, oy + (size - 1) * 1.0 + 0.08),
      (ox + (xi + 1) * 1.0 - 0.08, oy + (size - 1) * 1.0 + boundary-bulge),
      fill: rgb("#3b82f620"),
      stroke: rgb("#3b82f6") + 0.5pt,
    )
  }

  // Z stabilizers (vertices, red circles)
  for xi in range(size - 1) {
    for yi in range(size - 1) {
      circle(
        (ox + xi * 1.0 + 0.5, oy + yi * 1.0 + 0.5),
        radius: 0.2,
        fill: rgb("#ef444420"),
        stroke: rgb("#ef4444") + 0.75pt,
      )
    }
  }

  // Boundary Z stabilizers (left/right half-circles)
  for yi in range(size - 1) {
    // left boundary
    circle(
      (ox - boundary-bulge * 0.5, oy + yi * 1.0 + 0.5),
      radius: 0.18,
      fill: rgb("#ef444420"),
      stroke: rgb("#ef4444") + 0.5pt,
    )
    // right boundary
    circle(
      (ox + (size - 1) * 1.0 + boundary-bulge * 0.5, oy + yi * 1.0 + 0.5),
      radius: 0.18,
      fill: rgb("#ef444420"),
      stroke: rgb("#ef4444") + 0.5pt,
    )
  }

  // Data qubits (drawn last, on top)
  for xi in range(size) {
    for yi in range(size) {
      circle(
        (ox + xi * 1.0, oy + yi * 1.0),
        radius: point-radius,
        fill: rgb("#1e293b"),
        stroke: rgb("#e2e8f0") + 1pt,
      )
    }
  }
}

/// Draw a surface code with optional error and correction overlays.
/// - size: distance of the surface code (lattice is size × size data qubits)
/// - errors: array of (col, row) positions where bit-flip errors occurred;
///   shown as red circle overlays
/// - corrections: array of ((c0,r0),(c1,r1)) pairs; blue lines between syndromes
/// - highlight-logical: if true, draw an orange horizontal logical operator
/// - point-radius: radius of data qubit dots (default 0.15)
/// - boundary-bulge: protrusion of boundary stabilizer indicators (default 0.3)
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

    // Draw the base lattice
    _surface-code-draw(
      (0, 0),
      size: size,
      point-radius: point-radius,
      boundary-bulge: boundary-bulge,
    )

    // Error overlays (red circles)
    for e in errors {
      circle(
        (e.at(0) * 1.0, e.at(1) * 1.0),
        radius: 0.25,
        fill: rgb("#ff000040"),
        stroke: rgb("#ff0000") + 2pt,
      )
    }

    // Correction lines (blue lines between paired syndromes)
    for c in corrections {
      let start = c.at(0)
      let end = c.at(1)
      line(
        (start.at(0) * 1.0, start.at(1) * 1.0),
        (end.at(0) * 1.0, end.at(1) * 1.0),
        stroke: rgb("#3b82f6") + 2.5pt,
      )
    }

    // Logical operator highlight (orange horizontal line)
    if highlight-logical {
      line(
        (-0.5, calc.floor(size / 2) * 1.0),
        (size * 1.0 - 0.5, calc.floor(size / 2) * 1.0),
        stroke: rgb("#f59e0b") + 3pt,
      )
    }
  })
}

/// Mark syndrome measurement outcomes on an existing cetz canvas context.
/// Call this inside a canvas block after drawing the lattice.
/// - syndromes: array of (col, row, type) where type is "X" or "Z"
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

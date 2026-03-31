#import "@preview/cetz:0.4.2": canvas
#import "@preview/cetz-plot:0.1.2": plot

#let line-plot(data, x-label: $x$, y-label: $y$, title: none, size: (8, 5)) = {
  set page(width: auto, height: auto, margin: 12pt)
  if title != none {
    align(center, text(11pt, weight: "bold", title))
    v(4pt)
  }
  canvas({
    plot.plot(size: size, x-label: x-label, y-label: y-label, {
      plot.add(data)
    })
  })
}

#let scatter(data, x-label: $x$, y-label: $y$, title: none, size: (8, 5)) = {
  set page(width: auto, height: auto, margin: 12pt)
  if title != none {
    align(center, text(11pt, weight: "bold", title))
    v(4pt)
  }
  canvas({
    plot.plot(size: size, x-label: x-label, y-label: y-label, {
      plot.add(data, mark: "o", style: (stroke: none))
    })
  })
}

#let multi-plot(series, x-label: $x$, y-label: $y$, title: none, size: (8, 5)) = {
  set page(width: auto, height: auto, margin: 12pt)
  if title != none {
    align(center, text(11pt, weight: "bold", title))
    v(4pt)
  }
  canvas({
    plot.plot(size: size, x-label: x-label, y-label: y-label, {
      for s in series {
        plot.add(s.at(0), label: s.at(1))
      }
    })
  })
}

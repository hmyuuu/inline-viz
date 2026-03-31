#let figure-panel(panels, columns: 2, gutter: 12pt) = {
  set page(width: auto, height: auto, margin: 12pt)
  let cells = panels.map(p => {
    let (label, content) = p
    box(
      inset: 4pt,
      [
        #text(10pt, weight: "bold")[(#label)]
        #v(2pt)
        #content
      ]
    )
  })
  grid(
    columns: range(columns).map(_ => auto),
    gutter: gutter,
    ..cells
  )
}

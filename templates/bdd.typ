#import "@local/typdd:0.1.0": bdd

/// Render a single BDD from a boolean expression.
#let bdd-single(expr, style: "paper", labels: (:), ..args) = {
  set page(width: auto, height: auto, margin: 12pt)
  bdd(expr, style: style, labels: labels, ..args)
}

/// Render two BDDs side by side with different variable orderings for comparison.
#let bdd-compare(expr, orderings: (), style: "paper", labels: (:)) = {
  set page(width: auto, height: auto, margin: 12pt)
  let diagrams = orderings.map(order => {
    box(
      stroke: 0.5pt + luma(200),
      inset: 8pt,
      radius: 4pt,
      [
        #align(center, text(9pt, fill: luma(100))[Order: #order.join(" > ")])
        #v(4pt)
        #bdd(expr, style: style, labels: labels, order: order)
      ]
    )
  })
  align(center,
    stack(dir: ltr, spacing: 1.5cm, ..diagrams)
  )
}

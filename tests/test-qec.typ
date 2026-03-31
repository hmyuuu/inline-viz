#import "../templates/qec.typ": *

// Distance-3 surface code with error overlays, correction lines,
// and highlighted logical operator.
#qec-surface(
  3,
  errors: ((1, 0), (1, 2)),
  corrections: (((1, 0), (1, 2)),),
  highlight-logical: true,
)

#import "@preview/pixel-family:0.1.0": *

/// Compose pixel art characters in a horizontal scene.
/// - characters: array of content (e.g., alice(size: 2cm), bob(size: 2cm))
/// - spacing: horizontal gap between characters (default: 1cm)
/// - caption: optional text below the scene
#let scene(characters, spacing: 1cm, caption: none) = {
  set page(width: auto, height: auto, margin: 12pt)
  align(center,
    stack(dir: ltr, spacing: spacing, ..characters)
  )
  if caption != none {
    v(8pt)
    align(center, text(11pt, caption))
  }
}

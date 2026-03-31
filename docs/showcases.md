# Inline Viz — Showcase Examples

Run these inside Claude Code with the plugin loaded:

```bash
claude --plugin-dir /Users/hmyuuu/workspace/inline-viz
```

Or after installing via marketplace:
```bash
/plugin install inline-viz@hmyuuu-skills
```

---

## 1. Pixel Art (Smoke Test)

```
Show me Alice and Bob as pixel art characters. Write a .typ file using
@preview/pixel-family:0.1.0, set page to auto size, display them side by
side with a caption "Quantum Key Exchange". Render inline with vizrender.
```

## 2. BDD — Majority Function

```
Draw a BDD for the majority function: (a & b) | (a & c) | (b & c).
Write a .typ file importing @local/typdd:0.1.0, use style "paper".
Render inline with vizrender. Then render a second one with reversed
variable ordering (c, b, a) and show both side by side so I can
compare the node counts.
```

## 3. QEC — Surface Code

```
Draw a distance-5 surface code lattice. Mark errors at positions
(1,2) and (3,1) with red circles, and draw a blue correction chain
connecting them. Also draw an orange line for the logical operator
across the middle. Use the qec template and render inline.
```

## 4. Tensor Network — MPS Chain

```
Draw a 6-site MPS tensor network for a Heisenberg chain. Label the
bond dimensions as χ = 4, 8, 16, 8, 4 between sites. Label physical
indices as s₁ through s₆. Use CeTZ and render inline with vizrender.
```

## 5. Tensor Network — Kitaev Honeycomb

```
Draw a honeycomb lattice for the Kitaev model with Kx=1.0, Ky=1.0,
Kz=0.5. Color-code the three bond types: red for Kx, blue for Ky,
green for Kz. Make line width proportional to coupling strength.
Use the tensor-network template and render inline.
```

## 6. Quantum Control — Bloch Sphere

```
Show a Bloch sphere with a trajectory for a π/2 rotation from |0⟩
to |+⟩. The trajectory should have 20 points, going from θ=0 to
θ=π/2 at φ=0. Color gradient from blue (t=0) to red (t=T).
Use the quantum-control template and render inline.
```

## 7. Quantum Control — Multi-Panel

```
Show a multi-panel optimal control visualization:
- Panel A: Bloch sphere with a π rotation trajectory (θ: 0→π)
- Panel B: Control pulses — a Gaussian Ω_I pulse (peak 125 MHz, 20ns)
  and a DRAG Ω_Q correction
Use the control-panel function from quantum-control template.
Render inline with vizrender.
```

## 8. Feynman Diagram — QED Vertex Correction

```
Draw the 1-loop vertex correction in QED:
- 3 vertices forming a triangle
- 2 external fermion lines (incoming p, outgoing p')
- 1 external photon line (incoming γ with momentum q)
- 3 internal fermion propagators forming the loop
Use the feynman template with proper line styles (straight for
fermions, wavy for photon). Label all momenta. Render inline.
```

## 9. Data Plot — Sine Wave

```
Plot sin(x) from 0 to 2π with 50 data points. Label axes as
t and f(t). Title it "Signal Response". Use the plot template
and render inline with vizrender.
```

## 10. Data Plot — Multi-Series

```
Plot two series on the same axes:
- Series 1: sin(x) labeled "Signal"
- Series 2: cos(x) labeled "Reference"
From 0 to 2π with 30 points each. Use multi-plot from the plot
template. Render inline.
```

## 11. Paper Layout — Multi-Panel Figure

```
Create a 2x2 multi-panel figure with panels labeled (a), (b), (c), (d).
- Panel a: a simple sine wave plot
- Panel b: a cosine wave plot
- Panel c: text "Phase diagram placeholder"
- Panel d: text "Error rates placeholder"
Use the paper-layout template. Render inline with vizrender.
```

## 12. Display-Only — Show Existing Image

```
Use vizshow to display an existing PNG file at
/Users/hmyuuu/workspace/inline-viz/tests/test-pixel-art.png
directly in the terminal, without typst compilation.
```

## 13. Iterative Refinement

```
Draw a 4-site MPS with bond dimensions 2, 4, 2. Then I'll ask you
to modify it. Render inline first, then wait for my feedback.
```

(After seeing the output, say things like:)
```
Make the bond dimension labels bigger and change the tensor node
color from blue to purple. Re-render and show me.
```

## 14. SVG Readback

```
Render a distance-3 surface code using the qec template. After
rendering, read back the SVG file and tell me how many circle
elements are in the SVG (to verify the qubit count).
```

## 15. Vision Readback

```
Render the Kitaev honeycomb lattice with the tensor-network template.
After rendering, read back the PNG file and tell me if the three
bond colors (red, blue, green) are visually distinguishable.
```

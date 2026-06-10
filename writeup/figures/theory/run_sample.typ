#import "@preview/cetz:0.5.0": canvas, draw

#figure(caption: "Example Composed Machine Run", placement: none)[

#scale(x: 80%, y: 80%, reflow: true)[#canvas({
  import draw: *

  // 1. GRID VARIABLES
    // Adjust these to make the box wider or taller
    let start-x = 0
    let end-x = 18
    let top-y = 3.5
    let bottom-y = -3

  // Draws from the leftmost center (Inputs) to the rightmost center (Outputs)
    rect(
      (start-x, bottom-y), 
      (end-x, top-y), 
      name: "bg", 
      fill: luma(240), 
      stroke: 2pt
    )
  
  // Title
    content(
      "bg.north-east", 
      anchor: "north-east", 
      padding: 0.2, 
      text(size: 11pt)[run *$#[Start] bullet #[Produce] A bullet #[Produce] B bullet #[Combine] A and B$*]
    )

  // 3. INPUTS (Left Edge)
  // Placed at X = start-x so they straddle the left border perfectly
  content((start-x, 0), name: "in1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Begin \ Process])

  // 4. INTERNAL STEPS (Middle)
  // Placed freely between start-x and end-x
  content((3, 0), name: "step1", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[Start])

  content((6, 1.5), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Create \ $A$])

  content((6, -1.5), name: "place2", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Create \ $B$])

  // Connect any named node to any other named node
  line("in1", "step1", name: "edge1", mark: (end: ">", fill: black), stroke: 2pt)
  
  line("step1", "place1", name: "edge2", mark: (end: ">", fill: black), stroke: 2pt)
  line("step1", "place2", name: "edge3", mark: (end: ">", fill: black), stroke: 2pt)

  content((9, 1.5), name: "step3", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[Produce \ $A$])

  content((12, 1.5), name: "place3", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Produced \ $A$])

  line("place1", "step3.west", name: "edge4", mark: (end: ">", fill: black), stroke: 2pt)

  // Failure case
  line("step3", "place3", name: "edge5", mark: (end: ">", fill: black), stroke: 2pt)


  content((9, -1.5), name: "step3", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[Produce \ $B$])

  content((12, -1.5), name: "place4", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Produced \ $B$])

  line("place2", "step3.west", name: "edge4", mark: (end: ">", fill: black), stroke: 2pt)

  // Failure case
  line("step3", "place4", name: "edge5", mark: (end: ">", fill: black), stroke: 2pt)

  content((15, 0), name: "step2", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[Combine \ $A and B$])

  // 5. OUTPUTS (Right Edge)
  // Placed at X = end-x so they straddle the right border perfectly
  content((end-x, 0), name: "out1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Combined])

  // 6. EDGES
  
  line("place3", "step2", name: "edge3", mark: (end: ">", fill: black), stroke: 2pt)
  line("place4", "step2", name: "edge3", mark: (end: ">", fill: black), stroke: 2pt)


  line("step2", "out1", name: "edge6", mark: (end: ">", fill: black), stroke: 2pt)
})]

] <example-machine-run>

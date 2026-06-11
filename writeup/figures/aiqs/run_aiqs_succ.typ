#import "@preview/cetz:0.5.0": canvas, draw

#figure(caption: "AIQS Check Quality run", placement: none)[#align(center)[
  #scale(x: 80%, y: 80%, reflow: true)[#canvas({
    import draw: *

    // 1. GRID VARIABLES
    // Adjust these to make the box wider or taller
    let start-x = 0
    let end-x = 12
    let top-y = 3.5
    let bottom-y = 0

    // 2. THE BACKGROUND BOX
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
      text(size: 11pt)[run *AIQS Check Quality success*]
    )

    // 3. INPUTS (Left Edge)
    // Placed at X = start-x so they straddle the left border perfectly
    content((start-x, 1.5), name: "in1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Finish \ AIQS \ Pick ])

    // 4. INTERNAL STEPS (Middle)
    // Placed freely between start-x and end-x
    content((3, 1.5), name: "step1", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[AIQS \ Check ])

    content((6, 1.5), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[AIQS \ Checking])

    content((9, 1.5), name: "step2", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[AIQS \ Checked ])

    // 5. OUTPUTS (Right Edge)
    // Placed at X = end-x so they straddle the right border perfectly
    content((end-x, 1.5), name: "out1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Start \ AIQS \ Drop])


    // 6. EDGES
    // Connect any named node to any other named node
    line("in1", "step1", name: "edge1", mark: (end: ">", fill: black), stroke: 2pt)
    content("edge1", [#v(12pt) x])

    
    line("step1", "place1", name: "edge2", mark: (end: ">", fill: black), stroke: 2pt)
    line("place1", "step2", name: "edge3", mark: (end: ">", fill: black), stroke: 2pt)


    // Failure case

    
    line("step2", "out1", name: "edge6", mark: (end: ">", fill: black), stroke: 2pt)
  })
]]] <aiqs-check-run>
#import "@preview/cetz:0.5.0": canvas, draw

#let steps_mill = align(center)[#scale(x: 80%, y: 80%, reflow: true)[#canvas({
      import draw: *

      // 1. GRID VARIABLES
      // Adjust these to make the box wider or taller
      let start-x = 0
      let end-x = 6
      let top-y = 2
      let bottom-y = -1.5

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
        text(size: 11pt)[step *MILL Mill*]
      )

      // 3. INPUTS (Left Edge)
      // Placed at X = start-x so they straddle the left border perfectly
      content((start-x, 0), name: "in1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Finish \ MILL \ Pick ])

      // 4. INTERNAL STEPS (Middle)
      // Placed freely between start-x and end-x
      content((3, 0), name: "step1", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[MILL \ Mill ])

      content((6, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[MILL \ Milling])

      // 6. EDGES
      // Connect any named node to any other named node
      line("in1", "step1", name: "edge1", mark: (end: ">", fill: black), stroke: 2pt)
      
      line("step1", "place1", name: "edge2", mark: (end: ">", fill: black), stroke: 2pt)
    })
  ]]

#let step_success = align(center)[
  #scale(x: 80%, y: 80%, reflow: true)[#canvas({
    import draw: *

    // 1. GRID VARIABLES
    // Adjust these to make the box wider or taller
    let start-x = 6
    let end-x = 12
    let top-y = 2
    let bottom-y = -1.5

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
      text(size: 11pt)[step *MILL Milled*]
    )

    content((6, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[MILL \ Milling])

    content((9, 0), name: "step2", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[MILL \ Milled])

    // 5. OUTPUTS (Right Edge)
    // Placed at X = end-x so they straddle the right border perfectly
    content((end-x, 0), name: "out1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Start \ MILL \ Drop])

    // 6. EDGES
    
    line("place1", "step2", name: "edge3", mark: (end: ">", fill: black), stroke: 2pt)
    
    line("step2", "out1", name: "edge6", mark: (end: ">", fill: black), stroke: 2pt)
  })
]]

#figure(caption: "MILL Mill steps")[

#grid(
  columns: (1fr, 1fr),
  gutter: 10pt,
  rows: (auto),
  steps_mill,
  step_success,
)

#align(center)[
  #scale(x: 80%, y: 80%, reflow: true)[#canvas({
    import draw: *

    // 1. GRID VARIABLES
    // Adjust these to make the box wider or taller
    let start-x = 6
    let end-x = 12
    let top-y = 2
    let bottom-y = -1.5

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
      text(size: 11pt)[step *MILL Mill Failed*]
    )


    content((6, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[MILL \ Milling])


    content((9,0), name: "step3", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[MILL Mill \ Failed])

    // 5. OUTPUTS (Right Edge)
    // Placed at X = end-x so they straddle the right border perfectly
    content((end-x, 0), name: "out3", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Order \ Failed])

    // 6. EDGES
    // Connect any named node to any other named node

    line("place1", "step3.west", name: "edge4", mark: (end: ">", fill: black), stroke: 2pt)

    // Failure case
    line("step3", "out3", name: "edge5", mark: (end: ">", fill: black), stroke: 2pt)
  })
]]
] <mill-mill-steps>

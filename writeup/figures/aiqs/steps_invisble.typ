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
        text(size: 11pt)[step *AIQS invisible start*]
      )

      // 3. INPUTS (Left Edge)
      // Placed at X = start-x so they straddle the left border perfectly
      content((start-x, 0), name: "in1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Next \ Module \ Ready ])

      // 4. INTERNAL STEPS (Middle)
      // Placed freely between start-x and end-x
      content((3, 0), name: "step1", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[AIQS \ invisible \ start ])

      content((6, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[AIQS \ Start \ Pick])

      // 6. EDGES
      // Connect any named node to any other named node
      line("in1", "step1", name: "edge1", mark: (end: ">", fill: black), stroke: 2pt)
      content("edge1", [#v(12pt) x])
      
      line("step1", "place1", name: "edge2", mark: (end: ">", fill: black), stroke: 2pt)
      content("edge2", [#v(12pt) x])
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
      text(size: 11pt)[step *AIQS invisble finish*]
    )

    content((6, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Finish \ AIQS \ Drop])

    content((9, 0), name: "step2", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[AIQS \ invisible \ finish])

    // 5. OUTPUTS (Right Edge)
    // Placed at X = end-x so they straddle the right border perfectly
    content((end-x, 0), name: "out1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Next \ Module \ Ready])

    // 6. EDGES
    
    line("place1", "step2", name: "edge3", mark: (end: ">", fill: black), stroke: 2pt)
    content("edge3", [#v(12pt) x])


    
    line("step2", "out1", name: "edge6", mark: (end: ">", fill: black), stroke: 2pt)
    content("edge6", [#v(12pt) x])
  })
]]

#figure(caption: "AIQS Invisble steps")[

#grid(
  columns: (1fr, 1fr),
  gutter: 10pt,
  rows: (auto),
  steps_mill,
  step_success,
)

] <invisible-aiqs-steps>

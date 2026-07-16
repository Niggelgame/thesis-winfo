#import "@preview/cetz:0.5.0": canvas, draw

#figure(caption: "AGV step template", placement: none)[
  #align(center)[
  #scale(x: 80%, y: 80%, reflow: true)[#canvas({
    import draw: *

    // 1. GRID VARIABLES
    // Adjust these to make the box wider or taller
    let start-x = 0
    let end-x = 6
    let top-y = 2
    let bottom-y = -2

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
      text(size: 11pt)[step *AGV move `M1` to `M2`*]
    )

    // 3. INPUTS (Left Edge)
    // Placed at X = start-x so they straddle the left border perfectly
    content((start-x, 0), name: "in1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[AGV \ at `M1`])

    // 4. INTERNAL STEPS (Middle)
    // Placed freely between start-x and end-x
    content((3, 0), name: "step1", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[AGV move\ `M1` to `M2`])

    content((6, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[AGV\ at `M2`])


    // 6. EDGES
    // Connect any named node to any other named node
    line("in1", "step1", mark: (end: ">", fill: black), stroke: 2pt)
    
    line("step1", "place1", name: "edge1", mark: (end: ">", fill: black), stroke: 2pt)
    // content("edge1", name: "edge1-label", [#v(16pt) y])
  })
]]
  
] <move-agv-step>
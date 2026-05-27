#import "@preview/cetz:0.5.0": canvas, draw

#figure(caption: "AGV steps", placement: none)[
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
      text(size: 11pt)[step *move AGV*]
    )

    // 3. INPUTS (Left Edge)
    // Placed at X = start-x so they straddle the left border perfectly
    content((start-x, 0), name: "in1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[#h(20pt) #v(20pt)])
    content("in1.south-east", name: "in1-label", [#v(25pt) #h(20pt) #block[AGV\ at]])

    // 4. INTERNAL STEPS (Middle)
    // Placed freely between start-x and end-x
    content((3, 0), name: "step1", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[#h(20pt) #v(20pt)])
    content("step1.south-east", name: "step1-label", [#v(30pt)AGV \ move(y)])

    content((6, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[#h(20pt) #v(20pt)])
    content("place1.south-east", name: "place1-label", [#v(20pt) #h(45pt) #align(right)[#block[#align(left)[AGV\ moved]]]])


    // 6. EDGES
    // Connect any named node to any other named node
    line("in1", "step1", mark: (end: ">", fill: black), stroke: 2pt)
    
    line("step1", "place1", name: "edge1", mark: (end: ">", fill: black), stroke: 2pt)
    content("edge1", name: "edge1-label", [#v(16pt) y])
  })
]]
  #align(center)[
  #scale(x: 80%, y: 80%, reflow: true)[#canvas({
    import draw: *

    // 1. GRID VARIABLES
    // Adjust these to make the box wider or taller
    let start-x = 5.5
    let end-x = 11.5
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
      text(size: 11pt)[step *dock AGV*]
    )

    // 3. INPUTS (Left Edge)


    content((5.5, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[#h(20pt) #v(20pt)])
    content("place1.south-east", name: "place1-label", [#v(20pt) #h(45pt) #align(right)[#block[#align(left)[AGV\ moved]]]])

    content((8.5, 0), name: "step2", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[#h(20pt) #v(20pt)])
    content("step2.south-east", name: "step2-label", [#v(30pt)AGV \ docks(y)])

    // 5. OUTPUTS (Right Edge)
    // Placed at X = end-x so they straddle the right border perfectly
    content((end-x, 0), name: "out1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[#h(20pt) #v(20pt)])
    content("out1.south-east", name: "out1-label", [#v(20pt) #h(45pt) #align(right)[#block[#align(left)[AGV\ at]]]])


    // 6. EDGES
    // Connect any named node to any other named node

    line("place1", "step2", name: "edge2", mark: (end: ">", fill: black), stroke: 2pt)
    content("edge2", name: "edge2-label", [#v(16pt) y])
    
    line("step2", "out1", name: "edge3", mark: (end: ">", fill: black), stroke: 2pt)
    content("edge3", name: "edge3-label", [#v(16pt) y])
  })
]]
] <move-agv-step>
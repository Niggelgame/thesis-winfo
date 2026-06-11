#import "@preview/cetz:0.5.0": canvas, draw

#figure(caption: "Direct Module Interaction Modelling Approach", placement: none)[

#align(center)[
  #scale(x: 80%, y: 80%, reflow: true)[#canvas({
    import draw: *

    // 1. GRID VARIABLES
    // Adjust these to make the box wider or taller
    let start-x = 5.5
    let end-x = 12.5
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
      text(size: 11pt)[step *direct mill to drill*]
    )


    content((start-x, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Finish \ MILL \ Drop])


    content((9,0), name: "step3", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[MILL then \ DRILL])

    // 5. OUTPUTS (Right Edge)
    // Placed at X = end-x so they straddle the right border perfectly
    content((end-x, 0), name: "out3", frame: "circle", fill: white, stroke: 2pt, padding: 0.2, align(center)[Start \ DRILL \ Pick])

    // 6. EDGES
    // Connect any named node to any other named node

    line("place1", "step3.west", name: "edge4", mark: (end: ">", fill: black), stroke: 2pt)

    // Failure case
    line("step3", "out3", name: "edge5", mark: (end: ">", fill: black), stroke: 2pt)

  })
]]
] <direct-connect-drill-mill-step>
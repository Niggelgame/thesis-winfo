#import "@preview/cetz:0.5.0": canvas, draw

#let generate_implicit_start_and_end_for = (module, start_act: "Pick", end_act: "Drop") => {
  let steps_start = align(center)[
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
      text(size: 11pt)[step *#module Start*]
    )

    content((6, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.1, align(center)[Next \ Module \ Ready])

    content((9, 0), name: "step2", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[#module \ Start])

    // 5. OUTPUTS (Right Edge)
    // Placed at X = end-x so they straddle the right border perfectly
    content((end-x, 0), name: "out1", frame: "circle", fill: white, stroke: 2pt, padding: 0.1, align(center)[Start \ #module \ #start_act])

    // 6. EDGES
    
    line("place1", "step2", name: "edge3", mark: (end: ">", fill: black), stroke: 2pt)


    
    line("step2", "out1", name: "edge6", mark: (end: ">", fill: black), stroke: 2pt)
  })
]]

  let steps_end = align(center)[#scale(x: 80%, y: 80%, reflow: true)[#canvas({
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
        text(size: 11pt)[step *#module End*]
      )

      // 3. INPUTS (Left Edge)
      // Placed at X = start-x so they straddle the left border perfectly
      content((start-x, 0), name: "in1", frame: "circle", fill: white, stroke: 2pt, padding: 0.1, align(center)[Finish \ #module \ #end_act ])

      // 4. INTERNAL STEPS (Middle)
      // Placed freely between start-x and end-x
      content((3, 0), name: "step1", frame: "rect", fill: white, stroke: 2pt, padding: 0.4, align(center)[#module \ End ])

      content((6, 0), name: "place1", frame: "circle", fill: white, stroke: 2pt, padding: 0.1, align(center)[Next \ Module \ Ready])

      // 6. EDGES
      // Connect any named node to any other named node
      line("in1", "step1", name: "edge1", mark: (end: ">", fill: black), stroke: 2pt)
      
      line("step1", "place1", name: "edge2", mark: (end: ">", fill: black), stroke: 2pt)
    })
  ]]

  return (steps_start, steps_end)
}

#figure(caption: "Implicit Control steps", placement: none)[
  #let (drill_start, drill_end) = generate_implicit_start_and_end_for("DRILL")
  #let (mill_start, mill_end) = generate_implicit_start_and_end_for("MILL")
  #let (aiqs_start, aiqs_end) = generate_implicit_start_and_end_for("AIQS")
  #let (dps_pick_start, dps_pick_end) = generate_implicit_start_and_end_for("DPS Pick", start_act: "", end_act: "")
  #let (dps_drop_start, dps_drop_end) = generate_implicit_start_and_end_for("DPS Drop", start_act: "", end_act: "")
  #let (hbw_pick_start, hbw_pick_end) = generate_implicit_start_and_end_for("HBW Pick", start_act: "", end_act: "")
  #let (hbw_drop_start, hbw_drop_end) = generate_implicit_start_and_end_for("HBW Drop", start_act: "", end_act: "")

#grid(
  columns: (1fr, 1fr),
  gutter: 10pt,
  rows: (auto),
  drill_start,
  drill_end,
  mill_start, mill_end,
  aiqs_start, aiqs_end,
  dps_pick_start, dps_pick_end,
  dps_drop_start, dps_drop_end,
  hbw_pick_start, hbw_pick_end,
  hbw_drop_start, hbw_drop_end
)
] <implicit-connect-steps>
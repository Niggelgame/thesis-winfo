#import "@preview/benplate:0.1.0": note, todo
#import "@preview/cetz:0.5.0": canvas, draw

= Modelling

We want to evaluate our process prediction technique on the Fischer-Technik *Agile Production Simulator* #footnote[#link("https://www.fischertechnik.de/de-de/industrie-und-hochschulen/technische-dokumente/simulieren/agile-production-simulation")]. Prior to the evaluation, we want to set the theoretical foundation of _what_ the predictions mean. We do this by modelling the Heraklit @heraklit steps required to represent process models#note[Explain the Heraklit step modeling in background before] . These steps are later on predicted by our technique, thus it is crucial to have a clear understanding of what they represent and how they are defined.

These steps can be grouped by the relevant factory modules:

- Automated Guided Vehicle (*AGV*): It autonomously transports workpieces between factory modules. 
- High-Bay Warehouse (*HBW*): It serves as a storage system to the factory, designed with an automatic retrieval. 
- Delivery And Pickup Station (*DPS*): It serves as the point of input and output of the factory. New workpieces are _inserted_ here, processed workpieces are _shipped off_. The included NFC reader starts the tracking of workpieces across the factory.
- Drilling Station (*DRILL*): It performs a simulated drilling operation on the workpieces, picking them up from and dropping them onto the AGV.
- Milling Station (*MILL*): It performs a simulated milling operation on the workpieces, picking them up from and dropping them onto the AGV.
- Quality Control with AI (*AIQS*): Checks the quality of a workpiece using a camera and color sensor. If a failure occurred - represented by a erroneous print on the workpiece - the workpiece is discarded.
- Central Control Unit (*CCU*): It is the central controller of the factory. While it has no physical representation in the factory, it is the centralized decision maker of the factory, synchronizing the different distributed modules. Thus for our modelling purposes, it will be the *glue* that connects the modules together, while ensuring different processes for different piece types. 

== Heraklit Step Modelling

=== AGV


#include "figures/agv/steps.typ"

#include "figures/agv/run.typ"

These atomic steps are modeled with the variables and domains defined as ```
variable
y: process-module

domain
process-module: {DPS, HBW, DRILL, MILL, AIQS}
```

Important to notice is that the `AGV move` step transition is non-deterministic, as it does not consume the variable from the previous place, the input `AGV at`. It does however pass this decided variable onto the remaining parts of the process.

This will be relevant to ensure that the steps in the other modules can depend on the decision made in the `AGV move` step, as they depend on the AGVs position.

@move-agv-run shows the composition of the two step atoms, showing the typical run that can be found in the factory logs.


=== HBW

#grid(
  columns: (1fr, 1fr),
  rows: (auto),
  include "figures/hbw/steps_pick.typ",
  include "figures/hbw/steps_drop.typ"
)



#include "figures/hbw/system_pick.typ"
#include "figures/hbw/system_drop.typ"


In the steps regarding the HBW actions in @pick-hbw-steps and @drop-hbw-steps, we introduce the new variable `x`, defined as follows.

```
variable
x: workpiece

domain
workpiece: {blue, red, green}
```

The pattern of passing around the workpiece variable `x` will continue to appear in most other processing steps. This variable allows us to configure the processing steps to depend on the type of workpiece being processed, which is crucial to ensure that the process prediction technique can learn to correctly predict the processing of different workpieces across the factory.


The HBW Pick system model (@pick-hbw-system) takes a workpiece from the AGV and stores it in the warehouse. The HBW Drop system model (@drop-hbw-system) performs the reverse operation, thus dropping a workpiece into the AGV. 

Both system models are very similar, as they perform a similar operation, just in reverse. Surprisingly there is not much logic involved, as we decided to not model the explicit HBW state here, i.e. leaving out what is stored where. 

=== DPS

The DPS needs to insert pieces into the factory and ship them out of the factory. The piece insertion into the factory is represented by a `DPS Drop`, dropping the piece onto the AGV from the loading bay. The shipping out of the factory by `DPS Pick`, picking the piece up from the AGV and dropping it off at the loading bay. Both steps are reading and writing to the NFC Tag on the piece, if present, providing a history of the piece across the factory. Similarly to the physical actuator control done by the Siemens SPS, we choose to not model the NFC tag explicitly, as the prediction will be on a higher level of abstraction. 

Notably, the `DPS Drop` system (@drop-dps-system) contains the only step that can introduce a new workpiece into the factory, thus it is the only step that can introduce a new variable assignment to `x`, as it is the only step that can introduce a new workpiece into the process. The remaining process steps will look similar to other upcoming Pick and Drop steps, however they will not be able to change or introduce the workpiece variable assignment.

Notice how the @drop-dps-steps contains a failure case, where drop can fail. While most other failures will result in the order failing, at this point we don't have an active order with any part yet - the was just about the be arriving in our factory. Thus we only model it as a failed drop, the CCU will need to decide how to handle this failure, e.g. by retrying the drop or by cancelling operations.

#grid(
  columns: (1fr, 1fr),
  rows: (auto),
  include "figures/dps/steps_drop.typ",
  include "figures/dps/steps_pick.typ"
)

#include "figures/dps/system_drop.typ"
#include "figures/dps/system_pick.typ"



=== DRILL

The drill module also has to interact with the AGV, thus we also introduce Pick (@pick-drill-steps) and Drop (@drop-drill-steps) steps for the drilling station. Additionally, the module can also perform a certain module-specific action, in this case the simulated drilling of a hole into the workpiece (@drill-drill-steps). The variables follow the same definitions as in previous module definitions.

The Pick and Drop step definitions are defined completely analogous up to renaming to the ones of the HBW. We will see the same pattern in the coming modules as well, as the picking and droppping interactions with the AGV appear in all modules.

However, the drilling step is unique to the drill module, performing the actual processing of the worpiece at that station. 

The typical compositions can be seen in @pick-drill-system, @drop-drill-system and @drill-drill-system. These system models combined provide a top-level view on the drilling station process.

// Steps
#grid(
  columns: (1fr, 1fr),
  rows: (auto),
  include "figures/drill/steps_drop.typ",
  include "figures/drill/steps_pick.typ"
)
#include "figures/drill/steps_drill.typ"

// System Models
#include "figures/drill/system_pick.typ"
#include "figures/drill/system_drop.typ"
#include "figures/drill/system_drill.typ"



=== MILL

The mill module performs the same function as the drill, only changing the simulated action to milling a groove into the workpiece instead of drilling.

Thus it contains the steps for picking (@pick-mill-steps), dropping (@drop-mill-steps) and milling (@mill-mill-steps). The system models are defined in @pick-mill-system, @drop-mill-system and @mill-mill-system.


#grid(
  columns: (1fr, 1fr),
  rows: (auto),
  include "figures/mill/steps_drop.typ",
  include "figures/mill/steps_pick.typ"
)
#include "figures/mill/steps_mill.typ"

#include "figures/mill/system_pick.typ"
#include "figures/mill/system_drop.typ"
#include "figures/mill/system_mill.typ"

=== AIQS

The last physical module is the AIQS, which provides a quality control checkpoint for all orders. Using a camera and a color sensor, it can detect faults (printed onto the pieces) and then discard faulty pieces into a trash chute, while passing good pieces on. 

As with the previous two processing stations, it also contains Pick (@pick-aiqs-steps) and Drop (@drop-aiqs-steps) steps. Additionally, it implements its Check Quality (@check-quality-aiqs-steps) steps. The system models are defined in @aiqs-pick-system, @aiqs-drop-system and @aiqs-check-quality-system.

#grid(
  columns: (1fr, 1fr),
  rows: (auto),
  include "figures/aiqs/steps_drop.typ",
  include "figures/aiqs/steps_pick.typ"
)
#include "figures/aiqs/steps_check_quality.typ"

#include "figures/aiqs/system_pick.typ"
#include "figures/aiqs/system_drop.typ"
#include "figures/aiqs/system_check_quality.typ"

=== CCU

The CCU is the heart of the factory. It controls the interactions between the modules, taking the decisions on where the AGV should go and interacting with the factory owner.

During modelling, we will focus on the control interactions between the modules and the AGV management. This is *implicit* control. There is no control transition token to be found in the MQTT logs, the control can just be inferred from the interactions between the modules. 
This means that the CCU steps will not be present in the prediction tokens. However, they are crucial for validation or potential synthetic generation of runs.

To understand the CCU's role, we can look a the different CCU steps in a typical run. On a newly arriving piece, the CCU needs to instruct the modules to put it into the HBW.
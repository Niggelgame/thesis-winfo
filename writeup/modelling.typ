#import "@preview/benplate:0.1.0": note, todo
#import "@preview/cetz:0.5.0": canvas, draw
#import "lib.typ": *

= Modelling<modelling>

This section marks the beginning of our case study, showcasing the approach of using Heraklit and the Transformer architecture to perform next-step process prediction.

We want to evaluate our process prediction technique on the Fischertechnik *Agile Production Simulator* @fischertechnik. As required by our definition of what a correct prediction is (#ref_def("Correct Prediction")), we will first need to translate events of the APS into Heraklit @heraklit steps. These steps should crucially allow the modelling of concurrency within the system by only modelling the causal relationships of events.

While some domain knowledge is necessary for this step, still only step modules need to be created, not full system process models. As these steps are predicted by our technique, having a clear understanding of what each step represents is useful during further evaluation.

We can split and group the steps by the relevant factory modules:

- Automated Guided Vehicle (*AGV*): It autonomously transports workpieces between factory modules. 
- High-Bay Warehouse (*HBW*): It serves as a storage system to the factory, designed with an automatic retrieval. 
- Delivery And Pickup Station (*DPS*): It serves as the point of input and output of the factory. New workpieces are _inserted_ here, processed workpieces are _shipped off_. The included NFC reader starts the tracking of workpieces across the factory.
- Drilling Station (*DRILL*): It performs a simulated drilling operation on the workpieces, picking them up from and dropping them onto the AGV.
- Milling Station (*MILL*): It performs a simulated milling operation on the workpieces, picking them up from and dropping them onto the AGV.
- Quality Control with AI (*AIQS*): Checks the quality of a workpiece using a camera and color sensor. If a failure occurred - represented by a erroneous print on the workpiece - the workpiece is discarded.
- Central Control Unit (*CCU*): It is the central controller of the factory. While it has no physical representation in the factory, it is the centralized decision maker of the factory, synchronizing the different distributed modules. Thus for our modelling purposes, it will be the glue that connects the modules together.

== Heraklit Step Modelling

=== AGV

We start by modelling the AGV. It is the main source of interaction in the APS, however it can only perform one action by itself, which is moving from one processing module to the next. As we want to have one token per step, we need to create multiple *move AGV* steps.

For each module $#[`M1`] in {"DPS, HBW, DRILL, MILL, AIQS"} := M$ we need to have a move step to each module $#[`M2`] in M \\ {m}$. Thus in the following step module template, we get all possible *move AGV* steps by instantiating `M1` and `M2` with all possible combinations.


#include "figures/agv/steps.typ"

A keen reader with might realize that this could be modeled using a parameterized module, an advanced Heraklit concept not introduced in @theory. As no further parameterization was necessary in the remaining modelling, the introduction, definitions and complexity can be reduced by showcasing the template steps instead. For the sake of completeness, the step module as a parameterized module is shown below.

#include "figures/agv/steps_param.typ"

This type of modelling requires defining variables and domains as ```
variable
y: process-module

domain
process-module: {DPS, HBW, DRILL, MILL, AIQS}
```

Important to notice is that depending on which *AGV move* step is taken, different step modules depending on the AGV position can be composed afterwards. This however also ensures that modules can depend on the AGV being at their module, locking them at that position by temporarily consuming the token at the `AGV at MOD` place.

=== Picking and Dropping

All other modules need to phsycially interact with the remaining factory by picking up workpieces from the AGV or dropping workpieces onto the AGV. This workflow is generally the same over all modules, thus to reduce wasted space, we again fall back to modelling these steps using the following template, with #block(breakable: false)[$#[`MOD`] in {"DPS, HBW, DRILL, MILL, AIQS"}$]

#grid(
  columns: (1fr, 1fr),
  rows: (auto),
  include "figures/pick_drop/steps_pick.typ",
  include "figures/pick_drop/steps_drop.typ"
)

Two points should be highlighted:
1. We are modelling failure modes. In case the action fails, the respective `Pick Failed` or `Drop Failed` can be composed instead of the `Picked` or `Dropped` successful counterpart.
2. The AGV is not able to move while the picking or dropping action is performed, as it consumes the token at `AGV at MOD` token.

Next we will look at the individual process module actions.

#todo[Process Module changes (:]
#todo[Add the other modules to the appendix anyways?]

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

Our goal is to model the steps extractable from the Fischertechnik MQTT Logs. These control steps, deciding what module action happens after the next, is *implicit* or *invisble* control. There is no control transition token to be found in the MQTT logs, the control can just be inferred from the interactions between the modules. 
This means that the CCU steps will not be present in the prediction tokens. 

For a potential synthetic generation of runs modelling the different variations of runs, e.g. depending on the color of the workpiece, one could argue that these control steps must be meticulously designed. This would imply pre-modelling a specific order of module actions into the steps via the connecting places. An example can be seen in @direct-connect-drill-mill-step. 

#include "figures/direct_connect_drill_mill.typ"

This approach has multiple downsides. We trade the increased detail for *decreased flexibility*, as changes in the configuration for certain workpieces would require a new Heraklit step model. More importantly though, the tools to validate model outputs would need to be capable of handling an *exponential number of steps* with increases in configurations and length of runs. As these control steps are not to be found within the logs, all matching control steps must be tried to be appended at any point of the validation, creating a huge search tree for validation.

We therefore decide not to model all the configurations explicitly. Instead, we only restrict our model to allow one module action to take place at a time. While this might seem counter-intuitive when looking at the distributed factory setting, here we are only looking at the factory execution from the perspective of a singular workpiece. Since all parts of a singular workpiece are always only present in one module action, these actions don't need to be able to run concurrently. 

#include "figures/implicit_connect_drill_mill.typ"

Technically, this restriction is applied by creating a global place called `Next Module Ready`. Whenever a module wants to start, it needs to consume this place, whenever it is finished, it will fill the place again. Following the example from before, this creates the new steps in @implicit-connect-drill-mill. 

This new design does not directly solve the issue of these control steps missing in the logs, but provides a simple solution. By composing $"DRILL Dropped" circle.small "Implicit DRILL end"$ and $"Implicit MILL start" circle.small "MILL Pick"$ it essentially just changes the interfaces of the module steps to have the `Next Module Ready` place instead of their respective `Start` and `Finish` places. These newly composed models can be then again composed directly via the `Next Module Ready`. As we know that before and after all module actions their steps will need their one matching `Implicit` step, we can pre-compose the control and module steps when talking about the actual logs.

For example, if the logs contain the steps

`DRILL Dropped` #h(112pt) $arrow$ #h(118pt) `MILL Pick`

we can instead interpret this as 

`DRILL Dropped` $arrow$ `Implicit DRILL end` $arrow$ `Implicit MILL start` $arrow$ `MILL Pick`

as the implicit steps can be directly inferred.

At this point, one might wonder why we have not directly put the `Next Module Ready` step into the module steps. The reason for this decision is that we can keep the level of detail on the module basis, while essentially just having an interface wrapper to simplify implementation details later.
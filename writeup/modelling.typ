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
- Delivery and Pickup Station (*DPS*): It serves as the point of input and output of the factory. New workpieces are _inserted_ here, processed workpieces are _shipped off_. The included NFC reader starts the tracking of workpieces across the factory.
- Drilling Station (*DRILL*): It performs a simulated drilling operation on the workpieces, picking them up from and dropping them onto the AGV.
- Milling Station (*MILL*): It performs a simulated milling operation on the workpieces, picking them up from and dropping them onto the AGV.
- Quality Control with AI (*AIQS*): Checks the quality of a workpiece using a camera and color sensor. If a failure occurred - represented by a erroneous print on the workpiece - the workpiece is discarded.
- Central Control Unit (*CCU*): It is the central controller of the factory. While it has no physical representation in the factory, it is the centralized decision maker of the factory, synchronizing the different distributed modules. Thus for our modelling purposes, it will be the glue that connects the modules together.

== Heraklit Step Modelling

=== AGV

We start by modelling the AGV. It is the main source of interaction in the APS, however it can only perform one action by itself, which is moving from one processing module to the next. As we want to have one token per step, we need to create multiple *move AGV* steps.

For each module $#[`M1`] in {"DPS, HBW, DRILL, MILL, AIQS"} := M$ we need to have a move step to each module $#[`M2`] in M \\ {m}$. Thus in the following step module template, we get all possible *move AGV* steps by instantiating `M1` and `M2` with all possible combinations.


#include "figures/agv/steps.typ"

A keen reader might realize that this could be modeled using a parameterized module, an advanced Heraklit concept not introduced in @theory. As no further parameterization was necessary in the remaining modelling, the introduction, definitions and complexity can be reduced by showcasing the template steps instead. For the sake of completeness, the step module as a parameterized module is shown below.

#include "figures/agv/steps_param.typ"

This type of modelling requires defining variables and domains as ```
variable
y: process-module

domain
process-module: {DPS, HBW, DRILL, MILL, AIQS}
```

Important to notice is that depending on which *AGV move* step is taken, different step modules depending on the AGV position can be composed afterwards. This however also ensures that modules can depend on the AGV being at their module, locking them at that position by temporarily consuming the token at the `AGV at MOD` place.

=== Picking and Dropping

All other modules need to physically interact with the remaining factory by picking up workpieces from the AGV or dropping workpieces onto the AGV. This workflow is generally the same over all modules, thus to reduce wasted space, we again fall back to modelling these steps using the following template, with #block(breakable: false)[$#[`MOD`] in {"DPS, HBW, DRILL, MILL, AIQS"}$]

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

=== HBW

The High-Bay Warehouse actions only consist of picking up workpieces from the AGV and putting them into storage, and of dropping workpieces from storage onto the AGV. 

This might seem like actions that require a lot of control, first due to needing to select what workpiece should be extracted from storage, and second due to storage management itself.

However, the Fischertechnik simplified both control challenges by 

1. only looking at the current running order that the pick or drop action is associated with, figuring out what color it refers to and then 
2. performing a _First-In First-Out_ (FIFO) storage policy for all colors, keeping the mapping of colors to ordered storage slots persistent.

Thus when executing a pick or drop, it can do so without any further information. We decide to not try to model the internal (unexposed) storage logic here, as no events are emitted through the MQTT logs and therefore no step can be mapped to it. The generic `MOD Pick` and `MOD Drop` actions defined in @pick-steps-template and @drop-steps-template can be reused here.

A successful HBW pick run can be seen in @pick-hbw-run, a failed HBW pick @pick-hbw-run-fail.


#include "figures/hbw/run_pick_succ.typ"
#include "figures/hbw/run_pick_fail.typ"


They are clearly defined by composing the singular pick steps:

$&#[*HBW Pick success*] &= &#[*HBW Pick*] bullet #[*HBW Picked*] \
&#[*HBW Pick failure*] &= &#[*HBW Pick*] bullet #[*HBW Pick Failed*]$

These runs are exemplary for all module `Pick` and `Drop` runs, as they always follow the same structure. 

=== DPS

The DPS is responsible for insertion of pieces into the factory and shipping them out of the factory. The piece insertion into the factory is represented by a `DPS Drop`, dropping the workpiece onto the AGV from the loading bay. The shipping out of the factory by `DPS Pick`, picking the workpiece up from the AGV and dropping it off at the loading bay. 

Both actions are reading and writing to the NFC tag on the workpiece, if present, providing a history of the piece across the factory. Similarly to the physical actuator control done by the Siemens SPS, we choose to not model the NFC tag explicitly, as the prediction will be on a higher level of abstraction. Thus, we can again re-use the template for Picking and Dropping given in the templates in @pick-steps-template and @drop-steps-template.

Notably, the `DPS Drop` step is the only step that can introduce a new workpiece into the factory. New workpieces are generally first stored into the HBW and then extracted again with an order, even if an order for that piece is already present. 

The failure case of a `DPS Drop` could require different processing than other dropping steps, as this is the only action where a workpiece might not have an order associated to it yet. However, as we are only processing single workpieces at a time in our dataset, the order failure case is an appropriate failure model, as either way the processing of that workpiece ends there.

We do not need to introduce any additional new steps, as again the abstraction given through the MQTT traces does not provide further details.


=== DRILL

Like all other physical modules, the drill process module has to interact with the AGV to process workpieces. Therefore the `Pick` and `Drop` template is defined for it as well.

Additionally, this is the first module to perform a certain module-specific action observable via the MQTT logs. This unique action is simulated drilling of a hole into the workpiece, which can again succeed or fail. The matching Heraklit step definitions can be seen in @drill-drill-steps. Notice that 

1. We require a workpiece to be picked up from the AGV to be able to start the drill action by consuming the token at the place `Finish DRILL Pick`.
2. We do not require the AGV to be at the drill module during the drilling steps, opening up the future possibility of having multiple modules process workpieces simultaneously within the same model, as the AGV can drive to a different station during processing at the drill.

#include "figures/drill/steps_drill.typ"

Both of these properties can be re-discovered in the following module-specific step-definitions.

While there is a parameter for the drilling duration defined for each workpiece color, we decide to not model it due to two reasons. First, the parameter is constant and thus just belongs directly to the drilling operation of that color. Second, even assuming it was not constant, there is no causal relationship to be learned as to why the duration should be different. The Fischertechnik APS provides no simulated tool wear or different operation durations for simulated broken or working workpieces.

We again provide a successful run in @drill-drill-run and a failed run in @drill-drill-run-failure, composed of:

$&#[*DRILL Drill success*] &= &#[*DRILL Drill*] bullet #[*DRILL Drilled*] \
&#[*DRILL Drill failure*] &= &#[*DRILL Drill*] bullet #[*DRILL Drill Failed*]$


#include "figures/drill/run_drill_succ.typ"
#include "figures/drill/run_drill_fail.typ"




=== MILL


Similarly to the drill, the mill process module performs a simulated action, but it is an operation to simulate milling a groove into the workpiece instead of the drilling operation. It again also contains the template `Pick` and `Drop` steps. 

Thus the steps are defined identically modulo renaming in @mill-mill-steps. Thus the same properties hold and the runs can be composed in a similar fashion as in @drill-drill-run and @drill-drill-run-failure.

#include "figures/mill/steps_mill.typ"

=== AIQS

The last physical module is the AIQS, which provides a quality control checkpoint for all orders. To simulate failure within the APS, workpieces inserted into the factory at the DPS are designated `fail` or `pass` pieces, determined by a print on top of the piece. Using a camera and a color sensor, it can detect these faults and then discard faulty pieces into a trash chute, while passing good pieces on. 

Besides the `Pick` and `Drop` steps, the AIQS needs to perform this quality check action. The matching steps are defined in @check-quality-aiqs-steps.

#include "figures/aiqs/steps_check_quality.typ"

In the Fischertechnik APS, only the AIQS is concerned with the failure of a piece, all other pieces are processed based on just the color. This makes the behaviour of the next step after a started quality check hard to predict: The piece must either fail or pass, but the previous process execution provides no indication of whether the workpiece "processed" will result in a failure or not. This is a shortcoming in the simulation of the APS, as especially tool wear and processing durations could be exploited to simulate a failing processing module on a piece, such that a prediction has some grounds to base its decision on. 

We will later see that this results in missed accuracy of our prediction model.

A composed success run of the AIQS can be seen in @aiqs-check-run, the failure in @aiqs-check-run-failed.

#include "figures/aiqs/run_aiqs_succ.typ"
#include "figures/aiqs/run_aiqs_fail.typ"


=== CCU

The CCU is the heart of the factory. It controls the interactions between the modules, taking the decisions on where the AGV should go and interacting with the factory order system via the UI.

Our goal is to model the steps extractable from the Fischertechnik MQTT Logs. These control steps, deciding what module action happens after the next, is *implicit* or *invisible* control. There is no control action token to be found in the MQTT logs that clearly defines _after action X perform action Y_, the control can just be inferred from the interactions between the modules. 
This means that the CCU steps will and can not be present in the prediction tokens, as they do not exist within the logs. However, we still need to model some control system, as the steps of different modules are not composable at the moment.

For a potential synthetic generation of runs modelling the different variations of runs, e.g. depending on the color of the workpiece, one could argue that these control steps must be meticulously designed, including the order of stations per workpiece type. This would imply pre-modelling a specific order of module actions into the steps via the connecting places. An example can be seen in @direct-connect-drill-mill-step. Here we provide the fixed connection of a `MILL` step to the `DRILL` step.

#include "figures/direct_connect_drill_mill.typ"

This approach has multiple downsides. We trade the increased detail for *decreased flexibility*, as changes in the configuration for certain workpieces would require a new Heraklit step model. More importantly though, the tools to validate model outputs would need to be capable of handling an *exponential number of steps* to support all different process configurations, with increases in modules, and again exponential growth with length of runs. This is due to these control steps not being present within the logs, so all matching control steps must be tried to be appended at any point of the validation, creating a huge search tree for validation.

We therefore decide not to model all the configurations explicitly. Instead, we only restrict our model to allow one module action to take place at a time. While this might seem counter-intuitive when looking at the distributed factory setting, here we are only looking at the factory execution from the perspective of a singular workpiece. Since all processing parts of a singular workpiece are always only present in one processing module's action, these actions don't need to be able to run concurrently. 

Technically, this restriction is applied by creating a global shared place called `Next Module Ready`. Whenever a module wants to start, it needs to consume this place, whenever it is finished, it will fill the place again. Following the example from before, this creates the new steps in @implicit-connect-drill-mill. 

#include "figures/implicit_connect_drill_mill.typ"

This new design does not directly solve the issue of these control steps missing in the logs, but provides a simple solution. By composing $"DRILL Dropped" bullet "Implicit DRILL end"$ and $"Implicit MILL start" bullet "MILL Pick"$ we create a run module that essentially just changes the interfaces of the module steps to have the `Next Module Ready` place instead of their respective `Start` and `Finish` places. These newly composed models can be then again composed directly via the `Next Module Ready`. 

As we know that before and after all module actions their steps will need their one matching `Implicit` step, we can pre-compose the control and module steps when talking about the actual logs.

For example, if the logs contain the steps

`DRILL Dropped` #h(112pt) $arrow$ #h(118pt) `MILL Pick`

we can instead interpret this as 

`DRILL Dropped` $arrow$ `Implicit DRILL end` $arrow$ `Implicit MILL start` $arrow$ `MILL Pick`

as the implicit steps can be directly inferred.

At this point, one might wonder why we have not directly put the `Next Module Ready` step into the module steps. The reason for this decision is that we can keep the level of detail on the module basis, while essentially just having an interface wrapper to simplify implementation details later.

All the implicit control steps, that are implicitly composed with the respective `Start` and `Finish` steps of the processing modules can be found in @implicit-connect-steps. Notably, the DRILL, MILL and AIQS only connect a start module on the `Pick` action and a stop module on the `Drop` action. The DPS and HBW however can independently Pick and Drop without any ongoing action in between, so both `Pick` and `Drop` actions have their own implicit start and stop control.

For the further processing we then also redefine the following step modules as runs composed with their implicit control step:

#{
  let generate_implicit_start_and_end_for = (module, start_act: "Pick", end_act: "Drop") => {
    $& module #start_act &:= &#module "Start" bullet #module #start_act\ 
    & module#{if end_act == "" {if module.ends-with("Drop") { "ped"} else {"ed"}} else { " "}}#end_act &:= & module#{if end_act == "" {if module.ends-with("Drop") { "ped"} else {"ed"}} else { " "}}#end_act bullet #module "End" #v(25pt)$
  }

  $#generate_implicit_start_and_end_for("DRILL") \
  #generate_implicit_start_and_end_for("MILL") \
  #generate_implicit_start_and_end_for("AIQS") \
  #generate_implicit_start_and_end_for("DPS Pick", start_act: "", end_act: "") \
  #generate_implicit_start_and_end_for("DPS Drop", start_act: "", end_act: "") \
  #generate_implicit_start_and_end_for("HBW Pick", start_act: "", end_act: "") \
  #generate_implicit_start_and_end_for("HBW Drop", start_act: "", end_act: "") $
}

Since runs can be composed the same way individual step modules can, we do not require further differentiation and can *assume from now on, that the starting and stopping "steps" can be composed via the `Next Module Ready` place*.

#include "figures/all_implicit_control.typ"
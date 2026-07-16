#import "@preview/benplate:0.1.0": note, todo

= Introduction<introduction>


Traditionally, discovering knowledge about business processes required combining estimates and manual data collection. This acquired knowledge would then be used to analyze, redesign and optimize said processes or to make process-external decisions @ppm26. This type of knowledge discovery is naturally error-prone and tends to be time-consuming.

Nowadays, more and more businesses rely on enterprise systems to store highly detailed process execution information, based on sensor outputs, workflow data and machine logs. By applying various process mining techniques to these datasets, crucial knowledge can be extracted @procmining16, which can then be used in multiple business process lifecycles @bpmlifecycle. During process _design_, analysis of historical data can provide comparison points, during process _monitoring_ outliers and bottlenecks can be detected. 

A subfield of process monitoring is predictive process monitoring. It is focused on predicting the behavior of process executions under certain conditions. It can then provide information about the business goals, such as expected failure rates or execution time. If a process is structured into multiple events, _next-event prediction_ is concerned about the next event's activity or surrounding metadata. Here, machine learning approaches have been on the rise, from using LSTMs @lstmref1 @lstmref2 to modified transformer architectures @transformerpred1 @transformerpred2.

Predictive process monitoring needs to face certain challenges. In modern environments, process executions are inherently concurrent. As a result, given a running process execution, *the* next event is not clearly defined: Due to the parallel execution multiple actions could be executed at the same time, or in an arbitrary order depending on system load. While a linear log collected by an enterprise system might exist, due to the parallel execution this order should not be fully enforced onto predictions. 
As an example, if two machines need to produce $A$ and $B$, and then a third machine combines them, the imaginary prediction trace 

$ #[`Produce`] B -> #[`Produce`] A -> #[`Combine`] A and B$


does not necessarily conflict with

$ #[`Produce`] A -> #[`Produce`] B -> #[`Combine`] A and B$

However, there does exist a partial order of events within a process due to causal relationships between the events. Following the example from before, clearly

$#[`Combine`] A and B -> #[`Produce`] A -> #[`Produce`] B$

is not feasible, as one cannot combine non-existing products. 

In this work, we present an approach to use transformer networks to solve the next event prediction problem, while working around the concurrency uncertainty by modeling it using the Heraklit infrastructure @heraklit. 

// Heraklit provides a well-defined process semantics, especially regarding the comparison of process runs by 

We evaluate this approach on the Fischertechnik *Agile Production Simulator* (APS) #footnote[#link("https://www.fischertechnik.de/de-de/industrie-und-hochschulen/technische-dokumente/simulieren/agile-production-simulation")], providing the tools for end-to-end prediction. We extract process logs directly from the internal MQTT broker and then fit and train the model based on derived Heraklit steps. The model achieves an outstanding 91.07% mean accuracy on single next-event prediction. Even when simulating noisy MQTT logs by removing events or adding random events into the logs, similar results can still be achieved. // #todo[Fill in latest results]

The structure of the thesis can be summarized as follows. @theory introduces the necessary background on Heraklit, Transformers and MQTT while providing information on theoretical prediction approach.

@modelling then explains the chosen modeling approach of the Fischertechnik APS case study using Heraklit. Continuing into the technical details, @implementation provides a deeper dive into the details of the applied approach and the Fischertechnik data. 

The case study model is lastly evaluated in @evaluation in various scenarios, before drawing conclusions, and discussing limitations and future work in @conclusion.

// #todo[Now present my approach!]

// Existing Problem, how we try to solve it, sneak peek at results and roadmap.


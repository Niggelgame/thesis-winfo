#import "@preview/benplate:0.1.0": note, todo
#import "lib.typ": *

= Implementation<implementation>

This chapter provides the technical details of the implementation of our process prediction technique with encompassing information on the data collection, preprocessing and on the architecture and training of the final model.

While the chapter will describe what we do and how we do it, it explicitly does not explain how to technically execute the code infrastructure. This information is available through a collection of _Markdown files_ that provide a walkthrough the project code, including the commands to execute in the command line. 

For our implementation we rely on several tools:

- `python`#footnote[#link("https://www.python.org") _last accessed: 11.06.2026_]: The programming language used for the code infrastructure and scripts.
- `uv`#footnote[#link("https://docs.astral.sh/uv/") _last accessed: 11.06.2026_]: A Python project and package manager handling the other listed dependencies and tools.
- `pytorch`#footnote[#link("https://docs.pytorch.org/docs/2.12/index.html") _last accessed: 11.06.2026_]: An optimized python library for deep learning. It supports training on CPUs and GPUs, including integrated GPUs such as ones used in Apple Silicon processors. We use it to build our models by using integrated base models or layers, and to perform the training.
- `numpy`#footnote[#link("https://numpy.org") _last accessed: 11.06.2026_]: An optimized python library for array programming, such as tensors. This is also implicitely used by `pytorch`, and we use it to interact with data to and from `pytorch`.
- `graphviz`#footnote[#link("https://graphviz.readthedocs.io/en/stable/") _last accessed: 11.06.2026_]: A library for a graph drawing software for python. We use it to visualize Heraklit runs.

The implementation was tested on both _macOS 15.7_ and _Ubuntu Linux 24.04_. The hardware used for training and evaluation consists of an _Apple MacBook Pro_ with an _M1 Pro_ chip and _32GB_ of memory.

== Data Collection and Preprocessing

In a first step, the data needs to be _extracted_ from the Fischertechnik APS. As described in  @mqtt-theory, MQTT consists of _publishers_ and _subscribers_, that communicate via a broker. We add an additional client to the broker by connecting a computer to the APS network, that runs a script that subscribes to all topics, using a wildcard subscription ("\*"). It will be therefore sent a copy of every message in the APS. 

Whenever it then receives a message, the message is decoded, combined with the MQTT topic and the timestamp of the receiving computer, then dumped to a file in _JSON_ format. This format is chosen as the messages sent through the broker are all in a _JSON_ format already.

We *captured* the data of 10#note[change to the final number of runs] runs. Each run consists of a single workpiece being processed throughout the APS, from the insertion to the factory at the DPS up to either the successful delivery at the DPS or a failed quality control. 

Before any further processing, all JSON log files are read, checked for valid JSON syntax and then *combined* into one dataset of around 60MB#note[change to final size]. Here we also extract the color of the processed piece and pass it into the metadata.

Next, we perform some *preliminary filtering*, essentially removing the messages regarding two topics: The first one contains the raw image data of the camera mounted on the APS, wasting space in the logs. The second one removes a single action that makes sure a status LED is blinking. This removes 5298 and 1996 messages respectively, reducing the dataset size to only around 14MB. 

The camera data could be interesting for future work, so we decided to still collect it, even though we will not make any use of them here.

The next step contains the proper *preprocessing* of the trace data. Here, we analyse the messages themselves to *extract the tokens*, which represent the Heraklit steps modelled in @modelling. Note that these steps are assumed to already be implicitely composed with the control steps of @implicit-connect-steps.

We can distinguish 3 different message types relevant to our modelling based on the MQTT topic:
#pagebreak()

- `module/v1/ff/<SERIAL>/order`: This topic contains messages from the CCU to the respective module with the serial number `<SERIAL>`. These *order messages* contain the instructions to a module to start a certain action.

- `module/v1/ff/<SERIAL>/state`: This topic contains messages from the module with the serial number `<SERIAL>` to the CCU. These *state messages* are regularly transmitted and contain the state of an action in the module. 

- `fts/v1/ff/<SERIAL>`: This topic contains all messages related to the *AGV* with serial number `<SERIAL>`. It is again split into `/order`and `/state` messages, however for our modelling only the AGV _orders_ are relevant. 

We start by creating a mapping of serial numbers to module types, to handle the different module actions.
We can then usually extract the start of a new action and thus the `Start X` step from our model through the module *order messages*. For the result of an action, we need to listen to the *state messages*, until we need to find one that describes the status of the module as finished or failed to extract the next correct step.

Due to the QoS levels of MQTT and the retained messages of the APS MQTT broker, we need to apply some heuristics to filter out duplicate or old messages. This could have been partially avoided by also writing the MQTT `dup` flag of messages into the logs. However we would still need to figure out whether we received a message before or not regardless.

The then *extracted tokens* are written to a new processed JSON file. We additionally add some metadata to the tokens for analysis purposes, such as the message the time was sent from a module, the time it was received, the module serial number and message IDs.

Lastly, we perform a random split of our tokenized traces into 7 training and 3 validation#note[change to final numbers] traces. Concerns regarding dependent traces within training and validation datasets as presented by #cite(<generalisation>, form: "prose"), are not relevant, as all our executions in the APS are independent of another. This would change if we run multiple APSs in parallel or have multiple workpieces processed at the same time.

The two tokenized trace sets are then written to two files. We ensure, that from now on the model training process does not interact with the validation data.

#pagebreak()

== Heraklit Prefix Checker

In #ref_def("Correct Prediction") we define what constitutes a correct prediction based on potential next steps (#ref_def("Next Step")). This definition, while easily understandable, has the caveat of not being written in a computationally simple way. 

Following the definition directly, given a _reference_ Heraklit run, and a second _checker_ Heraklit run, to check whether the _checker_ run is a prefix of the _reference_ run, we would need to model all possible suffixes and then check, whether they are equal. 

However, by the composition calculus (#ref_def("Graph Composition")) we know that the two sequences of compositions are equal and represent the same run, if composition produces the same graph. Following from that, a _checker_ sequence of compositions is a prefix of a _reference_ sequence of compositions, if the composition graph of the _checker_ is a *graph prefix* of the _reference_ composition graph.

We define $A$ as a *graph prefix* of $B$ , if the _initial nodes_ (here: nodes without incoming edges) of $A$ are a subset of the _initial nodes_ of $B$ and if $A$ from these _initial nodes_ is a subgraph of $B$. 

We limit our initial nodes to only contain unique labels, as otherwise all possible initial node mappings must be explored, which is computationally expensive. This theoretical limit does not provide any limitations in practise, as proper runs on a single workpiece never contain multiple initial steps of the same type.

#line()

We built a tool and python library around this concept, which processes two sequences of predefined steps and checks, whether one is the prefix of the other. To ensure the correctness of the tool, an extensive test suite is created and passes.

Thus, given a reference run $r$, a prefix $p$ of it and a prediction $n$ made by our model, we check the correctness of this prediction by using this tool, asking whether $p bullet n$ is a prefix of $r$.

== Model Architecture 

-> embedder

== Training Details

training: Adam optimizer, regularization using dropout.

time to train
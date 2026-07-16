#import "@preview/benplate:0.1.0": note, todo
#import "lib.typ": *

= Implementation<implementation>

This chapter provides the technical details of the implementation of our process prediction technique with encompassing information on the data collection, preprocessing and on the architecture and training of the final model.

While the chapter will describe what we do and how we do it, it explicitly does not explain how to technically execute the code infrastructure. This information is available through a collection of _Markdown files_ that provide a walkthrough the project code, including the commands to execute in the command line. 

For our implementation we rely on several tools:

- `python`#footnote[#link("https://www.python.org") _last accessed: 11.06.2026_]: The programming language used for the code infrastructure and scripts.
- `uv`#footnote[#link("https://docs.astral.sh/uv/") _last accessed: 11.06.2026_]: A Python project and package manager handling the other listed dependencies and tools.
- `pytorch`#footnote[#link("https://docs.pytorch.org/docs/2.12/index.html") _last accessed: 11.06.2026_]: An optimized python library for deep learning. It supports training on CPUs and GPUs, including integrated GPUs such as ones used in Apple Silicon processors. We use it to build our models by using integrated base models or layers, and to perform the training.
- `numpy`#footnote[#link("https://numpy.org") _last accessed: 11.06.2026_]: An optimized python library for array programming, such as tensors. This is also implicitly used by `pytorch`, and we use it to interact with data to and from `pytorch`.
- `graphviz`#footnote[#link("https://graphviz.readthedocs.io/en/stable/") _last accessed: 11.06.2026_]: A library for a graph drawing software for python. We use it to visualize Heraklit runs.

The implementation was tested on both _macOS 15.7_ and _Ubuntu Linux 24.04_. The hardware used for training and evaluation consists of an _Apple MacBook Pro_ with an _M1 Pro_ chip and _32GB_ of memory.

== Data Collection and Preprocessing<data-col-and-proc>

In a first step, the data needs to be _extracted_ from the Fischertechnik APS. As described in  @mqtt-theory, MQTT consists of _publishers_ and _subscribers_, that communicate via a broker. We add an additional client to the broker by connecting a computer to the APS network, that runs a script that subscribes to all topics, using a wildcard subscription ("\*"). It will be therefore sent a copy of every message in the APS. 

Whenever it then receives a message, the message is decoded, combined with the MQTT topic and the timestamp of the receiving computer, then dumped to a file in _JSON_ format. This format is chosen as the messages sent through the broker are all in a _JSON_ format already.

We *captured* the data of 10// #note[change to the final number of runs]
runs. Each run consists of a single workpiece being processed throughout the APS, from the insertion to the factory at the DPS up to either the successful delivery at the DPS or a failed quality control. 

Before any further processing, all JSON log files are read, checked for valid JSON syntax and then *combined* into one dataset of around 60MB//#note[change to final size]
. Here we also extract the color of the processed piece and pass it into the metadata.

Next, we perform some *preliminary filtering*, essentially removing the messages regarding two topics: The first one contains the raw image data of the camera mounted on the APS, wasting space in the logs. The second one removes a single action that makes sure a status LED is blinking. This removes 5298 and 1996 messages respectively, reducing the dataset size to only around 14MB. 

The camera data could be interesting for future work, so we decided to still collect it, even though we will not make any use of them here.

The next step consists of the proper *preprocessing* of the trace data. Here, we analyse the messages themselves to *extract the tokens*, which represent the Heraklit steps modelled in @modelling. Note that these extracted steps are assumed to already be implicitly composed with the control steps of @implicit-connect-steps.

We can distinguish 3 different message types relevant to our modelling based on the MQTT topic:
#pagebreak()

- `module/v1/ff/<SERIAL>/order`: This topic contains messages from the CCU to the respective module with the serial number `<SERIAL>`. These *order messages* contain the instructions to a module to start a certain action.

- `module/v1/ff/<SERIAL>/state`: This topic contains messages from the module with the serial number `<SERIAL>` to the CCU. These *state messages* are regularly transmitted and contain the state of an action in the module. 

- `fts/v1/ff/<SERIAL>`: This topic contains all messages related to the *AGV* with serial number `<SERIAL>`. It is again split into `/order`and `/state` messages, however for our modelling only the AGV _orders_ are relevant. 

We start by creating a mapping of serial numbers to module types, to handle the different module actions.
We can then usually extract the start of a new action and thus the `Start X` step from our model through the module *order messages*. For the result of an action, we need to listen to the *state messages*, until we need to find one that describes the status of the module as finished or failed to extract the next correct step. 

Due to the QoS levels of MQTT and the retained messages of the APS MQTT broker, we need to apply some heuristics to filter out duplicate or old messages. This could have been partially avoided by also writing the MQTT `dup` flag of messages into the logs. However we would still need to figure out whether we received a message before or not regardless.

Notably, a different modelling of our steps would change the MQTT processing in a significant way. This could be supporting duplicate messages in the modelling itself, changing the level of detail of each step or changing the step definitions themselves. If duplicate messages are supported in the steps, there is no need for duplicate filtering. With increased detail within a step or new step definitions, more metadata can be extracted from the MQTT messages themselves, such as the workpiece ID, intermediate processing states or the machine configuration.  With more details comes the need to be able to predict this detail of the next steps as well.

Possibly, increased levels of detail would also require a different encoding of the tokens. Different encodings are discussed in @model-architecture.

The then *extracted tokens* are written to a new processed JSON file. We additionally add some metadata to the tokens for analysis purposes, such as the message the time was sent from a module, the time it was received, the module serial number and message IDs.

The 10 extracted tokenized traces consist of an average of 23,1 steps, with a minimum of 19 and a maximum of 31 steps. It consists of 4 traces of white workpieces, and 3 traces of red and blue workpieces each. For each color, it contains successful and failed runs.

Lastly, we perform a random split of our tokenized traces into 7 training and 3 validation//#note[change to final numbers] 
 traces. Concerns regarding dependent traces within training and validation datasets as presented by #cite(<generalisation>, form: "prose") are not relevant, as all our executions in the APS are independent of one another. This would change if we run multiple APSs in parallel or have multiple workpieces processed at the same time and extract the traces per workpiece.

The two tokenized trace sets are then written to two files. We ensure that from now on the model training process does not interact with the validation data.


== Heraklit Prefix Checker

In #ref_def("Correct Prediction") we define what constitutes a correct prediction based on potential next steps (#ref_def("Next Step")). This definition, while easily understandable, has the caveat of not being written in a computationally simple way. 

Following the definition directly, given a _reference_ Heraklit run, and a second _checker_ Heraklit run, to check whether the _checker_ run is a prefix of the _reference_ run, we would need to model all possible suffixes and then check, whether they are equal. 

However, by the composition calculus (#ref_def("Graph Composition")) we know that the two sequences of compositions are equal and represent the same run, if composition produces the same graph. Following from that, a _checker_ sequence of compositions is a prefix of a _reference_ sequence of compositions, if the composition graph of the _checker_ is a *graph prefix* of the _reference_ composition graph.

We define $A$ as a *graph prefix* of $B$ , if the _initial nodes_ (here: nodes without incoming edges) of $A$ are a subset of the _initial nodes_ of $B$ and if $A$ from these _initial nodes_ is a subgraph of $B$. 

We limit our initial nodes to only contain unique labels, as otherwise all possible initial node mappings must be explored, which is computationally expensive. This theoretical limit does not provide any limitations in practice, as proper runs on a single workpiece never contain multiple initial steps of the same type.

#line()

#figure(caption: "Example Composition Graph")[
#image("figures/tool-output/reference_graph.png")
] <example-composition-graph>

We built a tool and python library around this concept, which processes two sequences of predefined steps and checks, whether one is the prefix of the other. To ensure the correctness of the tool, an extensive test suite is created and passes. This tools code is additionally published on GitHub#footnote[#link("https://github.com/Niggelgame/heraklit-equiv-checker/") _last accessed 11.06.2026_] to allow using it for further Heraklit-based process prediction projects.

The tool also contains a neat feature to display the composed run graphs of the two compared runs, leaving out the petri net places. This visualization can help to understand the composition and why predictions might be deemed incorrect. A sample visualisation of a Fischertechnik APS can be seen in @example-composition-graph. It shows a run with a failed quality control. Note how steps that depend on multiple places have input edges coming from the steps that produced the corresponding place.


Thus, given a reference run $r$, a prefix $p$ of it and a prediction $n$ made by our model, we check the correctness of this prediction by using this tool, asking whether $p bullet n$ is a prefix of $r$.

== Model Architecture<model-architecture>

For next-event predictions, we use the Transformer architecture as presented by #cite(<attention>, form: "prose") and explained in @transformer.

As tokens, we use the steps defined in @modelling, plus some additional tokens:

- `<PAD>`, `<BOS>`, `<EOS>`: These meta-tokens are required for the training of the transformer. `<PAD>` is used to allows training on sequences shorter than our context window, padding the remaining window out. `<BOS>` and `<EOS>` mark the _begin_ and the _end_ of the sequence of tokens, letting the model stop its prediction when the process is over.
- `<COLOR RED>`, `<COLOR WHITE>`, `<COLOR BLUE>`: These tokens are inserted at the beginning of a sequence to let the model know about what kind of workpiece is currently processed. This allows learning the different process configurations for different workpiece colors without creating much overhead.

We choose to not encode the workpiece color directly into all tokens, as each step would need to be encoded for all colors, tripling the number of tokens. Most tokens would then need to learn a very similar behaviour within the model for each color. Only at the points of differently defined process behaviour, these tokens would need to show different model behaviour. By only encoding the color at the beginning of the sequence, we leverage the attention mechanism of the transformer to learn to refer to the color token when needed. For other tokens, the behaviour is simply _shared_ for all colors, without the need to refer to the color token. 

Additionally, by _sharing_ the token between colors, cross-color learning is possible. Due to our limited dataset, this is especially helpful, as the model can infer the shared behaviour from all training runs. With separate tokens for each color, the model would not necessarily learn the shared behaviour, but could treat each color separately, thus requiring more training data to learn the same behaviour.

Instead of having a one-to-one encoding of steps to tokens, we could have used a multi-token encoding for each step. Especially with increased detail in the steps, as discussed in @data-col-and-proc, this could be a reasonable approach to avoid token count explosion, especially with larger classes of step parameters. With multi-token encodings, we would however need to ensure that the model not only learns to predict the next event, but also the correct sequence of tokens for a single step to later be able to decode the parameters of a step into a single configured step. To reduce complexity, we decide to not use a multi-token encoding for our steps.

We use an embedding layer to encode the one-hot encoded tokens into a denser vector representation, see @transformer. While reducing the dimensionality of the input and thus the complexity of the model, it also allows the model to learn relationships between tokens, by encoding similar tokens into similar vector represenations.

The hyperparameters of our model architecture are chosen using cross-validation on k-folds of the training data, as discussed in @transformer. We try to provide reasonable values for each hyperparameter, then iterate all combinations of these hyperparameters and choose the best model on the basis of a loss function. 

The loss function represents the sum of the embedded distances between the real next token and the predicted probability distribution of tokens.

Further training details are discussed in the following section.

== Training Details

The model is generally trained in a set amount of _epochs_. Each epoch, the training data is provided to the model to compute the _loss_, a metric describing a _distance_ of the prediction to the correct results. The lower the loss, the better. 

We use a *cross-entropy loss* function, that always sets the loss to 0 for a position if the next token is a padding token. The cross entropy loss creates strong gradients for the optimizer by relying on a negative logarithm of the probability assigned, if the prediction is incorrect, which results in exponential penalty and thus loss for incorrect predictions. 

After computing the loss, we perform a `pytorch` backward computation. This computes a loss differential for each learnable parameter, thus specifying how much the loss would change in which direction if the parameter is changed in a certain direction. This differential is then provided to the AdamW optimizer @adamw-optimizer, which computes the next set of parameters for our models, hopefully lowering the loss.

During training of our model, we add a small _dropout_ layer into our model after the positional embedding of our tokens. _Dropout_, as the name suggests, drops parts of the tensor it computes on. These parts are always selected randomly on a probability defined as $d_("drop")$. This layer tries to regularize our model to not overfit certain parts of our embedding, as the model must rely on multiple different parts of the input. This behaviour has been validated in previous work also related to process prediction @proc-pred-dl. Crucially, the dropout layer is disabled during evaluation of the final model by using the `.eval()` pytorch feature on the model.

This process is repeated for a fixed set of epochs, until a certain loss is reached or until not enough loss progress is achieved.

=== Selecting Hyperparameters

Before training the actual model, we need to select its hyperparameters. 

The values for the different hyperparameters we search though are:

```python
d_models = [16, 32]
layers = [1, 2, 3]
dropouts = [0.1, 0.2, 0.3]
learning_rates = [3e-3, 1e-3]
```

On each possible combinatorial set of parameters we perform a *k-fold cross-validation*. This is a standard technique to avoid overfitting while just using training data. The data set is split into $k$ equally sized groups of data, the so-called _folds_, then we train the model $k$ times, always using $k-1$ folds for training, and one for validation. This technique is especially relevant for the small dataset we have, as we can not be sure that a single random split properly distributes the data into fair training and validation sets. We chose `k = 4`.

During this pre-training phase we train full models with the same number of _epochs_ as the final model. However, if a model does not show loss improvements after a number of predefined cycles of training (here: 8), we stop the model evaluation here. Models stopped in pre-training early either suggest a highly performing model, that has found good parameters early on, or such a bad model configuration, that training it further probably does not produce much of an impact either. 

During cross validation we also measure the performance of the combination of most probable 3 output tokens, producing higher `top_k` performance if any one of these top 3 tokens are correct. 

We then score the different configurations. We do not only consider the average model correctness, but also include a small factor of the `top_k` performance. While we want to optimize for the _one_ most probable output in the final trained model, we want the architecture to support producing other sensible options. This way of scoring rewards fully correct models the most, as providing a correct top hit implies the `top_k` also contain a correct hit. But it also chooses a model that produces good overall second or third hit performance over one that only has a the same top hit performance with bad second or third hit performance.

The highest scoring configuration is then selected as the one the with which we then perform the training on the full data.

As we are training full models for each model configuration, this process is the most time-consuming, taking around 3 minutes on the previously described MacBook configuration. The final selected configuration is the following:

$
  &d_("ctx") &= &128 \
  &d_("lr") &= &0.003 \
  &d_("weight_decay") &= &0.01 \
  &d_("dropout") &= &0.2 \
  &d_("model")&=&32 \
  &d_h &=&4 \
  &d_("layer") &= &3 \
  &d_("dim_ff")&= &128
$<configuration>

=== Training Results

The final training based on the parameters in @configuration takes 30 seconds in full load, using the integrated graphics chip. The cross entropy loss of the final model is $0.8392$.// #note[final values. maybe add a little graph with the progression over epochs?]

A more interesting statistic is the top hit correctness rate of _only_ 89.2%, the top three hit correctness rate being 98.4%. While this might seem surprisingly low for a model we just trained, we need to keep in mind the dropout layer we explicitily added to the training process. 

In @evaluation we will use the split off validation set to perform some different evaluations on the now obtained model.
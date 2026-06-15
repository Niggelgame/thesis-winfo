#import "lib.typ": *
#import "@preview/benplate:0.1.0": note, todo

= Theory<theory>

In this chapter, we will present the theoretical and technical background of this work. 
This includes defining the Heraklit modeling framework used to model the factory, the process prediction problem and finally the transformer architecture applied to solve it, while providing related work.


== Modelling with Heraklit

Heraklit @heraklit is a process modelling framework designed to thrive in a discrete digital world, providing a formal foundation for interaction-driven process management of digital and cyber-physical systems.

We will not provide an in-depth explanation of Heraklit, but will focus on an overview of the most important points relevant to this work. In general, Heraklit builds upon three main characteristics:

- *Architecture*: Models can be composed and refined, allowing building large systems using the _composition calculus_.
- *Dynamics*: Actions are performed using local state, and dynamics between actions using causal relationships.
- *Statics*: Items, data and operations on them are treated as first-class citizens.

The _composition calculus_ of _modules_ and causal modelling are what mainly power our approach to process prediction. To understand how they formally work, we will first define the Heraklit notions of some of the terms, including *interface* and *module*, *composition of modules* and a *step module*. These definitions are based on definitions found in  @heraklit @compositionheraklit. Due to the limited scope of the thesis and the limited requirements of Heraklit in our usecase, definitions are not necessarily complete and proofs are left out. They can be read upon in @heraklit.

Heraklit modules are conceptually modelled using graphs, with inner vertices and outer vertices. These outer vertices contribute to the _interface_ of a module and are the external connection points of a module.

#definition("Interface")[
  A _labeled_ and _totally ordered_ set is an interface.
]

#definition("Match")[
  Let $A$ and $B$ be two interfaces, let $a in A$ and $b in B$. Then ${a, b}$ is a _match of $A$ and $B$_, if for some label $lambda$, both $a$ and $b$ are $lambda-"labeled"$, and 
  
  $|{a' < a and a' "is" lambda-"labeled" | A}| = |{b' < b and b' "is" lambda-"labeled" | B}|$, 
  
  ensuring the number of $lambda-"labeled"$ gates that are smaller than $a$ in $A$ is equal to the number of $lambda-"labeled"$ gates that are smaller than $b$ in $B$. A gate of $A$ that does not belong to a match of $A$ and $B$ is _match free_ with respect to $B$. 

  - Let _matches($A, B$)_ be the set of all matches of $A$ and $B$.
  - Let _matchfree($A, B$)_ be the set of all elements of $A$ that do not belong to a match of $A$ and $B$. 
]


#definition("Module")[
  A module $M = (V, E)$ is a directed graph, together with two interfaces $"*"M subset.eq M$ and $M"*" subset.eq M$ of nodes of M.  The interfaces $"*"M$ and $M"*"$ are the _left_ and _right_ interfaces of $M$ respectively. 
]


The module composition requires composition of graphs along the interfaces. Intuitively, graph composition of two graphs ensures that all graph nodes still exist in the composed graph, just _merging_ the nodes at the interface. The new graph thus contains all nodes of both graphs not included in the interface, the free nodes of both interfaces and once the nodes in the interface. One then just needs to reconstruct the edges as before. 

#definition("Graph Composition")[
  Let $M$ and $N$ be two graphs, let $A subset.eq M$ and $B subset.eq N$ be interfaces. Then the _composition of $M$ and $N$ along $A$ and $B$_ is the graph G where:

  1. The nodes of $G$ are 
    
    $( M \\ A) union (N \\ B) union "matchfree"(A, B) union "matchfree"(B, A) union "match"(A, B)$

  2. For each edge $(x, y)$ of $M$ or $N$,
    - if $x$ and $y$ are both match free, then $(x,y)$ is an edge of $G$;
    - if $x$ is match free and ${y, y'}$ is a match, then $(x, {y, y'})$ is an edge of $G$;
    - if ${x, x'}$ is a match and $y$ is match free, then $({x, x'}, y)$ is an edge of $G$;
    - if ${x, x'}$ and ${y, y'}$ are matches, then $({x, x'}, {y, y'})$ is an edge of $G$.
]

#definition("Module Composition")[
  Let $A$ and $B$ be two modules. Their composition $A bullet B$ is defined as follows:
  - The graph of $A bullet B$ is defined as the composition of the graphs (#ref_def("Graph Composition")) of $A$ and $B$ along the interfaces $A"*"$ and $"*"B$.
  - The left interface $"*"(A bullet B)$ of $A bullet B$ is $"*"A union "matchfree"("*"B, A"*")$. The elements of $"*"A$ are ordered before the elements of $"matchfree"("*"B, A"*")$.
  - The right interface $(A bullet B)"*"$ of $A bullet B$ is $B"*" union "matchfree"(A"*", "*"B)$. The elements of $B"*"$ are ordered before the elements of $"matchfree"(A"*", "*"B)$.
]

Module Composition holds two important properties:

- *Associativity*: Let $A, B, C$ be modules. Then $(A bullet B) bullet C = A bullet (B bullet C)$. This property allows us to ignore the brackets in composition, and merging multiple submodules in arbitrary orders.
- *Commutativity* without shared gates: Let $A, B$ be modules. $A bullet B = B bullet A$ iff $A$ and $B$ share no equal interface labels. This will be of high interest when composing modules without causal relationships. Their interface would not share any labels, so the order of their composition also does not matter.

Note how in #ref_def("Module") there is no notion of any dynamics yet. Heraklit follows the idea of petri nets to model the dynamics, so we will now refine our definitions to separate the graph nodes into alternating _places_ and _transitions_.

#definition("Net Graph")[
  Let $G = (V, E)$ be a graph, and let $P$ and $T$ be two disjoint sets with elements called _places_ and _transitions_, respectively, such that:

  1. $P union T = V$;
  2. For each edge $(x, y) in E$ holds: either $x in P$ and $y in T$, or $x in T$ and $y in P$.

  Then $G$ is a _net graph_, and we write $G = (P, T; E)$
]

#definition("Net Module")[
  For a net graph $G$, a module over $G$ is called a _net module_.
]

Composition of net modules is defined via the composition of modules and produces a valid net module. 

To model the discrete stepwise behaviour of processes, we define _step modules_, which only ever include a single _event_ and the states it affects. Speaking in terms of net modules, every step module only contains *one transition*.


// #todo[Do we really need the "disjoint" requirement? (it should work for our stuff) Additionally, do we want to allow places that are not part of transitions?]
#definition("Step Module")[
  Let $M = (P, {t}; E)$ be a net module with disjoint interfaces $"*"M$ and $M"*"$ with $P = "*"M union M"*"$ such that for each $p in P$ holds: $(p, t) in E$ iff $p in "*"M$, and $(t, p) in E$ iff $p in M"*"$. Then $M$ is a _step module_. 
]

In the following, we will often refer to _step modules_ when describing objects in Heraklit context for simplicity.

#definition("Run Module")[
  Let $R = (P,T; E)$ be a net module. $R$ is a _run module_ iff

  1. all places and all transitions are labeled,
  2. at each place of $R$ at most one edge begins and at most one edge ends,
  3. no edge sequence forms a cycle,
  4. $"*"R$ contains all places where no edge ends,
  5. $R"*"$ contains all places where no edge begins.
]

Important properties of run modules are:
- Each step module is also a run module.
- The composition of run modules generates again a run module.
- Each finite run module $R$ can be composed as $R = P_1 bullet ... bullet P_n$ from step modules $P_1, ..., P_n$.

In the following, _run modules_ are often referred to as _runs_ for simplicity.

This concludes the most necessary basic Heraklit concepts necessary for the our approach. While Heraklit offers many possibilities to model data, structures and functions, we will not need them for the simple model of the Fischertechnik APS.

@nep shows some graphical examples of step modules and composition into runs. In @modelling the step modules for the Fischertechnik APS are defined, along with some examples of composition.

== Process Prediction

Modern enterprise systems collect huge amounts of data of process executions in so-called *event logs*. The event-log of just one execution of such a process is called a *trace*. Each event in these logs contains at least an _identifier_ to distinctly identify the process execution, and _event name_ describing the action and some sort of _ordering_ to express the sequence of events, mostly timestamps and execution times. Additional metadata, such as involved resources, machines or sensoric data, can also be attached to an event.

Process prediction is concerned with predicting *possible outcomes* of ongoing traces. This prediction can be performed online, meaning while the execution of the process happens, such that unwanted outcomes can be prevented by preemptively changing the execution based on the prediction. 

Predictions are thus performed on incomplete traces, providing potential outcomes as outputs. The to-be-predicted outcomes are determined by the business problem at hand. They can be broad information about the full process execution such as expected remaining process execution time or whether the process will fail or succeed in its action, or finer-grained information, such as the next possible event or detecting anomalies within events @fettke-deep-learning-proc-pred @proc-mining.

In this work, we will focus on predicting the next event of a process.

=== Next-Event Prediction<nep>

Given a full execution trace $t = e_1 arrow ... arrow e_n$ of length $n$ and let $p = e_1 arrow ... arrow e_i$ with $i < n$ be a finite prefix of $t$, the next event might seem to simply be $e_(i+1)$. This notion is certainly correct in a sense that $e_(i+1)$ is *a* next step of $p$. However this definition fails to capture the semantics of concurrent or parallel systems, where multiple _correct_ linearisations and thus orderings are possible. 

We build upon the example from #link(<introduction>)[the Introduction]: 

The process needs to start, then two separate machines produce `A` and `B`, and then a third machine combines them. There are two causal relationships given - `Start` must happen first, and the combination of `A` and `B` must clearly happen after both `A` and `B` were produced. Given the prefix trace `Start`, both $#[`Produce`] A$ and $#[`Produce`] B$ are valid options due to the parallelity given. Both traces

$ #[`Start`] -> #[`Produce`] A -> #[`Produce`] B -> #[`Combine`] A and B$

and

$ #[`Start`] -> #[`Produce`] B -> #[`Produce`] A -> #[`Combine`] A and B$

can be deemed _correct_. Given the first trace is then later extracted from the system, the second one should still not be deemed incorrect - as we don't want to care about the order of causally unrelated events.
Importantly though, 

$ #[`Start`] -> #[`Combine`] A and B -> #[`Produce`] A -> #[`Produce`] B$

is *not* a trace we should deem correct. 

To define this correctness measure, we use the Heraklit theory. As a first step, we need to create a mapping between events and Heraklit Step Modules. Given this mapping, we can use the following definitions to describe a correct prediction.

#definition("Run Prefix")[
  Let $R = P bullet S$ be a run module. Then $P$ is a prefix and $S$ a suffix of $R$.
]

#definition("Next Step")[
  Let $R$ be a run module and $P$ a prefix of R. Then the step module $s$ is a next step after $P$ in $R$ iff $P bullet s$ is a prefix of R.
]

#definition("Correct Prediction")[
  Let $R$ be a run module and $P$ a prefix of R. Then the step module $s$ is a correct prediction of $P$ iff $s$ is a next step after $P$ in $R$. 
]

Notice how next steps and correct predictions are inherently the same. 

We can examine these definitions on our example from above by defining the following steps:

#include "figures/theory/steps_sample.typ"

To keep it simple, the labels of the step modules are the same as the labels of the transitions contained within them. The transitions on the left and right on the edge of the module border are the left and right interfaces, respectively. By the layout of the steps one can already grasp as to how valid runs could look. 

By our definitions of composition, we already know that 

$ &#[*Start*] bullet #[*Produce*] A bullet #[*Produce*] B bullet #[*Combine*] A and B \ 
= &#[*Start*] bullet #[*Produce*] B bullet #[*Produce*] A bullet #[*Combine*] A and B$

This composition can also be shown graphically, as seen in @example-machine-run.
By looking at just the first step, *Start*, one can see how both *Produce $A$* and *Produce $B$* are correct predictions for such a run, as no causal relationships are existent between them.

To make use of this definition, we first need to model a system by providing the Heraklit step modules. For our case study, they can be found in @modelling.

#include "figures/theory/run_sample.typ"


=== MQTT<mqtt-theory>

MQTT is a client-server protocol using a publish/subscribe pattern. It is considered the most favorable connection pool for Internet of Things (IoT) applications @mqtt.

With MQTT, clients can connect to the server, a _broker_, and _publish_ some information to a _topic_. Other clients can connect to the same broker, and _subscribe_ to certain topics. Whenever new messages are published to a topic this client is subscribed to, the broker pushes this message to the client. Clients can be _publishers_ (or sources) and _subscribers_ (or sinks) at the same time. Thus MQTT is a many-to-many communication protocol. 

It provides three levels of Quality of Service (QoS), which can deal differently with network performance issues like latency or error rate, at the trade-off of network traffic and energy consumption @mqtt-qos.

1. QoS 0: At most once. The message is sent to all subscribers only once. It is not stored on the broker, and if delivery was not successful, no redistribution is planned. It is also known as _"fire and forget"_.
2. QoS 1: At least once. The message is repeatedly sent to all subscribers that have not acknowledged the message yet, marking every message from the second send on using the `DUP` flag. The message is stored at the broker until all subscribers have received the message.
3. QoS 2: Exactly once. Similarly to QoS 1 the broker stores the message and resends it. However the clients will need to also store the message until it gets released via a special message to ensure no double handling takes place.

The Fischertechnik APS uses MQTT as its main channel of communication between the different production modules. While most state updates are distributed via QoS 1, some specific order requests are executed using QoS 2. 

Both cases result in duplicate messages from the broker, which need to be filtered out during data processing. The specific MQTT broker can also _retain_ messages of QoS 1, which redistributes the latest message from a topic to newly connected clients, even if that message was published before. These messages need filtering as well, as they can incorrectly influence the assumed state.

== Transformer<transformer>

Over the last decade, research mostly identified deep-learning approaches as an advancement over traditional machine learning approaches for predictive process monitoring @fettke-deep-learning-proc-pred @ppm26 @deep-learning-process-pred @proc-pred-dl. Especially with a lot of different events requiring high cardinality categorial variables, traditional machine learning approaches start to show their weaknesses @rf-bad.

While using Long Short-Term-Memory models (LSTMs), a special version of recurring neural networks (RNN) showed it successes @lstmref1 @lstmref2, later state-of-the-art models use the transformer architecture @transformerpred1 @transformerpred2.

=== Transformer Architecture

First presented in @attention, this deep-learning based model architecture revolutionized its field, with now more than 250.000 direct citations #footnote[Based on Google Scholar, accessed June 2026]. Originally intended for language translation, it is now most known for the use in Large Language Models (LLMs), that power platforms like ChatGPT @chatgpt-is-transformer.

The following section will provide a technical overview of the architecture as presented in the original paper. The transformer can generally be split into two parts: The `Encoder` and the `Decoder`, whereas the former focuses on creating a _contextual understanding_ of input data and the latter is responsible for _generating output_ sequences based on previous output and the understanding of the `Encoder`. Nowadays often only one of the two structures is used, e.g. BERT only uses an `Encoder` layer to learn text representations @bert, while GPT and GPT-2 both used an `Decoder`-only architecture @gpt-1 @gpt-2, as it is focussed on next token generation only. 

As our goal of next-event prediction requires us to generate new steps, our model can be a `Decoder`-only network as well. We will therefore focus on presenting the architecture structure of that sub-module.

The first step is to convert the input sequence tokens to vectors of size $d_("model")$. With a context window size $d_("ctx")$, which is the maximum amount of tokens processed at the same time by the model, this conversion translates our sequence of tokens into a two-dimensional tensor of size $d_("model") times d_("ctx")$. This transformation is performed by a trainable linear layer, essentially the index of the tokens in the vocabulary to the lower dimension, _embedding_ it.
Both $d_("model")$ and $d_("ctx")$ are _hyperparameters_ of the architecture, as are further variables written as $d_("param")$, which must be chosen before training.

Next follows a _positional encoding_, where fixed geometrically decreasing frequencies are added to the input embeddings to encode the position of the token within the sequence. As no further weight is given to the explicit original sequence order in the following steps, this encoding provides the only way to distinguish two tokens' distance in the upcoming layers. 

The now properly embedded sequence is now passed through $d_("layer")$ repetitions of the transformer blocks. They each again consist of three sublayers, connected each by a layer normalization. Assuming input $x$ to a sublayer and $"Sublayer"(x)$ the function performed by the sublayer, the output is $"LayerNorm"(x + "SubLayer"(x))$, to keep the output stable without any unexpected outliers complicating the gradient descent during training.

Two of the sublayers are _Multi-Head Attention Layers_. Here the current embedding is first multiplied by $d_h dot 3$ linearly learnable parameter matrices $W_i^Q, W_i^K in RR^(d_("model") times d_k)$ and $W_i^V in RR^(d_("model") times d_v)$ with $1 <= i <= d_h$. The results are triples of the form $(Q_i, K_i, V_i)$. In more optimal implementations, this computation does not need to perform $3 dot d_h$ matrix multiplications, but instead combined into one larger matrix multiplication. The triples are fed into the _scaled dot-product attention mechanism_, defined as

#align(center)[$"Attention"(Q_i, K_i, V_i) = "softmax"("mask"(Q_i K_i^T)/(sqrt(d_k))))V_i$]

This computation can be intuitively understood as follows. 

1. Combining $Q_i$ and $K_i$: $Q_i$ represents a certain learned query, essentially encoding which part of the embedding is interested in getting certain information of other tokens. $K_i$ highlights positions in the embedding, that match this information of the query $Q_i$. By multiplying them, one combines the interested embedding with the tokens that contain information.
2. Lowering the magnitude of the values in the combined matrix by dividing by $sqrt(d_k)$, such that the $"softmax"$ function has smoother gradients. 
3. Masking out all fields that try to let tokens refer to tokens after them, by setting the matrix upper right diagonal to $- infinity$.
4. $"softmax"$ itself performs a rowwise normalisation, such that all rows represent a random distribution, i. e. summing up to 1 while keeping the relative magnitude information. Values of $- infinity$ result in $0$.
5. Multiplying by $V_i$: $V_i$ contains the embedding of the information that is present, if the query and key match. Thus the multiplication linearly scales that information within the embedding.

The resulting matrices are of the shape $d_("ctx") times d_v$. They are now concatenated into one $h dot d_("ctx") times d_v$ matrix and multiplied by a last parameter matrix $W^O in RR^(h d_v times d_("model"))$.

The third sublayer of the transformer block is a simple 2-layer fully-connected feed-forward network with a ReLU activation function. The input and output layers have dimension $d_("model")$ and the inner layer $d_("dim_ff")$.

After the transformer blocks, we need to extract the next token. Similarly to the initial embedding, we now need to map the embedded $d_("ctx")$ $d_("model")$-dimensional vectors back to our tokens. We again apply a learnable linear layer to the embedding, resulting in vectors the same size as the vocab with all tokens. After normalisation, the vector at position $i$ contains a probability distribution over the token at position $i+1$.

#line()

We acknowledge that there are further optimizations to this architecture since the original release, mostly on performance and resource usage @transformer-opt-cache, and that there are multiple adaptions to other domains such as image processing @image-transformer. Due to our limited dataset and resulting small parameter set, model performance and resource should operate in a scale that are not a concern for us. 

=== Model Training

Training not only consists of fitting our parameters to the training token sequences. Before training, we need to perform a hyperparameter selection. 

Besides the model parameters from above, we need to also select parameters for the deep learning optimizer, in this case the AdamW optimizer @adamw-optimizer, which builds upon the Adam optimizer @adam-optim, improving its generalization performance by decoupling the weight decay. Parameterwise it takes a learning rate $d_("lr")$, the weight decay, two running average parameters $beta_1, beta_2$ and a numerical stability parameter $epsilon$. 

Using cross validation on k-fold splits of the training data, we search through a subset of hyperparameters. These hyperparameters are based on the model defaults and changed according to the training data size we provide.


=== Technical requirements for Process Prediction

Some approaches to apply the transformer architecture rely on natural language to express the processes steps @llm-proc-pred. However, this approach requires the model not only learning things about the process, but also understanding the language.

Our approach to use the transformer architecture therefore relies on training a _smaller_#footnote[Compared by the number of learnable parameters to a typical LLM] model following the original transformer architecture from scratch. 

The architecture requires us to encode our Heraklit steps into _tokens_. We chose to make every possible step its own token, as our case study does not require taking in parameters for steps. In case of parameters, one can simply encode them as a sequence of tokens, or by creating multi-dimensional input- and output vectors that are parsed as parameters. The output of the model includes the _probabilities_ of the different next tokens. One can either just choose the one with the highest probability, or sample off of the then provided distribution.

Further details on Fischertechnik APS specifics and the training of our model are discussed in @implementation.



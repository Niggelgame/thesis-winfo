#import "lib.typ": *
#import "@preview/benplate:0.1.0": note, todo

= Theory<theory>

In this chapter, we will present the theoretical and technical background of this work. 
This includes explaining the Heraklit modeling framework used to model the factory, the process prediction problem and the transformer architecture applied to solve it. Lastly, related work in the field of process prediction and process mining will be discussed.


== Modelling with Heraklit

Heraklit @heraklit is a process modelling framework designed to thrive in a discrete digital world, providing a formal foundation for interaction-driven process management of digital and cyber-physical systems.

We will not provide an in-depth explaination of Heraklit, but will focus on an overview of the most important points relevant to this work. In general, Heraklit builds upon three main characteristics:

- *Architecture*: Models can be composed and refined, allowing building large systems using the _composition calculus_.
- *Dynamics*: Actions are performe using local state, and dynamics between actions using causal relationships.
- *Statics*: Items and data and operations on them are treated as first class citizens.

The _composition calculus_ of _modules_ and causal modelling are what mainly power our approach to process prediction. To understand how they formally work, we will first define the Heraklit notions some of the terms, including *interface* and *module*, *composition of modules* and a *step module*. These definitions are based on definitions found in  @heraklit @compositionheraklit. Due to the limited scope of the thesis and the limited requirements of Heraklit in our usecase, definitions are not necessarily complete and proofs are left our. They can be read upon in @heraklit.

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
  A module $M = (V, E)$ is a directed graph, together with two interfaces $"*"M subset.eq M$ and $M"*" subset.eq M$ of nodes of M.  The interfaces $"*"M$ and $M"*"$ are the _left_ and _right_ interface of $M$ respectively. 
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
  Let $A$ and $B$ be two modules. Their composition $A dot B$ is defined as follows:
  - The graph of $A dot B$ is defined as the composition of the graphs (#ref_def("Graph Composition")) of $A$ and $B$ along the interfaces $A"*"$ and $"*"B$.
  - The left interface $"*"(A dot B)$ of $A dot B$ is $"*"A union "matchfree"("*"B, A"*")$. The elements of $"*"A$ are ordered before the elements of $"matchfree"("*"B, A"*")$.
  - The right interface $(A dot B)"*"$ of $A dot B$ is $B"*" union "matchfree"(A"*", "*"B)$. The elements of $B"*"$ are ordered before the elements of $"matchfree"(A"*", "*"B)$.
]

Module Composition holds two important properties:

- *Associativity*: Let $A, B, C$ be modules. Then $(A dot B) dot C = A dot (B dot C)$. This property allows us to ignore the brackets in composition, and merging multiple submodules in arbitrary orders.
- *Commutative* without shared gates: Let $A, B$ be modules. $A dot B = B dot A$ iff $A$ and $B$ share no equal interface labels. This will be of high interest when composing modules without causal relationships. Their interface would not share any labels, so the order of their composition also does not matter.

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


#todo[Do we really need the "disjoint" requirement? Do we want to allow places not part of transitions?]
#definition("Step Module")[
  Let $M = (P, {t}; E)$ be a net module with disjoint interfaces $"*"M$ and $M"*"$ with $P = "*"M union M"*"$ such that for each $p in P$ holds: $(p, t) in E$ iff $p in "*"M$, and $(t, p) in E$ iff $p in M"*"$. Then $M$ is a _step module_. 
]

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
- Each finite run module $R$ can be composed as $R = P_1 dot ... dot P_n$ from step modules $P_1, ..., P_n$.



== Process Prediction Problem



== Transformers

What is this transformer?

=== How to apply this transformer theory to the process prediction problem?

== MQTT

== Related Work
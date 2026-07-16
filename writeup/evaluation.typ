#import "@preview/benplate:0.1.0": note, todo
#import "@preview/lilaq:0.6.0" as lq

= Evaluation<evaluation>

In this chapter we will first compare our prediction model with a random and an empirical baseline, showing that our model is able to learn about the underlying process. We then evaluate different generalization capabilities of our model. 

== Baseline Comparisons<baseline>

We want to predict the next step of the APS process, which is processing a single workpiece. One can understand this as predicting the next step from the perspective of the CCU, as the CCU controls the full behavior we model, or from the perspective of the workpiece, as we mostly predict actions only concerned with work on this workpiece. One exception to the last point is given by potential movement of the AGV while the workpiece is processed. This step is valid, but not relevant for the singular workpiece perspective. 

Given by the data collection process, the runs produced as the validation data set are already provided from this perspective. Thus, it remains to check the predictions.

In the following we will refer to our model as a function $(n_1, ..., n_k) = "predict"(P, k)$, where $P$ is a run prefix and $k$ is the number of best next steps options after $P$ the model should output, ordered by their probability.

=== Simple Next Step Check<simple-scen>

For each run $R = s_1 bullet ... bullet s_n$, where $s_j$ is a step token, we take all prefixes $P_i = s_1 bullet ... bullet s_i$ with $1 <= i < n$. We then let our model predict the most probable next step $n_i = "predict"(P_i, 1)$. If $n_i = s_(i+1)$, we set $c_i = 1$, else $c_i = 0$

We calculate the _run accuracy_ metric for each run as $A_R = 1/(n-1) sum_(i=1)^(n-1)c_i$, dividing the number of correctly predicted steps by the number of totally predicted steps.

As different runs have different lengths $n$, the total _accuracy_ of our model on the validation set is calculated by an average over all run accuracies, as otherwise longer runs would be deemed more important than short ones. This should not be the case, as especially shorter runs contain the failure cases, resulting in an early process abort.

We therefore calculate the _accuracy_ over our validation set of runs $"val"$ as

$A = 1/(|"val"|) sum_(R in "val") A_R$

We still need to provide a baseline, so we measure the same metric on a random predictor, selecting a *random* next step $"predict"'(R, k)$, drawing $k$ distinct steps from the set of possible steps. 

We also provide an *empirical* predictor $"predict"''(R, k)$, that processes the initial training data set and extracts number of times a token appeared in the dataset. We then order the tokens by descending count, and predict the first $k$ tokens, which are the $k$ tokens that appeared in the training data set the most. If there are multiple tokens with the same count that, sampled, would lead to more than $k$ predictions, we again randomly sample from that group.

The random baseline was able to achieve an accuracy of *1.79%*, meaning 1.79% of next steps were predicted correctly. The empirical baseline achieves an accuracy of *5.36%*.

Our model achieved an accuracy of *91.07%*, highly outperforming the random and empirical baseline. This is a clear indicator that our model was able to learn properties the structure of our process. This proves the model is learning about the sequential and causal relationships, and not only mimicking the frequency of contributions.

It is notable that this accuracy is higher than the accuracy measured during training, we expected this behavior due to the disabled dropout layer during evaluation.

=== Top-K Next Step Check

This scenario tries to adapt to an issue found in the Fischertechnik APS simulation control: Some next steps are basically unpredictable based just on the previous execution, leaving multiple options. One highlighted example from before is the quality control. The APS does not change its behavior if the processed workpiece is destined to be failing the quality control. Thus, the predictor also cannot catch any special structure pointing towards a failure. The decision of the next step at this position can be described as non-determinism. This means that after the quality control has started, both the quality control success and failure steps are both highly probably, the predictor has no way of knowing which one is correct.

We want to define a correctness measure that allows for lenience in the prediction due to the structure described above. Therefore, in the following, we check whether one of the top $k$ next step options ordered by their model output probability is correct instead of just the next step option with the highest probability.

We can simply adapt our definitions from the previous scenario to predict the $k$ most probably next steps at each prefix $n_(i,1), ..., n_(i, k) = "predict"(P_i, k)$. We then change the correctness measure to deem a prediction correct, if at least one option is a correct prediction, formally if $or.big_(j = 1)^k (n_(i,j) = s_(i+1))$, we set $c_i = 1$, else $c_i = 0$. The accuracy measure calculations on the correctness remain the same.

With $k=2$, we can observe a top-2 accuracy of *our model* of *100%*. The _random_ baseline only predicts the top-2 events correctly with an accuracy of *5.36%*, the _empirical_ baseline has a *10.71%* accuracy.

To put the prediction performance of our model into context, even with $k=10$, the random baseline only achieves an accuracy of 21.4%, the empirical baseline 57.14%. 


== Generalization Performance

#cite(<generalisation>, form: "prose") highlight the importance of generalization within the scope of next event prediction. Generalization here refers to the ability to make correct predictions for traces with unseen behavior, based on some implicit representation of the process structure within the model.

While our general baseline evaluation cases in @baseline are measured on traces not seen during training, and we are using cross-validation and dropout to reduce overfitting and guide towards generalization, we want to ensure that our model can cope with unseen behavior not found within the original dataset. 

We specifically want to focus on potential issues related to the transmission noise during the transmission of events to the predictor. This could be in the form of highly delayed messages arriving at an unexpected time or messages that are dropped and not received properly. Since the APS is a networked system, dropped or late messages are to be expected, thus robustness when dealing with such symptoms is desired.//#note[Duplicate scenario?] 
We will evaluate these two scenarios on our model by introducing synthetic noise in the described forms into the prefix runs passed to our model, comparing the resulting accuracy with the accuracy from our baseline.

An additional experimental evaluation to test our generalization performance is to extrapolate the type of runs we see in the training data. Instead of just processing a singular workpiece in one sequence, we perform a short analysis to see how our model performs on one long run processing multiple workpieces at once.

=== Additional Random Events

To simulate the arrival of highly delayed messages, we will insert random events into the prefix traces. The number of insertions is controlled by a parameter $p$, describing the ratio of number of newly inserted events to the size of the prefix event sequence. For example, with a trace prefix of length 10 and $p = 0.2$, we would insert 2 random events at random positions into the prefix trace. The random events are drawn from the set of all possible events with replacement.

To validate the correctness of the predicted step, we append the predicted next step to the _original prefix_ and check this for correctness.

We differentiate between two sub-scenarios:

- Insert at all positions except the last. This ensures that the model does not get unfairly reduced accuracy, as remotely possible events inserted after the last event might get treated as the situation where multiple events between the two last steps were dropped
- Insert at all positions


We evaluate both sub-scenarios with $p$ starting from 0 and increasing in steps of 0.05 up to 0.5.

For the first scenario the accuracy remains mostly stable, dropping slightly over the increasing $p$ from \~91% down to \~86%. The accuracy even slightly increases in some cases around $p = 0.3$. This can be explained by the amount of events inserted into the trace: The new events create a new context for the model, which leads to a correct prediction for the original unmodified prefix, under which the model has failed before. This progression is plotted in @p-progression on the left.

The performance drop in the second scenario, inserting random events being possible at all positions, worsens the accuracy much more significantly, up to only \~*43.4%* with $p = 0.5$. The progression over increasing $p$ is plotted in @p-progression on the right.


#figure(caption: [Progression of accuracy over increasing insertion rate $p$], placement: none)[

  #let results_no_last = (
    "0": 0.9056603773584906,
    "0.05": 0.9056603773584906,
    "0.1": 0.8867924528301887,
    "0.15": 0.8867924528301887,
    "0.2": 0.8867924528301887,
    "0.25": 0.8867924528301887,
    "0.3": 0.9433962264150944,
    "0.35": 0.9433962264150944,
    "0.4": 0.9056603773584906,
    "0.45": 0.8679245283018868,
    "0.5": 0.8679245283018868
    )

    #let x = results_no_last.keys().map(e => float(e))
  #let y = results_no_last.values()


  #let no_last = scale(x: 90%)[#lq.diagram(
    xaxis: (label: [$p$_: insertion ratio (keeping last)_]),
    yaxis: (label: [_accuracy_], lim: (0, 1)),
    lq.plot(x, y)
  )]
  
    #let results = (
    "0": 0.9056603773584906,
    "0.05": 0.8113207547169812,
    "0.1": 0.7735849056603774,
    "0.15": 0.7169811320754716,
    "0.2": 0.6792452830188679,
    "0.25": 0.7358490566037735,
    "0.3": 0.6792452830188679,
    "0.35": 0.5471698113207547,
    "0.4": 0.5094339622641509,
    "0.45": 0.4339622641509434,
    "0.5": 0.4339622641509434
  )

  #let x = results.keys().map(e => float(e))
  #let y = results.values()


  #let with_last = scale(x: 90%)[#lq.diagram(
    xaxis: (label: [$p$_: insertion ratio (changing last)_]),
    yaxis: (label: [_accuracy_], lim: (0, 1)),
    lq.plot(x, y)
  )]

  #grid(
    columns: 3,
    align: (center, center, center),
    no_last,
    h(20pt),
    with_last
  )
  #v(10pt)
]<p-progression>

This suggests that the model highly depends on the last prefix event being the correct event to predict the next event. 

=== Dropping Random Events

To simulate dropped messages, we can simply drop random events from our prefix traces before prediction. The percentage of dropped messages is controlled by a parameter $p$. We validate the prediction outputs again by appending the next step to the _original_, pre-drop prefix and checking for correctness.

For the dropping of random events we explicitly do not consider the case of dropping the last event, since the model would then possibly predict the last event itself. Due to our validation mechanism this would duplicate the last token, immediately treating the model output as incorrect, even though the model output on the given sequence would be perfectly correct.

By dropping $p$ parts of the run, except the last event, the accuracy only reduces slowly compared to the scenario in @p-progression. Surprisingly, even when dropping 50% of the events, the accuracy remains at \~*81%* from the previous \~91%. The plot of accuracy can be seen in @p-dropout. 

#figure(caption: [Progression of accuracy over increasing dropout rate $p$], placement: none)[
  #let results = (
    "0": 0.9056603773584906,
    "0.05": 0.8867924528301887,
    "0.1": 0.8867924528301887,
    "0.15": 0.8867924528301887,
    "0.2": 0.8867924528301887,
    "0.25": 0.9245283018867925,
    "0.3": 0.9233962264150944,
    "0.35": 0.8867924528301887,
    "0.4": 0.8679245283018868,
    "0.45": 0.8301886792452831,
    "0.5": 0.8113207547169812
  )

  #let x = results.keys().map(e => float(e))
  #let y = results.values()


  #lq.diagram(
    xaxis: (label: [$p$_: dropout rate_]),
    yaxis: (label: [_accuracy_], lim: (0, 1)),
    lq.plot(x, y)
  )
]<p-dropout>

The reduced rate of accuracy rate points towards good generalization capabilities of the model when dealing with message drops. 

=== Extended Input Run<extended-run>

The training data just contains traces of the APS, for which one workpiece was processed at a time, from entering the factory at the DPS, up to failing at the AIQS or being dropped off for delivery at the DPS again. We now predict on a singular additional recorded trace, for which nine workpieces are passed into the factory directly after each other, with the orders starting to be processed directly. It consists of 180 steps in total, averaging 20 steps per workpiece.

This run has certain properties our training runs do not have, that can have an impact on the prediction quality:

1. The run contains workpieces of multiple colors. Remember that we use special _meta_ color tokens to let the model know what kind of workpiece is processed in this sequence (see @model-architecture). Usually, this token is automatically prepended based on the trace metadata containing the color. Thus, our automatic preprocessing cannot handle the color changes in between the workpiece processes.

2. The run contains previously unseen parallelism. Especially the started processing of the first workpiece, while pieces are picked up from the DPS and passed to the HBW, lets the AGV continuously transfer between DPS, HBW and the processing workstation.

3. The model outputs `<EOS>` tokens when it reaches what it learned to be the end of a sequence and thus a run. In the training data, every run ends after processing one piece. Here, the `<EOS>` should only be output after the processing of multiple workpieces. This type of generalization cannot be expected from our model.

Due to the set of training data sequences never containing such parallel scenarios, there is no proper workaround for the second and third issues. One could retrain a new model on training data containing such runs or split the traces into multiple separate traces and thus create scenarios known to our model. Splitting the traces by workpiece order could create traces from the perspective of individual workpieces, reducing the parallelism and ending individual sequences properly, which our model is capable of handling - we do not evaluate this in this thesis, as our preprocessing is not able to distinct different orders. The coloring issue could be resolved at the time by adding additional color meta-tokens by hand into the token sequence, which would, however, also require changes to our processing specific to this sample.

The APS trace is processed following the same procedures for training and validation data as seen in @data-col-and-proc. We then perform the same evaluation baseline evaluations as before.

For simple next step prediction, our model has an accuracy of *45.25%*. Looking at the incorrect predictions, \~10% incorrectly assumed `<EOS>` matching our expectation from 3.
An additional \~25% the model failed to predict additional AGV movements never seen in that context in the training data, and \~33% stem from the repeated picks and drops from the DPS and the HBW, stemming from the insertion of additional workpieces into the factory. The remaining failures can be mostly attributed to unknown process configurations from missing color information, as the model incorrectly predicts the sequences of process modules.

Thus, the accuracy, while seeming low, matches the expectations due the limits explained above. The hypothesis is supported by the accuracy of the top $2$ prediction of just *53.63%*, as many of the corrected step predictions from before are not even considered a valid option by the model.


== Model Performance

Predictive process monitoring is mostly done for ongoing processes, and possibly in an completely online setting, predicting on data just as it arrives at the system. Both the _resource requirements_ and the _amount of time_ required for singular predictions are relevant factors to consider when discussing online deployment. 

Resource requirements are a non-issue for our model. The prediction itself consumed at most 400MB of memory during longer-running benchmarks, with up to 60% single CPU usage and 5% GPU usage. Not using 100% of the CPU can be explained by offloaded work to the GPU, during which the CPU is not needed by the program. Our model only consists of _42466_//#note[final number!] 
floating-point parameters, thus VRAM with a fully loaded model usage is limited as well.

The individual prediction times amounted to an average of 40ms including reloading the model after each prediction. The first prediction requires loading the model from the filesystem, resulting in \~400ms loading times, later predictions only reloading the model from mapped memory then average at only 34ms. These times can certainly be enhanced by not reloading the model after every prediction, however the current infrastructure does not provide the functionality for consistently keeping the model loaded.

Combining these two results, we can infer that online usage is certainly possible with this model, even though it would require some infrastructure build-up to support live translation of the MQTT events into the steps, and pipelining that into the model.


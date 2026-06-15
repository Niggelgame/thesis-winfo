#import "@preview/benplate:0.1.0": todo, note, prose


= Conclusion<conclusion>

This thesis presents an approach to using the transformer deep learning architecture to perform predictive process monitoring, especially next-event prediction, under concurrent and parallel systems. This approach starts by modelling relevant event as Heraklit @heraklit _steps_, which are then interpreted as _tokens_ for a modified transformer architecture by #prose([@attention]). 

To evaluate the approach, we introduce a _correctness_ measure of a prediction based on prefix runs. We rely on the Heraklit composition calculus to allow arbitrary ordering of causally unrealated events, while enforcing the order of causally related events. 

Our approach is then evaluated on the Fischertechnik _Agile Production Simulation_ to perform next-event prediction within the distributed production system from the view of the central control unit. We train our model on a limited set of event traces of singular workpiece processings throughout the factory.

The resulting model shows a high accuracy of *91.07%* for single next step prediction, and when considering the two possible next steps with the highest probabilities, our model reaches *100%* accuracy on the validation data set.

We also perform an analysis of the generalisation performance of the model on special scenarios of the factory. As our factory communicates via MQTT over a network, we simulate scenarios with dropped messages and random arrival of late, unrelated messages. With dropped messages, the model accuracy only falls to \~81% with 50% of the messages being dropped. Similarly with random unrelated messages, the performance of our model only decreases slightly to 86% when the latest event stays the same, but falls down to \~50% when new events are also inserted after the last original event. 

This is expected, as our model is prepared for generalisation due to the use of _cross validation_ and _dropout_ during the training, however it highly relies on the last step to predict the next.

Our approach shows clear success on the Fischertechnik APS, while creating a model performant enough to be run on conventional mobile devices and prediction times, that would allow use in an online production environment.

To conclude, our approach creates a model that properly predicts next events, while allowing the reordering of non-causally related events. Thus an application for parallel or concurrent systems such as a distributed production environment is reasonable.


== Limitations and Future Work

In the following section we want to highlight certain limitations and present relevant open problems for future work.

Our case study relies on a dataset of only 10 runs through the system. While the resulting performance from such a small dataset is impressive, the training data obviously did not catch all edge cases for the model to learn. More data can be extracted from the APS, and more complex scenarios can be reflected in the training data, such as parallel processing of multiple workpieces or multiple AGVs running in the same system, as highlighted in @extended-run.

The dataset also did not contain the metadata from the raw MQTT messages, such as the `DUP` flag to identify resends of messages due to the QoS levels. This additional protocol information could make future data pre-processing more reliable.

We did not focus on extracting the parameters for specific actions, such as the amount of time the MILL should perform its action. Adding these kind of parameters to the modelling and encoding could open up the prediction of more fine-grained prediction within the APS. This is a clear limitation for what kind of processes can be modelled by the infrastructure at the moment, as parameters need to be included into the tokens directly. Adding byte-pair-encoding instead of doing a 1-1 step to token mapping could simplify this in future work.

We perform no comparison to other prediction-model architectures, as this would be out of scope for this thesis. To clearly isolate the performance benefits coming from the transfomer architecture, it remains to benchmark other, possibly simpler traditional machine learning models. Especially with the fundamental simplicity of the factory, traditional machine learning models could already perform quite well for limited scenarios.

Some further actions on the basis of our model could be to

- Extend our discrete pipeline into one continuous live algorithm, that can consume the live logs as an input and output concrete predictions as an output. This should be straight-forward, as the singular steps of the pipeline already exist, however the current pipeline would need to be adjusted to combine all scripts into one module.
- Focus on explainability of the model. During generalisation testing, we realised that especially the last token has a big influence on the next predictions. An analysis to identify which parts of the sequence the model puts its _attention_ to would increase explainability, and thus trust into the model.
- Extend the Fischertechnik APS software to create early indicators for failure during the process, such as milling longer or by providing simulated tool wear. This would ensure that a process prediction on the APS can base failure or success predictions on run information.   

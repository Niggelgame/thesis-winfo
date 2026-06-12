# ML Model

This directory contains the scripts related to preprocessing and training of the transformer model used for process prediction in the Fischertechnik APS.

## Preprocessing

Consuming the previously created filtered and collected trace JSON file, we will now extract further information about tokens and additional metadata. This metadata includes timing, the type of commands and reasons for why events were not converted to tokens.

```shell
uv run main.py preprocess --data ../../data/combined/collected-filtered.proc.json --out-json ../../data/model/preprocessed_tokens.json
```

This generated file will then be used for training the model.

## Training

We have our dataset processed into tokens, now we need to create our prediction model. Using

```shell
uv run main.py train --data-preproc ../../data/model/preprocessed_tokens.json --artifacts-dir ../../data/model/artifacts
```

the model will be trained. Certain hyperparameters will first be chosen using cross-validation (the model dimensions, layers, dropouts and learning rates). Then a training run on the data happens. 

For the final validation, the data should be split into training and validation before training the models:

```shell
uv run random_split_preprocessed.py ../../data/model/preprocessed_tokens.json ../../data/model/train_tokens.json ../../data/model/val_tokens.json
```

and then training with

```shell
uv run main.py train --data-preproc ../../data/model/train_tokens.json --artifacts-dir ../../data/model/artifacts
```



## Predicting

From the validation data set one can now extract the simple token traces first using

```shell
uv run extract_steps.py ../../data/model/val_tokens.json ../../data/eval/traces
```

and also extract the token occurences using

```shell
uv run extract_training_token_occurences.py ../../data/model/train_tokens.json ../../data/eval/training_trace_occurences.json
```

which can now be individually evaluated with using [the eval suite](../eval/README.md).


Sample predictions can be done with individual token traces in a file using 

```shell
uv run main.py predict --artifacts-dir ../../data/model/artifacts --data ../../data/eval/single_trace --steps <num_of_steps>
```
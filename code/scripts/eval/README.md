# Evaluation

Evaluation consists of multiple evaluated scenarios. 

## Simple scenario

Run the simple scenario just predicting the next token using 

```shell
uv run simple_scenario.py
```

To create the baseline with random steps, run 
```shell
uv run simple_scenario.py --random
```

## Top X scenario

Run the general top X scenario predicting and checking x next token options using

```shell
uv run topx_scenario.py
```

Again, to use the random baseline, use

```shell
uv run topx_scenario.py --random
```

To change the number of top n options to check, provide the additional `--top-x` parameter.

```shell
uv run topx_scenario.py --top-x N
```

## Insert Random Scenario

Run the random insertion generalisation scenario using

```shell
uv run insert_random_scenario.py
```

To run it with allowing insertion after the last step, run

```shell
uv run insert_random_scenario.py --drop-first
```

## Drop Random Scenario

Run the scenario randomly dropping events using 

```shell
uv run random_dropped_scenario.py
```

## Long Unseen Trace

First, in `data-collection`, run 

```shell
uv run collect_set.py ../../data/eval/long_trace/original --output ../../data/eval/long_trace/collected.proc.json
```

Then filter:

```shell
uv run prefilter.py ../../data/eval/long_trace/collected.proc.json --output ../../data/eval/long_trace/collected-filtered.proc.json
```

Next, from `ml_model`, run preprocessing:

```shell
uv run main.py preprocess --data ../../data/eval/long_trace/collected-filtered.proc.json --out-json ../../data/eval/long_trace/preprocessed_tokens.json
```
To evaluate, run both simple and topk scenarios:

```shell
uv run simple_scenario.py --validation-trace-path ../../data/eval/long_trace/preprocessed_tokens.json
```

```shell
uv run topx_scenario.py --validation-trace-path ../../data/eval/long_trace/preprocessed_tokens.json
```

# Integrity

All randomness within these evaluations have fixed the seed of `random` to ensure deterministic test execution.

Timing measurements are extracted on the simple scenario

```shell
uv run simple_scenario.py --time
```
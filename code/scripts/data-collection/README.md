# Data Collection

This directory contains all the scripts related to data collection and early pre-filtering.

## Data Extraction

First data needs to extracted from the Fischertechnik APS using a MQTT connection to the included Broker. All events are written to JSON files.

## Data Aggregation

Before any processing of the data itself takes place, the raw MQTT logs are first combined into a single data file:

```shell
uv run collect_set.py ../../data/original --output ../../data/combined/collected.proc.json
```

Now some events are already filtered out for the ease of analysis of the raw data:

```shell
uv run prefilter.py ../../data/combined/collected.proc.json --output ../../data/combined/collected-filtered.proc.json
```

This script will also give some information about the events collected within the data.

## Next step

Now the data is ready be parsed by our preprocessor. The preprocessor will find relevant events for our prediction model and convert it to tokens corresponding to the Heraklit transitions. 

Take a look at [the ML-Model Readme](../ml-model/README.md) next.

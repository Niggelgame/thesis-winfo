# Project Scripts

## Setup

Install [uv](https://docs.astral.sh/uv/getting-started/installation/) to get started. All other dependencies will be installed automatically when running `uv` later.

## Reproducing Results

To get started with using this code, go into the [data collection directory](data-collection/README.md). Make sure to enter the directories with the terminal as well to be able to run the scripts.

## Issues with Heraklit Equivalence Checker

The [Heraklit Equivalence Checker](data-collection/README.md) tool is included in the `heraklit_equiv_checker` directory as a submodule. If you cannot access the submodule, run `git submodule update --init --recursive` to load it.
uv run main.py preprocess --data ../../data/combined/collected-filtered.proc.json --out-json ../../data/model/preprocessed_tokens.json
uv run random_split_preprocessed.py ../../data/model/preprocessed_tokens.json ../../data/model/train_tokens.json ../../data/model/val_tokens.json
uv run extract_steps.py ../../data/model/val_tokens.json ../../data/eval/traces
uv run main.py train --data-preproc ../../data/model/train_tokens.json --artifacts-dir ../../data/model/artifacts

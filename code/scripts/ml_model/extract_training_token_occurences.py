import sys
import json
from collections import defaultdict


if len(sys.argv) != 3:
    print("Usage: extract_training_token_occurences.py <in_file> <out_file>")
    exit(1)

with open(sys.argv[1], "r") as f:
    data = json.load(f)


tokens = defaultdict(lambda: 0)

for trace in data:
    for ev in trace["events"]:
        tokens[ev["token"]] += 1

tokens_sorted = {k: v for k, v in sorted(tokens.items(), key=lambda item: item[1], reverse=True)}

with open(sys.argv[2], "w") as f:
    json.dump(tokens_sorted, f)

print(f"Wrote the token occurences")
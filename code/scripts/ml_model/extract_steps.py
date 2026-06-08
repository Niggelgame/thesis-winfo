import sys
import json



if len(sys.argv) != 3:
    print("Usage: extract_steps.py <in_file> <out_file>")
    exit(1)

with open(sys.argv[1], "r") as f:
    data = json.load(f)


steps = []
for trace in data:
    tr_steps = [ev["token"] for ev in trace["events"]]
    steps.append(tr_steps)

with open(sys.argv[2], "w") as f:
    for trace in steps:
        f.write(", ".join(trace))
        f.write("\n\n")

print(f"Wrote {len(steps)} trace's steps")
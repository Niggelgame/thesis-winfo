import argparse
from collections import defaultdict
import json
import os

def filter_traces(data, filter_func):
    filtered_data = []
    for trace in data:
        filtered_trace = {
            "label": trace["label"],
            "color": trace["color"],
            "file": trace["file"],
            "trace": [event for event in trace["trace"] if filter_func(event)],
        }
        filtered_data.append(filtered_trace)
    return filtered_data

def topic_counts(data):
    merged_traces = [event for trace in data for event in trace["trace"]]

    counts = defaultdict(int)
    for row in merged_traces:
        counts[row["topic"]] += 1
    
    res = dict(counts)
    # sort by count
    res = dict(sorted(res.items(), key=lambda item: item[1], reverse=True))
    for topic, count in res.items():
        print(f"{topic}: {count}")
    return res



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process MQTT JSON data")
    parser.add_argument("input", help="Path to the input JSON file")
    parser.add_argument("--output", help="Path to the output JSON file (optional)")

    parser.add_argument("--mode", choices=["topic_counts"], default="topic_counts", help="Processing mode to apply to the data")

    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"Error: File '{args.input}' does not exist.")
        exit(1)
    
    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)
        # support "old" just trace format
        if isinstance(data, list) and len(data) > 0 and "trace" not in data[0]:
            data = [{ "label": "unknown", "file": "unknown", "trace": data }]

    # apply filters (filters must return True to keep event, False to remove)
    filters = [
         # filter out image lines
        lambda event: not event["topic"] == "/j1/txt/1/i/cam",
        # filter out "blinking actions"
        lambda event: not (event["topic"] == "module/v1/ff/SVR4H92774/instantAction" and event["payload"]["actions"][0]["actionType"] == "setStatusLED")
    ]
    for f in filters:
        data = filter_traces(data, f)
    
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    if args.mode == "topic_counts":
        topic_counts(data)
    
    if args.mode == "to_atom":
        # convert to atoms
        to_atoms(data)

import argparse
from collections import defaultdict
import json
import os


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process MQTT JSON data")
    parser.add_argument("input", help="Path to the input directory containing JSON files")
    parser.add_argument("--output", help="Path to the output JSON file (optional)")

    args = parser.parse_args()

    if not os.path.isdir(args.input):
        print(f"Error: Directory '{args.input}' does not exist.")
        exit(1)
    
    data = []
    for filename in os.listdir(args.input):
        print(f"Processing file: {filename}")
        if filename.endswith(".proc.json"):
            continue
        if filename.endswith(".json"):
            plain_filename = filename[:-5]

            if "bestanden" in plain_filename:
                res = "success"
            elif "Ausschuss" in plain_filename:
                res = "qc-fail"
            elif "Fehler" in plain_filename:
                res = "error"
            else:
                res = "unknown"

            trace_entries = []
            with open(os.path.join(args.input, filename), "r", encoding="utf-8") as f:
                for line in f:
                    trace_entries.append(json.loads(line))
            
            trace = {
                "label": res,
                "file": plain_filename,
                "trace": trace_entries,
            }
            data.append(trace)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

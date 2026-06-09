import json
import random
import math
import pprint

from argparse import ArgumentParser

from shared import predict_next, check_correct_prefix, RANDOM_SEED, VOCAB




def predict_single(artifacts_dir, trace, color, ins_rate):
    correct = 0
    total = 0
    for i in range(2, len(trace)):
        predict_from = trace[:i]

        # never insert after last element
        with_inserted = list(predict_from)[:-1]
        indicee = [i for i, e in enumerate(with_inserted)]
        ins_count = math.ceil(ins_rate * len(predict_from))
        suffixed_indicee = list(random.sample(indicee, ins_count))
        suffixed_indicee.sort()
        for before, i in enumerate(suffixed_indicee):
            added = random.choice(VOCAB)
            # add before, as otherwise not inserted at the original position
            with_inserted.insert(before + i + 1, added)
        with_inserted.append(predict_from[-1])

        next = predict_next(artifacts_dir, color, with_inserted)
        predict_from.append(next)

        total += 1
        is_prefix = check_correct_prefix(trace, predict_from)
        if is_prefix:
            correct += 1
        else:
            print(f"Predicted incorrect. Expected {trace[i]} but got {next}")

    return {
        "total": total,
        "correct": correct
    }


def evaluate(args):
    with open(args.validation_trace_paths, "r") as f:
        traces = json.load(f)
    
    trace_tokens = [
        {"color": trace["color"], "tokens": [ev["token"] for ev in trace["events"]]} for trace in traces]

    ins_rate_stats = {}

    insertion_rates = [0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5]
    random.seed(RANDOM_SEED)
    for insertion_rate in insertion_rates:
        stats = []
        for trace in trace_tokens:
            stats.append(predict_single(args.artifacts_dir, trace["tokens"], trace["color"], insertion_rate))
        
        print(f"InsertionRate: {insertion_rate:.0%}\nAccuracy by trace:")
        total = 0
        correct = 0
        for stat in stats:
            s_correct = stat["correct"]
            s_total = stat["total"]
            correct += s_correct
            total += s_total

            print(f"    {s_correct/s_total:.2%}")
        
        print(f"\nTotal Accuracy: {correct/total:.2%}")
        print("\n\n")#

        ins_rate_stats[insertion_rate] = {
            "accuracy": correct/total
        }
    
    print(pprint.pprint(ins_rate_stats))



if __name__ == "__main__":
    parser = ArgumentParser("simple_scenario")
    parser.add_argument("--artifacts-dir", type=str, default="../../data/model/artifacts")
    parser.add_argument("--validation-trace-paths", type=str, default="../../data/model/val_tokens.json")

    args = parser.parse_args()

    evaluate(args)
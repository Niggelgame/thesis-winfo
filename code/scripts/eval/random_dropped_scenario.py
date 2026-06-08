import json
import random
import math
import pprint

from argparse import ArgumentParser

from shared import predict_next, check_correct_prefix, RANDOM_SEED


def predict_single(artifacts_dir, trace, drop_rate):
    correct = 0
    total = 0
    # start from at least 2 elements to be able to even drop
    # never drop last element
    for i in range(2, len(trace)):
        predict_from = trace[:i]

        # never drop last element
        with_dropped = list(predict_from)[:-1]
        indicee = [i for i, e in enumerate(with_dropped)]
        drop_count = math.ceil(drop_rate * len(predict_from))
        dropped_indicee = set(random.sample(indicee, drop_count))
        with_dropped = [x for i, x in enumerate(with_dropped) if i not in dropped_indicee]
        with_dropped.append(predict_from[-1])


        # print(f"Real Drop Rate: {1 - len(with_dropped)/len(predict_from):2%}")

        next = predict_next(artifacts_dir, with_dropped)
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
    
    trace_tokens = [[ev["token"] for ev in trace["events"]] for trace in traces]

    drop_rate_stats = {}

    drop_rates = [0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5]
    for drop_rate in drop_rates:
        random.seed(RANDOM_SEED)
        stats = []
        for trace in trace_tokens:
            stats.append(predict_single(args.artifacts_dir, trace, drop_rate))
        
        print(f"DropRate: {drop_rate:.0%}\nAccuracy by trace:")
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

        drop_rate_stats[drop_rate] = {
            "accuracy": correct/total
        }
    
    print(pprint.pprint(drop_rate_stats))



if __name__ == "__main__":
    parser = ArgumentParser("simple_scenario")
    parser.add_argument("--artifacts-dir", type=str, default="../../data/model/artifacts")
    parser.add_argument("--validation-trace-paths", type=str, default="../../data/model/val_tokens.json")

    args = parser.parse_args()

    evaluate(args)
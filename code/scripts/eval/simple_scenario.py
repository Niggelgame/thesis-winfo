import json
import random

from argparse import ArgumentParser

from shared import predict_next, predict_next_random, check_correct_prefix, RANDOM_SEED, timer

timings = []

def predict_single(random, artifacts_dir, color, trace):
    correct = 0
    total = 0
    for i in range(1, len(trace)):
        predict_from = trace[:i]
        if random:
            next = predict_next_random()
        else:
            with timer() as elapsed:
                next = predict_next(artifacts_dir, color, predict_from)
                timings.append(elapsed())
        predict_from.append(next)

        total += 1
        try:
            is_prefix = check_correct_prefix(trace, predict_from)
        except Exception:
            is_prefix = False
        
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

    random.seed(RANDOM_SEED + 1)
    stats = []
    for trace in trace_tokens:
        stats.append(predict_single(args.random, args.artifacts_dir, trace["color"], trace["tokens"]))
    
    print("Accuracy by trace:")
    total = 0
    correct = 0
    for stat in stats:
        s_correct = stat["correct"]
        s_total = stat["total"]
        correct += s_correct
        total += s_total

        print(f"    {s_correct/s_total:.2%}")
    
    print(f"\nTotal Accuracy: {correct/total:.2%}")

    if args.time:
        avg_time = sum(timings) / len(timings)

        print(f"Average time: {avg_time}")

        print(f"First time: {timings[0]} - last time: {timings[-1]}")

        avg_time_without_first = sum(timings[1:]) / (len(timings) - 1)
        print(f"Average no first time: {avg_time_without_first}")


if __name__ == "__main__":
    parser = ArgumentParser("simple_scenario")
    parser.add_argument("--random", action='store_true')
    parser.add_argument("--artifacts-dir", type=str, default="../../data/model/artifacts")
    parser.add_argument("--validation-trace-paths", type=str, default="../../data/model/val_tokens.json")
    parser.add_argument("--time", action="store_true")

    args = parser.parse_args()

    evaluate(args)
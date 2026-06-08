import json

from argparse import ArgumentParser

from shared import predict_next, check_correct_prefix


def predict_single(artifacts_dir, trace):
    correct = 0
    total = 0
    for i in range(1, len(trace)):
        predict_from = trace[:i]
        next = predict_next(artifacts_dir, predict_from)
        predict_from.append(next)

        total += 1
        correct = check_correct_prefix(trace, predict_from)
        if correct:
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


    stats = []
    for trace in trace_tokens:
        stats.append(predict_single(args.artifacts_dir, trace))
    
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

        







if __name__ == "__main__":
    parser = ArgumentParser("simple_scenario")
    parser.add_argument("--artifacts-dir", type=str, default="../../data/model/artifacts")
    parser.add_argument("--validation-trace-paths", type=str, default="../../data/model/val_tokens.json")

    args = parser.parse_args()

    evaluate(args)
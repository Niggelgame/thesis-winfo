import json
import random

from argparse import ArgumentParser

from shared import predict_next_topk, predict_next_topk_random, predict_next_topk_occurence, check_correct_prefix, RANDOM_SEED

def predict_single(random, occurency, artifacts_dir, trace, color, topk):
    correct = 0
    total = 0
    for i in range(1, len(trace)):
        predict_from = trace[:i]
        if occurency is not None:
            next = predict_next_topk_occurence(occurency, topk)
        elif random:
            next = predict_next_topk_random(topk)
        else:
            next = predict_next_topk(artifacts_dir, color, predict_from, topk)

        total += 1

        ever_correct = False

        for i in range(topk):
            predict_from.append(next[i]["token"])
            
            try:
                is_prefix = check_correct_prefix(trace, predict_from)
            except Exception:
                is_prefix = False
            if is_prefix:
                ever_correct = True
                break
            
            # remove last added token again
            predict_from.pop()
        
        if ever_correct:
            correct += 1
        else: 
            print(f"Failed to predict correct in {topk} top next!")

    return {
        "total": total,
        "correct": correct
    }


def evaluate(args):
    with open(args.validation_trace_paths, "r") as f:
        traces = json.load(f)
    
    trace_tokens = [
        {"color": trace["color"], "tokens": [ev["token"] for ev in trace["events"]]} for trace in traces]


    random.seed(RANDOM_SEED)
    stats = []
    for trace in trace_tokens:
        stats.append(predict_single(args.random, args.occurency, args.artifacts_dir, trace["tokens"], trace["color"], args.top_x))
    
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
    parser.add_argument("--random", action='store_true')
    parser.add_argument("--occurency", type=str, default=None)
    parser.add_argument("--top-x", type=int, default=2)
    parser.add_argument("--artifacts-dir", type=str, default="../../data/model/artifacts")
    parser.add_argument("--validation-trace-paths", type=str, default="../../data/model/val_tokens.json")

    args = parser.parse_args()

    evaluate(args)
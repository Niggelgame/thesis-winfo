import json

from argparse import ArgumentParser

from shared import predict_next_topk, check_correct_prefix

TOP_X = 2

def predict_single(artifacts_dir, trace, topk):
    correct = 0
    total = 0
    for i in range(1, len(trace)):
        predict_from = trace[:i]
        next = predict_next_topk(artifacts_dir, predict_from, topk)

        total += 1

        ever_correct = False

        for i in range(topk):
            predict_from.append(next[i]["token"])
            
            is_prefix = check_correct_prefix(trace, predict_from)
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
    
    trace_tokens = [[ev["token"] for ev in trace["events"]] for trace in traces]


    stats = []
    for trace in trace_tokens:
        stats.append(predict_single(args.artifacts_dir, trace, TOP_X))
    
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
import argparse
import json
from pathlib import Path

import torch

from simple_step_trace_preprocessor import extract_traces_and_timings
from pipeline import TrainConfig, cross_validate_and_select, train_final_model, predict_topk_next, save_artifacts, load_artifacts


def select_device(device_arg: str, force_cpu: bool) -> torch.device:
    if force_cpu:
        return torch.device("cpu")

    if device_arg == "cpu":
        return torch.device("cpu")
    if device_arg == "cuda":
        if torch.cuda.is_available():
            return torch.device("cuda")
        raise ValueError("CUDA requested but not available.")
    if device_arg == "mps":
        if torch.backends.mps.is_available():
            return torch.device("mps")
        raise ValueError("MPS requested but not available.")

    # auto: prefer CUDA, then Apple MPS, then CPU
    if torch.cuda.is_available():
        return torch.device("cuda")
    if torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


def cmd_preprocess(args: argparse.Namespace) -> None:
    traces = extract_traces_and_timings(args.data)
    print(f"Extracted {len(traces)} traces from {args.data}")

    if args.out_json:
        out_traces = []
        for trace in traces:
            out_traces.append({
                "events": [event.to_dict() for event in trace["events"]],
                "rejected_events": {reason.value: [e for e in evs] for reason, evs in trace.get("rejected_events", {}).items()},
                "timings": trace["timings"],
            })

        out_path = Path(args.out_json)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(out_traces, f, indent=2)
        print(f"Saved preprocessed traces to {out_path}")


def cmd_train(args: argparse.Namespace) -> None:
    device = select_device(args.device, args.force_cpu)

    # Load traces from file 
    with open(args.data_preproc, "r") as f:
        traces = json.load(f)
    print(f"Loaded {len(traces)} traces")
    print(f"Using device: {device}")

    if len(traces) < 6:
        raise ValueError("Dataset is too small for robust training; need at least 8 traces.")

    # TODO: change some params if they should be overwritten
    base_cfg = TrainConfig()
    best_cfg, search_summary = cross_validate_and_select(
        traces,
        base_cfg=base_cfg,
        device=device,
        max_configs=args.search_configs,
    )
    print("Best hyperparameters:")
    print(best_cfg)

    model, vocab = train_final_model(traces, cfg=best_cfg, device=device)
    save_artifacts(Path(args.artifacts_dir), model, vocab, best_cfg, search_summary)
    print(f"Saved model artifacts to {args.artifacts_dir}")


def predict_wrap(artifacts_dir, device, force_cpu, events, steps, topk):
    device = select_device(device, force_cpu)
    print(f"Using device: {device}")
    model_path = Path(artifacts_dir) / "model.pt"
    model, vocab, idx_to_value, _cfg = load_artifacts(model_path, device=device)

    pred_steps = predict_topk_next(
        model=model,
        initial_events=events,
        vocab=vocab,
        idx_to_value=idx_to_value,
        steps=steps,
        topk=topk,
        device=device,
    )

    return pred_steps

def cmd_predict(args: argparse.Namespace) -> None:
    # parse seed trace
    with open(args.data, "r") as f:
        events = list(map(lambda e: e.strip(), f.read().split(",")))

    print(f"Found trace with {len(events)} steps.")

    if args.prefix_cut == -1:
        initial_events = events
    else:
        initial_events = events[:args.prefix_cut]

    pred_steps = predict_wrap(args.artifacts_dir, args.device, args.force_cpu, initial_events, args.steps, args.topk)

    print("Seed events:")
    for event in initial_events:
        print(f"  {event}")
    
    
    print("Predictions:")
    for i, p in enumerate(pred_steps):
        print(f"Step +{p['step']}: {p['predicted_event']}")
        for cand in p["topk"]:
            print(
                f"  token={cand['token']} | p={cand['probability']:.4f}"
            )

    print("Remaining Reality")
    for i in range(len(initial_events), len(events)):
        print(f"    {events[i]}")



def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Process prediction with transformer")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_pre = sub.add_parser("preprocess", help="Extract token traces")
    p_pre.add_argument("--data", type=str, default="collected-filtered.proc.json")
    p_pre.add_argument("--out-json", type=str, default="")
    p_pre.set_defaults(func=cmd_preprocess)

    p_train = sub.add_parser("train", help="Tune hyperparameters with k-fold and train final model")
    p_train.add_argument("--data-preproc", type=str, default="../../data/model/preprocessed_tokens.json")
    p_train.add_argument("--artifacts-dir", type=str, default="../../data/model/artifacts")
    p_train.add_argument("--device", type=str, choices=["auto", "cpu", "cuda", "mps"], default="auto")
    p_train.add_argument("--force-cpu", action="store_true")
    # whether to limit the number of hyperparameter configs to search through
    p_train.add_argument("--search-configs", type=int, default=0)
    p_train.set_defaults(func=cmd_train)
    

    p_pred = sub.add_parser("predict", help="Run top-k next-event prediction")
    # the file containing trace samples
    p_pred.add_argument("--data", type=str, default="token-trace")
    p_pred.add_argument("--artifacts-dir", type=str, default="../../data/model/artifacts")
    p_pred.add_argument("--prefix-cut", type=int, default=-1, help="Whether the trace should be cut off at a certain position")
    # how many steps to predict
    p_pred.add_argument("--steps", type=int, default=1)
    p_pred.add_argument("--topk", type=int, default=3)
    p_pred.add_argument("--device", type=str, choices=["auto", "cpu", "cuda", "mps"], default="auto")
    p_pred.add_argument("--force-cpu", action="store_true")
    p_pred.set_defaults(func=cmd_predict)

    return parser


if __name__ == "__main__":
    parser = build_arg_parser()
    args = parser.parse_args()
    args.func(args)
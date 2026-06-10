import itertools
import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, Dataset

from ml_model.simple_step_trace_preprocessor import build_vocab, NA
from ml_model.model import ProcessPredictionTransformer, generate_causal_mask


@dataclass
class TrainConfig:
    max_len: int = 128 # maximum length of sequences in one transformer run
    batch_size: int = 8
    epochs: int = 24 # how many training epochs should exist
    lr: float = 2e-3 # learning rate for adamw optimizer
    weight_decay: float = 1e-2 # weight decay for optimizer
    # TODO: change to 0.1?
    dropout: float = 0.2 # probability to disable some neurons during training 
    label_smoothing: float = 0.05 # don't try to one-hot encode 
    d_model: int = 64 # embedding dimension
    nhead: int = 4 # number of transformer attention heads
    num_layers: int = 2 # number of stacked transformer encoder layers
    dim_feedforward: int = 128 # what the dimension the FF-Network has after each transformer layer
    grad_clip: float = 1.0 # what kind of norm maximum of parameters should be
    patience: int = 8 # during cross validation, how many attempts at bettering should be done
    k_folds: int = 4 # how many k fold splits
    seed: int = 42 # randomness seed

# torch represenation of dataset 
class ProcessTraceDataset(Dataset):
    def __init__(self, traces: List[Dict[str, List[Any]]], vocab: Dict[str, int], max_len: int = 128):
        self.traces = traces
        self.vocab = vocab
        self.max_len = max_len

    def __len__(self) -> int:
        return len(self.traces)

    def _event_to_id(self, value: str) -> int:
        return self.vocab.get(value, self.vocab[NA])

    def __getitem__(self, idx: int):
        trace = self.traces[idx]
        events = trace["events"][: self.max_len - 2]
        events = map(lambda e: e["token"], events)

        # turn tokens into numbers
        seq: List[int] = {}
        seq = [self.vocab["<BOS>"]]

        if trace["color"] and trace["color"] != "unknown":
            seq.append(self.vocab[f"<COLOR {trace["color"]}>"])

        seq.extend(self._event_to_id(ev) for ev in events)
        seq.append(self.vocab["<EOS>"])

        # pad
        pad_len = self.max_len - len(seq)
        seq += [self.vocab["<PAD>"]] * pad_len

        # get map from token to next token on same index
        x = torch.tensor(seq[:-1], dtype=torch.long) 
        y = torch.tensor(seq[1:], dtype=torch.long)
        
        return x, y

# to rule out randomness in evaluation
def set_seed(seed: int) -> None:
    random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


# create array splits into k arrays -> create training / validation datasets without much data
def create_kfold_splits(n: int, k_folds: int, seed: int) -> List[Tuple[List[int], List[int]]]:
    indices = list(range(n))
    rng = random.Random(seed)
    rng.shuffle(indices)

    fold_sizes = [n // k_folds] * k_folds
    for i in range(n % k_folds):
        fold_sizes[i] += 1

    splits = []
    offset = 0
    for fold_size in fold_sizes:
        val_idx = indices[offset : offset + fold_size]
        train_idx = indices[:offset] + indices[offset + fold_size :]
        splits.append((train_idx, val_idx))
        offset += fold_size
    return splits

# provide the top k hits of tokens
def token_metrics(logits: torch.Tensor, y: torch.Tensor, pad_id: int, topk: int = 3) -> Tuple[float, float]:
    with torch.no_grad():
        mask = y != pad_id
        if mask.sum().item() == 0:
            return 0.0, 0.0

        pred = torch.argmax(logits, dim=-1)
        top1_acc = ((pred == y) & mask).sum().item() / mask.sum().item()

        topk_idx = torch.topk(logits, k=min(topk, logits.size(-1)), dim=-1).indices
        y_expanded = y.unsqueeze(-1).expand_as(topk_idx)
        topk_hit = (topk_idx == y_expanded).any(dim=-1)
        topk_acc = (topk_hit & mask).sum().item() / mask.sum().item()
        return top1_acc, topk_acc


def one_epoch(
    model: ProcessPredictionTransformer,
    loader: DataLoader,
    optimizer: torch.optim.Optimizer,
    criterium: nn.Module,
    vocab: Dict[str, int],
    device: torch.device,
    grad_clip: float,
    train: bool,
) -> Dict[str, float]:
    model.train(mode=train)

    total_loss = 0.0
    total_top1 = 0.0
    total_topk = 0.0
    batches = 0

    pad = vocab["<PAD>"]

    for x, y in loader:
        x = x.to(device)
        y = y.to(device)
        
        seq_len = x.size(1)
        src_mask = generate_causal_mask(seq_len, device=device)
        pad_mask = x.eq(pad)

        if train:
            optimizer.zero_grad()

        logits = model(
            x,
            src_mask=src_mask,
            src_padding_mask=pad_mask,
        )

        target = y
        loss = criterium(logits.reshape(-1, logits.size(-1)), target.reshape(-1))

        if train:
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), grad_clip)
            optimizer.step()

        top1, topk = token_metrics(logits, target, pad_id=pad, topk=3)

        total_loss += float(loss.item())
        total_top1 += top1
        total_topk += topk
        batches += 1

    if batches == 0:
        return {
            "loss": 0.0,
            "top1": 0.0,
            "topk": 0.0
        }

    return {
        "loss": total_loss / batches,
        "top1": total_top1 / batches,
        "topk": total_topk / batches,
    }

# build search space for model parameters
def build_search_space() -> List[Dict[str, Any]]:
    d_models = [18, 32, 64]
    layers = [1, 2, 3]
    dropouts = [0.1, 0.2, 0.3]
    learning_rates = [3e-3, 1e-3]

    configs: List[Dict[str, Any]] = []
    for d_model, n_layers, dropout, lr in itertools.product(d_models, layers, dropouts, learning_rates):
        nhead = 4 if d_model % 4 == 0 else 2
        configs.append(
            {
                "d_model": d_model,
                "num_layers": n_layers,
                "dropout": dropout,
                "lr": lr,
                "dim_feedforward": d_model * 4,
                "nhead": nhead,
            }
        )
    return configs


# creates loss function for tokens
def build_criteria(vocab: Dict[str, int], label_smoothing: float) -> nn.Module:
    return nn.CrossEntropyLoss(ignore_index=vocab["<PAD>"], label_smoothing=label_smoothing)


def cross_validate_and_select(
    traces: List[Dict[str, List[Any]]],
    base_cfg: TrainConfig,
    device: torch.device,
    max_configs: int = 0,
) -> Tuple[TrainConfig, Dict[str, Any]]:
    set_seed(base_cfg.seed)
    vocab = build_vocab()

    if len(traces) < base_cfg.k_folds:
        raise ValueError("Not enough traces for configured k-fold cross validation.")

    search_space = build_search_space()
    if max_configs and max_configs > 0:
        search_space = search_space[:max_configs]

    best_cfg = None
    best_score = -1.0
    all_results: List[Dict[str, Any]] = []

    for i, hp in enumerate(search_space, start=1):
        cfg = TrainConfig(**{**base_cfg.__dict__, **hp})
        splits = create_kfold_splits(len(traces), cfg.k_folds, cfg.seed)

        fold_metrics = []
        for fold_i, (train_idx, val_idx) in enumerate(splits, start=1):
            # training
            train_ds = ProcessTraceDataset([traces[j] for j in train_idx], vocab=vocab, max_len=cfg.max_len)
            # validation
            val_ds = ProcessTraceDataset([traces[j] for j in val_idx], vocab=vocab, max_len=cfg.max_len)

            train_loader = DataLoader(train_ds, batch_size=cfg.batch_size, shuffle=True)
            val_loader = DataLoader(val_ds, batch_size=cfg.batch_size, shuffle=False)

            model = ProcessPredictionTransformer(
                vocab_size=len(vocab),
                d_model=cfg.d_model,
                nhead=cfg.nhead,
                num_layers=cfg.num_layers,
                dim_feedforward=cfg.dim_feedforward,
                dropout=cfg.dropout,
            ).to(device)

            optimizer = torch.optim.AdamW(model.parameters(), lr=cfg.lr, weight_decay=cfg.weight_decay)
            scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="min", factor=0.5, patience=2)
            criterium = build_criteria(vocab, cfg.label_smoothing)

            best_fold_val = float("inf")
            best_fold_metrics: Dict[str, float] = {}
            no_improve = 0

            for _epoch in range(cfg.epochs):
                one_epoch(
                    model,
                    train_loader,
                    optimizer,
                    criterium,
                    vocab,
                    device,
                    grad_clip=cfg.grad_clip,
                    train=True,
                )
                val_metrics = one_epoch(
                    model,
                    val_loader,
                    optimizer,
                    criterium,
                    vocab,
                    device,
                    grad_clip=cfg.grad_clip,
                    train=False,
                )
                scheduler.step(val_metrics["loss"])

                if val_metrics["loss"] < best_fold_val:
                    best_fold_val = val_metrics["loss"]
                    best_fold_metrics = val_metrics
                    no_improve = 0
                else:
                    no_improve += 1
                    if no_improve >= cfg.patience:
                        break

            fold_metrics.append(best_fold_metrics)
            print(
                f"[search {i}/{len(search_space)}] fold {fold_i}/{cfg.k_folds} "
                f"val_loss={best_fold_metrics.get('loss', 0.0):.4f} "
                f"base_top1={best_fold_metrics.get('top1', 0.0):.3f} "
                f"base_top3={best_fold_metrics.get('topk', 0.0):.3f} "
            )

        avg_top1 = sum(m.get("top1", 0.0) for m in fold_metrics) / len(fold_metrics)
        avg_topk = sum(m.get("topk", 0.0) for m in fold_metrics) / len(fold_metrics)

        score = avg_top1 + 0.5 * avg_topk

        result = {
            "config": cfg.__dict__,
            "avg_top1": avg_top1,
            "avg_top3": avg_topk,
            "score": score,
        }
        all_results.append(result)
        print(
            f"[search {i}/{len(search_space)}] avg_top1={avg_top1:.3f} "
            f"avg_top3={avg_topk:.3f} score={score:.3f}"
        )

        if score > best_score:
            best_score = score
            best_cfg = cfg

    assert best_cfg is not None
    all_results.sort(key=lambda r: r["score"], reverse=True)
    return best_cfg, {"results": all_results, "vocab_size": len(vocab)}


def train_final_model(
    traces: List[Dict[str, List[Any]]],
    cfg: TrainConfig,
    device: torch.device,
) -> Tuple[ProcessPredictionTransformer, Dict[str, Dict[str, int]]]:
    set_seed(cfg.seed)
    vocab = build_vocab()
    dataset = ProcessTraceDataset(traces, vocab=vocab, max_len=cfg.max_len)
    loader = DataLoader(dataset, batch_size=cfg.batch_size, shuffle=True)

    model = ProcessPredictionTransformer(
        vocab_size=len(vocab),
        d_model=cfg.d_model,
        nhead=cfg.nhead,
        num_layers=cfg.num_layers,
        dim_feedforward=cfg.dim_feedforward,
        dropout=cfg.dropout,
    ).to(device)

    optimizer = torch.optim.AdamW(model.parameters(), lr=cfg.lr, weight_decay=cfg.weight_decay)
    criterium = build_criteria(vocab, cfg.label_smoothing)

    for epoch in range(cfg.epochs):
        metrics = one_epoch(
            model,
            loader,
            optimizer,
            criterium,
            vocab,
            device,
            grad_clip=cfg.grad_clip,
            train=True,
        )
        print(
            f"[final train] epoch {epoch + 1}/{cfg.epochs} "
            f"loss={metrics['loss']:.4f} base_top1={metrics['top1']:.3f} "
            f"base_top3={metrics['topk']:.3f}"
        )

    return model, vocab


def save_artifacts(
    out_dir: Path,
    model: ProcessPredictionTransformer,
    vocab: Dict[str, int],
    cfg: TrainConfig,
    search_summary: Dict[str, Any],
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)

    idx_to_value = {int(v): k for k, v in vocab.items()}

    torch.save(
        {
            "model_state": model.state_dict(),
            "vocab": vocab,
            "idx_to_value": idx_to_value,
            "config": cfg.__dict__,
        },
        out_dir / "model.pt",
    )

    with open(out_dir / "search_summary.json", "w", encoding="utf-8") as f:
        json.dump(search_summary, f, indent=2)


def load_artifacts(model_path: Path, device: torch.device):
    payload = torch.load(model_path, map_location=device)
    cfg = TrainConfig(**payload["config"])
    vocab = payload["vocab"]

    model = ProcessPredictionTransformer(
        vocab_size=len(vocab),
        d_model=cfg.d_model,
        nhead=cfg.nhead,
        num_layers=cfg.num_layers,
        dim_feedforward=cfg.dim_feedforward,
        dropout=cfg.dropout,
    ).to(device)

    num_of_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    # print(f"loading model with {num_of_params} parameters")
    state = payload["model_state"]
    # add params here in case model changed
    missing = []
    has_new_params = all(k in state for k in missing)
    if has_new_params:
        model.load_state_dict(state)
    else:
        print("Warning: loading legacy checkpoint.")
        print("Warning: retrain recommended to fully use new model.")
        model.load_state_dict(state, strict=False)
    model.eval()

    return model, vocab, payload["idx_to_value"], cfg



def predict_topk_next(
    model: ProcessPredictionTransformer,
    initial_events: Sequence[str],
    color: str,
    vocab: Dict[str, int],
    idx_to_value: Dict[int, str],
    steps: int,
    topk: int,
    device: torch.device,
) -> List[Dict[str, Any]]:
    seq: List[int] =  [vocab["<BOS>"]]
    if color and color != "unknown":
        seq.append(vocab[f"<COLOR {color}>"])

    for ev in initial_events:
        seq.append(vocab.get(ev, vocab[NA]))

    predictions: List[Any] = []

    for step_i in range(steps):
        x = torch.tensor([seq], dtype=torch.long, device=device)

        mask = generate_causal_mask(x.size(1), device=device)

        with torch.no_grad():
            logits = model(x, src_mask=mask)

        base_logits = logits[0, -1, :]
        base_probs = torch.softmax(base_logits, dim=-1)

        k = min(topk, base_probs.numel())
        top_vals, top_idx = torch.topk(base_probs, k=k)
        top_candidates = []
        for p, idx in zip(top_vals.tolist(), top_idx.tolist()):
            token = idx_to_value.get(int(idx), "<UNK>")
            top_candidates.append({"token": token, "probability": round(float(p), 4)})

        next_event: str = None

        ids = torch.argsort(base_logits, descending=True).tolist()
        if len(ids) == 0:
            next_event = "<UNK>"
        else:
            idx = ids[0]
            next_event = idx_to_value.get(int(idx), NA)

        predictions.append(
            {
                "step": step_i + 1,
                "topk": top_candidates,
                "predicted_event": next_event,
            }
        )

        if next_event == "<EOS>":
            break

        seq.append(vocab.get(next_event, vocab[NA]))

    return predictions

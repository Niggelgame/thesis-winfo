import os
import sys
import importlib
from pathlib import Path

from heraklit_equiv_checker.checker import check_equivalence_step_file
from ml_model.main import predict_wrap

RANDOM_SEED = 42


# returns [{"token": <>, "probability": <>}]
def predict_next_topk(artifacts_dir, color, steps, topk):
    res = predict_wrap(artifacts_dir, "auto", False, False, color, steps, 1, topk)
    assert len(res) == 1
    return res[0]["topk"]

def predict_next(artifacts_dir, color, steps):
    res = predict_next_topk(artifacts_dir, color, steps, 1)
    if len(res) < 1:
        return None
    else: 
        return res[0]["token"]


def check_correct_prefix(full_trace, sub_trace):
    here_path = os.path.abspath(os.path.dirname(__file__))
    step_def_path = Path(here_path).parent / "heraklit_equiv_checker" / "tests" / "step_defs" / "fischertechnik_steps.json"
    return check_equivalence_step_file(full_trace, sub_trace, step_def_path.absolute(), enable_warnings=False)


# TODO: Graph / Table generation code 
import os
import sys
import importlib
from pathlib import Path

from heraklit_equiv_checker.checker import check_equivalence_step_file
from ml_model.main import predict_wrap

RANDOM_SEED = 42

VOCAB = [
    "AGV move HBW to DPS",
    "AGV move HBW to MILL",
    "AGV move HBW to DRILL",
    "AGV move HBW to AIQS",
    "AGV move DPS to HBW",
    "AGV move DPS to MILL",
    "AGV move DPS to DRILL",
    "AGV move DPS to AIQS",
    "AGV move MILL to HBW",
    "AGV move MILL to DPS",
    "AGV move MILL to DRILL",
    "AGV move MILL to AIQS",
    "AGV move DRILL to HBW",
    "AGV move DRILL to DPS",
    "AGV move DRILL to MILL",
    "AGV move DRILL to AIQS",
    "AGV move AIQS to HBW",
    "AGV move AIQS to DPS",
    "AGV move AIQS to MILL",
    "AGV move AIQS to DRILL",
    "HBW Pick",
    "HBW Picked",
    "HBW Pick Failed",
    "HBW Drop",
    "HBW Dropped",
    "HBW Drop Failed",
    "DPS Pick",
    "DPS Picked",
    "DPS Pick Failed",
    "DPS Drop",
    "DPS Dropped",
    "DPS Drop Failed",
    "DRILL Pick",
    "DRILL Picked",
    "DRILL Pick Failed",
    "DRILL Drop",
    "DRILL Dropped",
    "DRILL Drop Failed",
    "DRILL Drill",
    "DRILL Drilled",
    "DRILL Drill Failed",
    "MILL Pick",
    "MILL Picked",
    "MILL Pick Failed",
    "MILL Drop",
    "MILL Dropped",
    "MILL Drop Failed",
    "MILL Mill",
    "MILL Milled",
    "MILL Mill Failed",
    "AIQS Pick",
    "AIQS Picked",
    "AIQS Pick Failed",
    "AIQS Drop",
    "AIQS Dropped",
    "AIQS Drop Failed",
    "AIQS Check",
    "AIQS Checked",
    "AIQS Check Failed",
]

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
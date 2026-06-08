import sys
import json
import random
import math

# predefined ration of train to validation
TRAIN_TO_VAL = 0.7
RANDOM_SEED = 42

if len(sys.argv) != 4:
    print("Usage: random_split_preprocessed.py <in_file> <out_file_train> <out_file_val>")
    exit(1)

with open(sys.argv[1], "r") as f:
    data = json.load(f)

random.seed(RANDOM_SEED)

random.shuffle(data)

# -1 for idx
last_train_idx = math.floor(0.7 * len(data))

train = data[0:last_train_idx]
val = data[last_train_idx:]

with open(sys.argv[2], "w") as f:
    json.dump(train, f)

with open(sys.argv[3], "w") as f:
    json.dump(val, f)

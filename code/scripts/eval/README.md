# Evaluation

Evaluation consists of multiple evaluated scenarios. 

1. Predict in previously unseen trace sequences. Check validity with `heraklit-equiv-checker`.
2. Remove some events from the traces and predict on them, then do check with original trace
3. Add some completely unrelated events into the traces and predict on them, then check for validity with original trace

## Simple szenario


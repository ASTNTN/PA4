# BPM Tuning Spaces

Tuning parameters and exploration space for each variant. The user may
explore additional parameters too, by changing `shared/harness/args.c`.

---

## 00-GSQ

No tuning parameters. Reference baseline.

## 01-OPQ

No sequential tuning (loop order fixed). Parallel: `schedule`, chunk
size, `reduction` — guided by investigation. `collapse` is illegal;
the `nowait` diagnostic run lands under `results/diagnostic/`
(`--allow-gate-failure`).

## 02-EXQ

Same exploration space as OPQ. Question: do different loop orders
require different scheduling strategies?

## 03-BKQ

Block size (BS) — explore a range, including non-power-of-two values.
Also explore `schedule`/chunk/`collapse`/`nowait` as needed.

## 04-DCQ

LEAF_SIZE (degree threshold) and DEPTH (task-spawn cutoff). Leaf
kernel: best of OPQ/EXQ/BKQ, decided by measurement, not assumption.

## 05-DCP

Race-handling strategy needs discussion first: limited parallelism,
private copies, synchronization, task reductions, or custom. May
require shared-infrastructure changes (memory allocation, function
signatures) — Claude helps implement directly once a strategy is
chosen.

## Summary Table

| variant | parameter | guidance |
|---|---|---|
| GSQ | (none) | Reference baseline |
| OPQ | (none sequential) | `schedule`, chunk, `collapse` |
| EXQ | (none sequential) | Same as OPQ; compare to it |
| BKQ | Block size | Range incl. non-power-of-2 |
| DCQ | LEAF_SIZE | Coarse then fine sweep |
| DCP | LEAF_SIZE + DEPTH | Plus race-avoidance strategy |

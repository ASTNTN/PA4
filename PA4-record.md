# PA4 Record

Machine: E-cores 16-31, TPP = 35.2 GFLOPs/s per core (`--tpp-per-core 35.2`).
Binding: `_gate.sh` defaults (sequential runs pinned to core 16).

PA4 (`PA4.md`): write DCQ and compare it with the earlier sequential
variants, then parallelize it with OpenMP tasks (DCP): (1) near-perfect
speedup with task reductions; (2) best speedup without reductions, using
correctly placed taskwaits, with a work/span analysis and prediction made
before running; (3) another coarse-grain race-free strategy without
reductions, and/or further vectorization of the leaf toward TPP.

## 04-DCQ: Divide-and-conquer (sequential)

### DCQ.1: naive baseline, OPQ leaf, always-quadrant split

#### Introduction

PA4 starts from a sequential divide-and-conquer kernel (VARIANTS.md
04-DCQ: recursively divide into quadrants, switch to a leaf kernel below a
leaf-size threshold). This first version is a plain baseline to compare
against OPQ/EXQ/BKQ before choosing the best leaf kernel by measurement.

#### Hypothesis

(To be stated by the student before the timed run.)

#### Design

Decisions (user):

- Leaf kernel: OPQ loop order (i outer, j inner) over the sub-ranges.
- Split: always quadrants. a is halved at na/2 and b at nb/2, giving 4
  sub-multiplies; each adds into c at offset (a offset + b offset). A half
  of length 0 (halving a length-1 range) is an empty sub-problem and
  returns immediately, so when dA and dB are very unequal the short side
  stops shrinking while the long side keeps splitting.
- Leaf rule: a sub-problem is a leaf when both of its ranges have at most
  `leaf_size` coefficients. Runtime knob `--tune leaf_size=N`, fallback 64
  (the shared gate tune's value).

```
dcq(a, na, b, nb, c):
    if na <= 0 or nb <= 0: return
    if na <= leaf and nb <= leaf:
        for i in 0..na-1: for j in 0..nb-1: BPM_ACC(c, comp, i + j, a[i] * b[j])
        return
    ha = na / 2, hb = nb / 2
    dcq(a,      ha,      b,      hb,      c)
    dcq(a,      ha,      b + hb, nb - hb, c + hb)
    dcq(a + ha, na - ha, b,      hb,      c + ha)
    dcq(a + ha, na - ha, b + hb, nb - hb, c + ha + hb)
```

c is zeroed once in kernel_multiply before the top-level call. In the
checking build the Kahan compensation array is passed down at the same
offset as c (`COMP_PARAM`/`COMP_ARG`, as in BKP5); in the timed build it
is compiled out. All pointer parameters are `restrict`.

#### Implementation

`04-DCQ/` (Makefile and run.sh copied from `01-OPQ`, variant name `DCQ`;
kernel in `src/PolyMult.c`). Built with no warnings. Gate PASSED: oracle
42/42 and gold 14/14, on both `PolyMult.check` and `PolyMult.check-par`.
The gate runs with leaf_size=64 only (shared gate tune).

#### Experiment

Sequential baseline at the PA3 comparison size, untuned (leaf_size=64),
recorded as DCQ's T(seq) for 100000x100000. Settings follow the PA3
baseline convention (BKP1-BKP5, BKQ6, BKQ7); the user gave the go-ahead
without specifying them.

```
./sweep.sh --variant-dir 04-DCQ --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
```

Gate passed again inside the sweep. Another user's niced Python jobs were
running (load average 2.1 before, 3.7 after); reps show no visible effect.

#### Results

Median of 7: 2.7405 s, 7.30 GFLOPs/s (20.7% TPP). Rep spread: all 7 reps
within 0.04% of the median (2.7403-2.7413 s). Recorded in
`04-DCQ/results/seq_time.json` (100000x100000 entry).

Earlier single-core results for comparison, all at or near this size (from
PA3-record.md / notes.md; not re-measured here):

| variant (setting)       | GF/s  | % TPP |
|-------------------------|------:|------:|
| OPQ (160000x160000)     | ~9.4  | ~26.5 |
| BKQ, bs=64 (8000x2000)  | 8.90  | 25.3  |
| BKQ, bs=3072            | 13.22 | 37.6  |
| BKQ7, bs=768            | 25.40 | 72.2  |
| **DCQ, leaf=64**        | 7.30  | 20.7  |

- DCQ at leaf=64 is slower than plain OPQ at a large size and slower than
  BKQ with 64x64 blocks (at a smaller size); not explained.

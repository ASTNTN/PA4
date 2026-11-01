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

#### Conclusion

(To be stated by the student.)

### DCQ.2: leaf size sweep

#### Introduction

DCQ.1 ran at 20.7% TPP with leaf_size=64, slower than OPQ and than BKQ
with 64x64 blocks. Halving until a range is at most leaf_size leaves
leaves somewhere between leaf_size/2 and leaf_size long, so leaf_size=64
gives leaves of only 33-64 coefficients per side.

#### Hypothesis

(Student's reasoning.) The leaves are too small; larger leaf sizes should
improve performance.

#### Design / Experiment

DCQ.1 code unchanged. Leaf-size sweep at the same size, 1 thread, 7 reps:

```
./sweep.sh --variant-dir 04-DCQ --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --tune leaf_size=16,32,64,96,128,256,512,1024,2048,4096,8192,16384 \
    --name 2026.11.01.002_leaf_sweep_100000x100000
../PA3/.venv/bin/python plot.py \
    --csv 04-DCQ/results/2026.11.01.002_leaf_sweep_100000x100000.csv \
    --tpp-per-core 35.2 --topic LeafSizeSweep100000x100000 \
    --title "DCQ (OPQ leaf) leaf size sweep, 100000x100000, 1 core"
```

(PA4 has no `.venv` and the system Python lacks `xlsxwriter`, so PA4's
plot.py was run with PA3's venv Python.) Gate passed inside the sweep.
Another user's niced Python jobs were running (load average 1.8 before,
2.6 after).

#### Results

Median of 7. "Leaf length" is the length of each side of a leaf at
100001 coefficients: 100001 / 2^levels, the first halving at or below
leaf_size (arithmetic, not measured).

| leaf_size | levels | leaf length | time (s) | GF/s  | % TPP |
|----------:|-------:|------------:|---------:|------:|------:|
| 16        | 13     | ~12         | 9.564    | 2.09  | 5.9   |
| 32        | 12     | ~24         | 5.029    | 3.98  | 11.3  |
| 64        | 11     | ~49         | 2.738    | 7.30  | 20.8  |
| 96        | 11     | ~49         | 2.737    | 7.31  | 20.8  |
| 128       | 10     | ~98         | 1.857    | 10.77 | 30.6  |
| 256       | 9      | ~195        | 1.707    | 11.72 | 33.3  |
| 512       | 8      | ~391        | 1.655    | 12.08 | 34.3  |
| 1024      | 7      | ~781        | 1.737    | 11.51 | 32.7  |
| 2048      | 6      | ~1563       | 1.680    | 11.90 | 33.8  |
| 4096      | 5      | ~3125       | 1.651    | **12.12** | **34.4** |
| 8192      | 4      | ~6250       | 2.238    | 8.94  | 25.4  |
| 16384     | 3      | ~12500      | 2.176    | 9.19  | 26.1  |

Rep spread <= 0.3% everywhere except leaf_size=8192 (one rep +1.1%).

- leaf_size 64 and 96 give the same time (both produce ~49-long leaves),
  and match DCQ.1's baseline (2.741 s).
- Rate rises steeply up to leaf length ~98 (5.9% -> 30.6%), then
  plateaus at 32.7-34.4% for leaf lengths ~195-3125. Best: 12.12 GF/s
  (34.4%) at leaf_size=4096, with 512 within 0.3%.
- The plateau is not flat: 1024 (~781) dips below both 512 and 2048.
- Above 4096 the rate drops to ~25-26%, near OPQ's large-size rate
  (~26.5%).
- The plateau (~34%) stays below BKQ's ~37% at 100K and far below BKQ7's
  72%.

Plot: `04-DCQ/plots/2026.11.01.001.LeafSizeSweep100000x100000.xlsx`.

#### Conclusion

(To be stated by the student.)

## 04-DCQ2: DCQ + 64-byte-aligned b sub-ranges (sequential)

### DCQ2.1: aligned copy of b, splits of b rounded to 16 floats

#### Introduction

DCQ.2 put DCQ's best rate at 34.4% TPP (leaf_size=4096), below BKQ's ~37%.
In DCQ the b sub-range of each leaf starts at an arbitrary float offset:
b comes from the harness's plain `malloc` (16-byte aligned by default,
`BPM_ALIGN=0`), and the split points nb/2 land anywhere. In PA3, aligning
the b windows (BKQ4) removed most split loads.

#### Hypothesis

(To be stated by the student.)

#### Design

Decisions (user): new directory `04-DCQ2`; aligned copy of b with split
points rounded; default leaf_size 4096 (DCQ.2 best). DCQ unchanged
otherwise (OPQ leaf, always-quadrant split, leaf when both ranges <=
leaf_size):

- Once per call, b is copied into a 64-byte-aligned buffer
  (`aligned_alloc(64, ...)`, size rounded up to whole 64-byte lines); the
  copy is inside the timed kernel. The recursion reads only the copy.
- b's split point is `hb = (nb / 2) & ~15`: nb/2 rounded down to a
  multiple of 16 floats (64 bytes). If a b sub-range starts aligned, both
  halves do, so every leaf's b window starts on a 64-byte boundary. The
  b halves are now unequal by up to 15 floats.
- Fallback: for nb < 32 that rounding gives 0 (empty half, no progress),
  so hb = nb/2 unrounded; only reachable with leaf_size < 32.
- a's split (na/2) and c are not aligned. In the OPQ leaf the c window
  c[i + j] still shifts by one float per row i.

#### Implementation

`04-DCQ2/` (copied from `04-DCQ`, variant name `DCQ2`; kernel in
`src/PolyMult.c`). Built with no warnings. Gate PASSED: oracle 42/42 and
gold 14/14, on both `PolyMult.check` and `PolyMult.check-par`. The gate
runs with leaf_size=64 (shared gate tune), so it exercises the rounded
splits but not the nb < 32 fallback or the 4096 default.

#### Experiment

Same as DCQ.1: sequential baseline, untuned (now leaf_size=4096, DCQ2's
default), recorded as DCQ2's T(seq) for 100000x100000.

```
./sweep.sh --variant-dir 04-DCQ2 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
```

Gate passed again inside the sweep. Load average 1.8 before, 2.7 after
(another user's niced jobs).

#### Results

Median of 7: 2.2716 s, 8.80 GFLOPs/s (25.0% TPP). Reps 2.2670-2.2730 s,
within 0.2% of the median. Recorded in `04-DCQ2/results/seq_time.json`.

| variant (leaf_size)       | time (s) | GF/s  | % TPP |
|---------------------------|---------:|------:|------:|
| DCQ (4096), DCQ.2         | 1.651    | 12.12 | 34.4  |
| DCQ (8192), DCQ.2         | 2.238    | 8.94  | 25.4  |
| **DCQ2 (4096)**           | 2.272    | 8.80  | 25.0  |

- Surprise: DCQ2 is 0.73x DCQ at the same leaf_size (4096), not faster.
  It lands near DCQ's leaf_size=8192/16384 rate (25-26%) and OPQ's
  large-size rate (~26.5%). Not explained; not yet profiled.
- The copy of b (100001 floats, ~400 KB, once per call) is inside the
  timed region; its cost is not measured separately.

#### Conclusion

(To be stated by the student.)

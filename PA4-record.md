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

Re-check (after DCQ2.1 showed that load from another process can slow a
run by 1.5x with tight reps): DCQ.1's baseline and this sweep were re-run
with identical commands on a quiet machine (load average 0.8-1.8, no other
user's jobs), as `2026.11.01.003_seq_100000x100000.csv` and
`2026.11.01.004_leaf_sweep_100000x100000.csv`. Every point agrees with the
original within 0.1% (baseline 2.7381 vs 2.7405 s), so the original
numbers above stand and the original T(seq) entry was kept.

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

Run 1 (`2026.11.01.001_seq_100000x100000.csv`, superseded): median of 7
2.2716 s, 8.80 GFLOPs/s (25.0% TPP), reps within 0.2%. The user's own
rerun indicated additional usage from another process during it, so it
was repeated.

Run 2 (`2026.11.01.002_seq_100000x100000.csv`), same command with
`--name 2026.11.01.002_seq_100000x100000`, load average 1.5 before and
after, other user's Python jobs no longer present: median of 7 1.5107 s,
**13.24 GFLOPs/s (37.6% TPP)**, reps 1.5106-1.5114 s (within 0.05%).
`--record-seq` replaced run 1's entry in `04-DCQ2/results/seq_time.json`
with run 2's value.

| variant (leaf_size)       | time (s) | GF/s  | % TPP |
|---------------------------|---------:|------:|------:|
| DCQ (4096), DCQ.2         | 1.651    | 12.12 | 34.4  |
| DCQ2 (4096), run 1        | 2.272    | 8.80  | 25.0  |
| **DCQ2 (4096), run 2**    | 1.511    | 13.24 | 37.6  |
| BKQ (3072), PA3 BKQ7.2    | -        | 13.22 | 37.6  |

- Run 2: DCQ2 is 1.09x DCQ at the same leaf_size, and equal to BKQ's best
  single-core rate.
- Run 1 was 1.50x slower than run 2 yet had reps just as tight (0.2%):
  tight rep spread did not reveal the interference. DCQ.1 and DCQ.2 ran
  under similar load but were unaffected: quiet-machine re-runs agreed
  within 0.1% (see DCQ.2).
- The copy of b (100001 floats, ~400 KB, once per call) is inside the
  timed region; its cost is not measured separately.

#### Conclusion

(To be stated by the student.)

## 04-DCP1: DCQ2 + tasks, task reduction into c (parallel)

### DCP1.1: tasks for all 4 sub-multiplies down to a depth cutoff, taskgroup task_reduction

#### Introduction

PA4 goal 1: near-perfect speedup with the usual reduction strategy (tasks,
taskgroups). DCQ2 is the best sequential DC kernel so far (13.24 GF/s,
37.6% TPP, leaf_size=4096). The four quadrant sub-multiplies of a node
write overlapping ranges of c (the two "cross" quadrants write the same
range, and every quadrant overlaps its neighbours), so concurrent
sub-multiplies race on c unless each accumulates into a private copy.

#### Hypothesis

(To be stated by the student.)

#### Design

Decisions (user): directory `04-DCP1` (T(seq) ancestor lookup -> `04-DCQ`,
the original DCQ, by directory name; DCQ2 is not looked up
automatically); each of the 4 recursive calls is a task, down to a depth
cutoff; reduction via `taskgroup task_reduction`.

Note (user): compare reduction implementations going forward, e.g. this
`taskgroup task_reduction` against `reduction` on the parallel region with
`single` and `in_reduction` tasks.

- Sequential recursion and leaf exactly as DCQ2 (OPQ leaf, always
  quadrants, b split rounded to 16 floats, aligned copy of b, leaf_size
  fallback 4096).
- New knob `--tune depth=N`, the task-spawn cutoff, fallback 5 (the shared
  gate tune's value; default chosen by Claude, not discussed).
- Top level: `parallel` -> `single` -> `taskgroup task_reduction(+:
  c[:n])` (also `comp[:n]` in the checking build), then dcp on the whole
  problem.
- dcp at depth d < depth spawns each non-empty quadrant as a task:
  - a child that does arithmetic (a leaf, or at depth = cutoff) gets
    `in_reduction(+: c[:n])` and runs the sequential DCQ2 recursion on
    its thread's private copy of c, at its offset;
  - any other child only spawns tasks, never writes c, and is a plain
    task (so in_reduction never sees an already-privatized pointer).
- No taskwait: the taskgroup's end waits for all descendant tasks, then
  combines the private copies into c.
- With depth=5 there are up to 4^5 = 1024 working tasks; at 100K and
  leaf_size=4096 each does a ~3125 x ~3125 sub-multiply (5 levels down)
  sequentially.
- Without -fopenmp the pragmas are ignored: `PolyMult.time` is DCQ2.

#### Implementation

`04-DCP1/` (Makefile and run.sh copied from `04-DCQ2`, variant name
`DCP1`; kernel in `src/PolyMult.c`). Built with no warnings (GCC accepts
`in_reduction` on a function-parameter pointer matching the taskgroup's
`task_reduction` item by address). Gate PASSED: oracle 42/42 and gold
14/14, on both `PolyMult.check` and `PolyMult.check-par`. The gate runs
leaf_size=64, depth=5; the parallel check sets no thread count, so
OpenMP's default applies (16 threads, the `taskset -c 16-31` mask).

#### Experiment

Settings follow the PA3 BKP convention (user gave the go-ahead without
specifying them): DCP1's own sequential baseline, then a 1-16 thread sweep
at the defaults (leaf_size=4096, depth=5).

```
./sweep.sh --variant-dir 04-DCP1 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 04-DCP1 --dA 100000 --dB 100000 --threads 1:16:1 --reps 5 \
    --name 2026.11.01.002_threads_100000x100000
.venv/bin/python plot.py --csv 04-DCP1/results/2026.11.01.002_threads_100000x100000.csv \
    --tpp-per-core 35.2 --topic ThreadSweep100000x100000 \
    --title "DCP1 (tasks + taskgroup task_reduction, leaf 4096, depth 5), 100000x100000"
```

Gate passed in both sweeps. Load average 1.1 before, 3.1 after the thread
sweep (the sweep itself uses 16 cores); no other user's jobs seen.

Recorded T(seq): 1.5109 s (13.24 GF/s), matching DCQ2's 1.5107 s (the
sequential binary is DCQ2). The thread sweep's T(seq) is this own entry
(`seq_time_source: min of 3: own`).

#### Results

Median of 5. Speedup vs T(seq) = 1.5109 s; %TPP = GF/s / (35.2 x t):

| t  | time (s) | GF/s  | speedup | % TPP | rep spread |
|---:|---------:|------:|--------:|------:|-----------:|
| 1  | 1.5129   | 13.2  | 1.00    | 37.6  | 0.1%       |
| 2  | 0.7581   | 26.4  | 1.99    | 37.5  | 0.2%       |
| 4  | 0.3813   | 52.4  | 3.96    | 37.3  | 0.5%       |
| 6  | 0.2551   | 78.4  | 5.92    | 37.1  | 0.9%       |
| 8  | 0.1924   | 104.0 | 7.85    | 36.9  | 0.7%       |
| 10 | 0.1559   | 128.3 | 9.69    | 36.5  | 1.5%       |
| 12 | 0.1310   | 152.6 | 11.53   | 36.1  | 1.5%       |
| 13 | 0.1215   | 164.7 | 12.44   | 36.0  | 8.1%       |
| 14 | 0.1128   | 177.4 | 13.39   | 36.0  | 1.9%       |
| 15 | 0.1066   | 187.6 | 14.17   | 35.5  | 7.9%       |
| 16 | 0.1004   | 199.2 | **15.05** | 35.4 | 0.4%      |

(All 16 thread counts in the csv and plot.)

- Speedup 15.05x at 16 threads (94% efficiency); 1 thread of the OpenMP
  build matches the sequential binary (1.5129 vs 1.5109 s).
- The per-core rate falls slowly and steadily, 37.6% -> 35.4% of TPP from
  1 to 16 threads; no steps or drops at particular thread counts.
- Rep spread <= 1.9% except t=13 and t=15 (one slow rep each, ~8%; the
  medians are unaffected).
- 199.2 GF/s at 16 threads is below BKP5's 397 GF/s (PA3); the per-core
  rate is DCQ2's ~37% vs BKP5's ~71%.

Plot: `04-DCP1/plots/2026.11.01.001.ThreadSweep100000x100000.xlsx`.

#### Conclusion

(To be stated by the student.)

## 04-DCP2: DCQ2 + tasks, no reduction, taskwait ordering (parallel)

### DCP2.1: LL || HH, taskwait, then LH and HL sequentially

#### Introduction

DCP1.1 scaled nearly linearly with a task reduction (15.05x at 16
threads). PA4 goal 2: the best speedup without reductions, using
correctly placed syncs (taskwaits). PA4.md requires analyzing the work
and span of the program and using it to predict parallel performance
before running the experiment.

Within one node, the four quadrants write: LL = a_lo x b_lo ->
c[0 .. ha+hb-2]; HH = a_hi x b_hi -> c[ha+hb .. na+nb-2]; LH = a_lo x b_hi
-> c[hb .. ha+nb-2] and HL = a_hi x b_lo -> c[ha .. na+hb-2], which
overlap LL, HH and each other. LL and HH write disjoint ranges.

#### Hypothesis

Work/span analysis (student), done before any timed run as PA4.md
requires. Approximation: $N_A = N_B = N$. Unit of time: one multiply-add,
so a sequential $N \times N$ sub-multiply costs $N^2$.

##### Work and span: sequential (DCQ2)

$$
\begin{aligned}
W_s(N) &= 4\,W_s(N/2) + O(1) = \Theta(N^2) \\
S_s(N) &= 4\,S_s(N/2) + O(1) = \Theta(N^2)
\end{aligned}
$$

##### Work and span: parallel (DCP2), no cutoff

LL and HH recurse in parallel; LH and HL are sequential DCQ2 calls.

$$
\begin{aligned}
W_p(N) &= 2\,W_p(N/2) + 2\,W_s(N/2) + O(1) \\
       &= 2\,W_p(N/2) + 2\,\Theta(N^2/4) + O(1) = \Theta(N^2) \\
S_p(N) &= S_p(N/2) + 2\,S_s(N/2) + O(1) \\
       &= S_p(N/2) + 2\,\Theta(N^2/4) + O(1) = \Theta(N^2)
\end{aligned}
$$

- The work is unchanged from the sequential version (discounting
  parallelization overhead).
- The span has the same order as the work, $\Theta(N^2)$, so the
  parallelism is $\Theta(1)$: despite the parallelization, the span has
  the same asymptotic complexity as the serial implementation.

##### Span with a depth cutoff K

At depth $K$ the algorithm stops spawning tasks and runs the remaining
sub-problem sequentially:

$$
S_K(N) =
\begin{cases}
N^2, & K = 0 \\
S_{K-1}(N/2) + N^2/2, & K > 0
\end{cases}
$$

$$
\begin{aligned}
S_K(N) &= \frac{N^2}{2} \sum_{i=0}^{K-1} 4^{-i} + \frac{N^2}{4^K}
        = N^2 \left( \frac{2}{3} + \frac{1}{3 \cdot 4^K} \right) \\
\lim_{K \to \infty} S_K(N) &= \frac{2N^2}{3}
\qquad\Rightarrow\qquad
\lim_{K \to \infty} \frac{W_p}{S_K} = \frac{3}{2} = 1.5
\end{aligned}
$$

The speedup is capped at 1.5, no matter how many threads are used.

For our test cases where $N = 100000$ and the leaf size cuts subtasking at 4096, the tree has a depth $K = 5$. $\frac{S_4(N)}{N^2} = 0.6680$, so $\frac{W_p}{S_4} = 1.497$.

##### Prediction

The speedup curve will approach 1.5 asymptotically as the thread count
increases.

Model: LL and HH each get half of the $p$ threads, so each subtree runs
on its own thread group. $T_p$ then follows the same recurrence as
$S_K$, with $K = \log_2 p$, since each split halves the thread count:

$$
\begin{aligned}
T_1(N) &= N^2 \\
T_p(N) &= T_{p/2}(N/2) + N^2/2 \\
\Rightarrow\quad \frac{T_p}{T_1} &= \frac{2}{3} + \frac{1}{3p^2} \\
\Rightarrow\quad \text{speedup}(p) &= \frac{3p^2}{2p^2 + 1}
\qquad (p \text{ a power of 2},\ p \le 2^K)
\end{aligned}
$$

| p       | 1    | 2    | 4    | 8    | 16   |
|:-------:|:----:|:----:|:----:|:----:|:----:|
| speedup | 1.00 | 1.33 | 1.45 | 1.49 | 1.50 |

#### Design

Decisions (user): no reduction, sync with taskwait; first approach: LL
and HH in parallel, then LH and HL sequentially, each as plain sequential
DCQ2 on the calling thread; directory `04-DCP2`; depth knob kept
(fallback 5), leaf_size fallback 4096.

```
dcp(node, d):
    if d >= depth or node is a leaf: dcq(node)            # sequential DCQ2
    else:
        task dcp(LL, d+1)
        task dcp(HH, d+1)
        taskwait
        dcq(LH)                                           # sequential
        dcq(HL)                                           # sequential
top: parallel -> single -> dcp(whole, 0)
```

- All writes go straight into the shared c (and comp in the checking
  build, at the same offsets).
- The taskwait waits only for the direct children LL and HH; each child
  returns only after its own taskwait and its own LH/HL, so all
  descendants are done when it returns.
- Only LL and HH recurse in parallel; LH and HL (half of each node's
  work) run sequentially at every level above the cutoff.
- Without -fopenmp: quadrant order LL, HH, LH, HL above the cutoff
  (DCQ2: LL, LH, HL, HH); same arithmetic per element, different
  summation order.
- Copied from DCP1 with the reduction removed; sequential dcq, b copy
  and split rule unchanged.

#### Implementation

`04-DCP2/` (Makefile and run.sh copied from `04-DCP1`, variant name
`DCP2`; kernel in `src/PolyMult.c`). Built with no warnings. Gate PASSED:
oracle 42/42 and gold 14/14, on both `PolyMult.check` and
`PolyMult.check-par` (leaf_size=64, depth=5; parallel check at OpenMP's
default 16 threads). One gate run; a race that the gate happens not to
expose in one run cannot be ruled out by a single pass.

#### Experiment

Settings as DCP1.1 (user gave the go-ahead without specifying them):
DCP2's own sequential baseline, then a 1-16 thread sweep at the defaults
(leaf_size=4096, depth=5).

```
./sweep.sh --variant-dir 04-DCP2 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 04-DCP2 --dA 100000 --dB 100000 --threads 1:16:1 --reps 5 \
    --name 2026.11.01.002_threads_100000x100000
.venv/bin/python plot.py --csv 04-DCP2/results/2026.11.01.002_threads_100000x100000.csv \
    --tpp-per-core 35.2 --topic ThreadSweep100000x100000 \
    --title "DCP2 (tasks, LL || HH, taskwait, LH/HL sequential, leaf 4096, depth 5), 100000x100000"
```

Gate passed in both sweeps (a second and third passing run of
`PolyMult.check-par`, after the one in Implementation). Load average 1.1
before (15-minute average 24.4, from earlier load), 1.9 after the thread
sweep; no other user's jobs seen.

Recorded T(seq): 1.5107 s (13.24 GF/s), the same as DCQ2's 1.5107 s,
although DCP2's sequential binary runs the quadrants in a different order
(LL, HH, LH, HL) above the cutoff. The thread sweep's T(seq) is this own
entry (`seq_time_source: min of 3: own`).

#### Results

Median of 5. Speedup vs T(seq) = 1.5107 s; %TPP = GF/s / (35.2 x t);
"predicted" is the Hypothesis's 3p^2/(2p^2+1), given for powers of 2
only:

| t  | time (s) | GF/s | speedup | predicted | % TPP | rep spread |
|---:|---------:|-----:|--------:|----------:|------:|-----------:|
| 1  | 1.5112   | 13.2 | 1.00    | 1.00      | 37.6  | 0.0%       |
| 2  | 1.1347   | 17.6 | 1.33    | 1.33      | 25.0  | 0.2%       |
| 3  | 1.1357   | 17.6 | 1.33    |           | 16.7  | 0.5%       |
| 4  | 1.1344   | 17.6 | 1.33    | 1.45      | 12.5  | 1.9%       |
| 5  | 1.0396   | 19.2 | 1.45    |           | 10.9  | 7.1%       |
| 6  | 1.0406   | 19.2 | 1.45    |           | 9.1   | 4.5%       |
| 7  | 1.0391   | 19.2 | 1.45    |           | 7.8   | 0.3%       |
| 8  | 1.0390   | 19.2 | 1.45    | 1.49      | 6.8   | 0.8%       |
| 9  | 1.0333   | 19.4 | 1.46    |           | 6.1   | 1.2%       |
| 10 | 1.0332   | 19.4 | 1.46    |           | 5.5   | 0.2%       |
| 11 | 1.0258   | 19.5 | 1.47    |           | 5.0   | 1.3%       |
| 12 | 1.0211   | 19.6 | 1.48    |           | 4.6   | 0.9%       |
| 13 | 1.0213   | 19.6 | 1.48    |           | 4.3   | 0.6%       |
| 14 | 1.0184   | 19.6 | 1.48    |           | 4.0   | 0.8%       |
| 15 | 1.0172   | 19.7 | 1.49    |           | 3.7   | 0.3%       |
| 16 | 1.0170   | 19.7 | **1.49** | 1.50     | 3.5   | 0.3%       |

- Speedup 1.49x at 16 threads (19.7 GF/s), against the predicted 1.50
  (the Hypothesis's cap).
- The curve is a staircase, not a smooth approach: flat at 1.33 for 2-4
  threads, a step to 1.45 at 5, flat at 1.45 for 5-8, then a slow rise
  from 1.46 to 1.49 over 9-16.
- Surprise: at 4 threads the measured speedup is 1.33 (same as 2 and 3
  threads), against the predicted 1.45; the 1.45 appears only at 5
  threads. At 2 and 16 threads the measurement matches the prediction.
- Rep spread <= 1.9% except t=5 (7.1%) and t=6 (4.5%), each from one
  slow first rep (1.113 s and 1.086 s, near the 4-thread level); the
  medians are unaffected. At t=4 the first rep was the fast one (1.114 s
  vs ~1.134 s for the others).
- 1 thread of the OpenMP build matches the sequential binary (1.5112 vs
  1.5107 s).
- Against DCP1.1 at 16 threads: 1.017 s vs 0.100 s (19.7 vs 199.2
  GF/s).

Plot: `04-DCP2/plots/2026.11.01.001.ThreadSweep100000x100000.xlsx`.

#### Conclusion

The 1.5 bound holds at large p, but the curve is under expectation at lower p.

## 04-DCP3: DCP2 + tasks for LH and HL, taskwait-separated (parallel)

### DCP3.1: LL || HH, taskwait, task LH, taskwait, task HL, taskwait

#### Introduction

DCP2.1 ran LH and HL as sequential DCQ2 on the calling thread and reached
1.49x at 16 threads, with a staircase curve (1.33 for 2-4 threads, 1.45
for 5-8). DCP3 runs LH and HL as tasks that recurse with the same scheme,
still without a reduction, with a taskwait after each so that no two
overlapping quadrants run at once.

#### Hypothesis

Work/span analysis (student), done before any timed run as PA4.md
requires. Same approximation and unit as DCP2.1: $N_A = N_B = N$, one
multiply-add per unit of time.

##### Work and span: parallel (DCP3), no cutoff

LL and HH recurse in parallel; LH and HL are recursive dcp tasks, each
running alone between taskwaits.

$$
\begin{aligned}
W_p(N) &= 4\,W_p(N/2) + O(1) = \Theta(N^2) \\
S_p(N) &= S_p(N/2) + 2\,S_p(N/2) + O(1) \\
       &= 3\,S_p(N/2) + O(1) = \Theta(N^{\log_2 3})
\end{aligned}
$$

- The work is unchanged from the sequential version (discounting
  parallelization overhead).
- The span has a lower order than the work:
  $W_p/S_p = \Theta(N^2)/\Theta(N^{\log_2 3}) = \Theta(N^{2-\log_2 3})$.

##### Span with a depth cutoff K

At depth $K$ the algorithm stops spawning tasks and runs the remaining
sub-problem, of length $L = N/2^K$, sequentially:

$$
\begin{aligned}
S_K(N) &= 3^K \left( \frac{N}{2^K} \right)^2 = N^2 \left( \frac{3}{4} \right)^K \\
\frac{W}{S_K} &= \left( \frac{4}{3} \right)^K
               = \left( \frac{N}{L} \right)^{2-\log_2 3}
               \approx \left( \frac{N}{L} \right)^{0.415}
\end{aligned}
$$

This speedup grows with depth.

At 100000 with leaf_size=4096, the recursion stops at $K = 5$ (leaves
about 3125 long), which gives $W/S = 4.2$. Going deeper needs both a
smaller leaf_size and depth $\ge K$.

##### Prediction

Speedup will grow sublinearly with thread count, approaching 4.2x at 16
threads. Observed speedup will be less than the ideal speedup listed
below, due to overhead.

Model: in phase A, LL and HH get $p/2$ threads each; in phases B (LH)
and C (HL), the single child gets all $p$ threads. No overhead and a
constant leaf rate are assumed.

| K (leaf_size) | W/S  | p=2  | p=4  | p=8  | p=16  |
|:-------------:|-----:|-----:|-----:|-----:|------:|
| 5 (4096)      | 4.2  | 1.94 | 3.20 | 4.00 | 4.20  |
| 6 (2048)      | 5.6  | 1.97 | 3.51 | 4.92 | 5.51  |
| 7 (1024)      | 7.5  | 1.98 | 3.71 | 5.79 | 7.06  |
| 8 (512)       | 10.0 | 1.99 | 3.84 | 6.50 | 8.77  |
| 9 (256)       | 13.3 | 2.00 | 3.91 | 7.04 | 10.48 |
| 10 (128)      | 17.8 | 2.00 | 3.95 | 7.41 | 12.01 |

#### Design

Decisions (user): LH and HL as tasks, separated by another taskwait; each
runs the recursive dcp (not sequential dcq); new directory `04-DCP3`.

```
dcp(node, d):
    if d >= depth or node is a leaf: dcq(node)            # sequential DCQ2
    else:
        task dcp(LL, d+1)
        task dcp(HH, d+1)
        taskwait
        task dcp(LH, d+1)
        taskwait
        task dcp(HL, d+1)
        taskwait
top: parallel -> single -> dcp(whole, 0)
```

- All writes go straight into the shared c (and comp in the checking
  build, at the same offsets).
- LH and HL overlap LL, HH and each other, so each runs alone, after the
  previous taskwait; within each, the same LL || HH, LH, HL ordering
  applies recursively down to the cutoff.
- Each taskwait waits only for the direct children; each child returns
  only after its own last taskwait.
- Without -fopenmp: quadrant order LL, HH, LH, HL above the cutoff, as in
  DCP2.
- Copied from DCP2 (Makefile, run.sh, kernel); only the LH/HL calls
  changed. Defaults unchanged: leaf_size 4096, depth 5.

#### Implementation

`04-DCP3/` (Makefile and run.sh copied from `04-DCP2`, variant name
`DCP3`; kernel in `src/PolyMult.c`). Built with no warnings. Gate PASSED:
oracle 42/42 and gold 14/14, on both `PolyMult.check` and
`PolyMult.check-par` (leaf_size=64, depth=5; parallel check at OpenMP's
default 16 threads). One gate run; a race that the gate happens not to
expose in one run cannot be ruled out by a single pass.

#### Experiment

Settings as DCP2.1: DCP3's own sequential baseline, then a 1-16 thread
sweep at the defaults (leaf_size=4096, depth=5, so K = 5).

```
./sweep.sh --variant-dir 04-DCP3 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 04-DCP3 --dA 100000 --dB 100000 --threads 1:16:1 --reps 5 \
    --name 2026.11.01.002_threads_100000x100000
.venv/bin/python plot.py --csv 04-DCP3/results/2026.11.01.002_threads_100000x100000.csv \
    --tpp-per-core 35.2 --topic ThreadSweep100000x100000 \
    --title "DCP3 (tasks, LL || HH, then task LH, then task HL, taskwaits, leaf 4096, depth 5), 100000x100000"
```

Gate passed in both sweeps. Machine not quiet: another user's python job
(one thread at ~85-95% CPU, plus data-worker processes) ran throughout;
its busy thread was seen on cores 5 and 6, outside the 16-31 timing mask,
but it was not pinned (affinity 0-31). The user chose to run anyway and
note it. Load average 2.1 before, 6.3 after the thread sweep.

Recorded T(seq): 1.5106 s (13.24 GF/s), matching DCP2's 1.5107 s and
DCQ2's 1.5107 s (the same sequential code), so the baseline shows no
sign of the other job. The thread sweep's T(seq) is this own entry
(`seq_time_source: min of 3: own`).

#### Results

Median of 5. Speedup vs T(seq) = 1.5106 s; %TPP = GF/s / (35.2 x t);
"model" is the Hypothesis's K = 5 row (powers of 2 only):

| t  | time (s) | GF/s | speedup | model | % TPP | rep spread |
|---:|---------:|-----:|--------:|------:|------:|-----------:|
| 1  | 1.5107   | 13.2 | 1.00    | 1.00  | 37.6  | 0.1%       |
| 2  | 1.1340   | 17.6 | 1.33    | 1.94  | 25.1  | 0.1%       |
| 3  | 0.9461   | 21.1 | 1.60    |       | 20.0  | 2.5%       |
| 4  | 0.8284   | 24.1 | 1.82    | 3.20  | 17.1  | 1.4%       |
| 5  | 0.6684   | 29.9 | 2.26    |       | 17.0  | 8.3%       |
| 6  | 0.5748   | 34.8 | 2.63    |       | 16.5  | 7.2%       |
| 7  | 0.5304   | 37.7 | 2.85    |       | 15.3  | 6.1%       |
| 8  | 0.4991   | 40.1 | 3.03    | 4.00  | 14.2  | 4.6%       |
| 9  | 0.4642   | 43.1 | 3.25    |       | 13.6  | 2.9%       |
| 10 | 0.4423   | 45.2 | 3.42    |       | 12.8  | 5.4%       |
| 11 | 0.4245   | 47.1 | 3.56    |       | 12.2  | 2.8%       |
| 12 | 0.4103   | 48.7 | 3.68    |       | 11.5  | 1.6%       |
| 13 | 0.4058   | 49.3 | 3.72    |       | 10.8  | 1.9%       |
| 14 | 0.3993   | 50.1 | 3.78    |       | 10.2  | 0.8%       |
| 15 | 0.3902   | 51.3 | 3.87    |       | 9.7   | 1.2%       |
| 16 | 0.3846   | 52.0 | **3.93** | 4.20 | 9.2   | 1.2%       |

Measured / model: 0.69 (t=2), 0.57 (t=4), 0.76 (t=8), 0.94 (t=16).

- Speedup 3.93x at 16 threads (52.0 GF/s), against the model's 4.20
  (= W/S at K = 5); 2.6x DCP2.1's 1.49x.
- Unlike DCP2.1 (flat steps), the curve rises at every thread count and
  flattens toward 16.
- Surprise: at 2 threads the speedup is 1.33, against the model's 1.94,
  and identical to DCP2.1's 2-thread value (1.1340 vs 1.1347 s), with
  0.1% spread.
- The model is furthest off at 4 threads (1.82 vs 3.20) and closest at
  16 (3.93 vs 4.20).
- Rep spread 4.6-8.3% for t=5-8 and 5.4% at t=10 (others <= 2.9%);
  spread is in both directions, not one slow rep. The other user's job
  was running; whether it contributed cannot be told from this data.
- 1 thread of the OpenMP build matches the sequential binary (1.5107 vs
  1.5106 s).

Plot: `04-DCP3/plots/2026.11.01.001.ThreadSweep100000x100000.xlsx`.

#### Conclusion

(To be stated by the student.)

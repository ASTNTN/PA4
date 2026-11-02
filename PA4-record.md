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

The baseline task-based approach will be slower than the OPQ implementation it is based on.

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


### DCQ.2: leaf size sweep

#### Introduction

DCQ.1 ran at 20.7% TPP with leaf_size=64, slower than OPQ and than BKQ
with 64x64 blocks. Halving until a range is at most leaf_size leaves
leaves somewhere between leaf_size/2 and leaf_size long, so leaf_size=64
gives leaves of only 33-64 coefficients per side.

#### Hypothesis

The leaves are too small; larger leaf sizes should
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

## 04-DCQ2: DCQ + 64-byte-aligned b sub-ranges (sequential)

### DCQ2.1: aligned copy of b, splits of b rounded to 16 floats

#### Introduction

DCQ.2 put DCQ's best rate at 34.4% TPP (leaf_size=4096), below BKQ's ~37%.
In DCQ the b sub-range of each leaf starts at an arbitrary float offset:
b comes from the harness's plain `malloc` (16-byte aligned by default,
`BPM_ALIGN=0`), and the split points nb/2 land anywhere. In PA3, aligning
the b windows (BKQ4) removed most split loads.

#### Hypothesis

We should see the same ~37% of TPP by using aligned splits of b.

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

We will achieve perfect speedup by using task-based parallelization.

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

Student's conclusion: the 1.5 bound holds at large p, but the curve is
below expectation at lower p.

**The idle-spawner hypothesis (from DCP3.1) applied to DCP2.** The
hypothesis is that a thread at taskwait runs only its own child tasks,
and idle threads take newly queued tasks first (not verified in
libgomp's source). In DCP2 only phase A spawns tasks; LH and HL run as
plain calls on the spawning thread after the taskwait, so the spawner is
lost only in phase A:

- Phase A: at 2 threads, LL and HH get 1 thread each. With 3 or more,
  they share the other $p-1$ threads, split
  $\lfloor (p-1)/2 \rfloor$ / $\lceil (p-1)/2 \rceil$.
- Phases B and C: 0.25 of the node's $T_1$ each, sequential on the
  spawner.

| t     | measured  | ideal model (Hypothesis) | idle-spawner model |
|------:|----------:|-------------------------:|-------------------:|
| 2     | 1.33      | 1.33                     | 1.33               |
| 3     | 1.33      | --                       | 1.33               |
| 4     | 1.33      | 1.45                     | 1.33               |
| 5-8   | 1.45      | 1.49 (t=8)               | 1.45               |
| 9-10  | 1.46      | --                       | 1.45               |
| 11-14 | 1.47-1.48 | --                       | 1.49               |
| 15-16 | 1.49      | 1.50 (t=16)              | 1.49               |

(Idle-spawner column computed by Claude from the student's DCP3.1 model,
K = 5.)

- The model gives the staircase: 1.33 for t = 2-4 because, with 3
  threads in phase A, LL and HH each get one thread, and with 4 threads,
  3 workers split 1/2, so the 1-thread subtree sets the time. The step to
  1.45 at t = 5 comes when both subtrees first get 2 threads.
- This accounts for the Results' surprise at 4 threads (1.33 measured vs
  the ideal model's 1.45).
- Above 8 threads the model has one more step, at t = 11 (1.45 -> 1.49),
  while the measurement rises gradually from 1.46 at t = 9 to 1.49 at
  t = 15-16.
- At 2 threads DCP2 and DCP3 both take 0.75 of $T_1$ under this model,
  matching their measured 1.1347 s and 1.1340 s.

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

Student's conclusion.

**The surprise.** At 2 threads DCP3 took 1.1340 s (1.33x), practically
the same as DCP2's 1.1347 s, against a predicted 1.94x. The rep spread
was 0.1%, so this happens every time, not by chance.

**Hypothesis (the same one as for DCP2's later steps): the spawning
thread idles at taskwait.** A thread that spawns tasks and then reaches
taskwait appears to run only its own child tasks (not verified in
libgomp's source). Idle threads waiting at the end of `single` grab any
newly queued task immediately, so:

- LH and HL are each a single task followed by a taskwait. An idle thread
  almost always takes it first, and the thread that spawned it has
  nothing to do for the whole phase.
- LL and HH: with 3 or more threads, both get taken by other threads and
  the spawner idles again.

**Idle-spawner model:** "lose the spawner at each level".
- Phase A: at 2 threads, LL and HH get 1 thread each. With 3 or more,
  they share the other $p-1$ threads, split
  $\lfloor (p-1)/2 \rfloor$ / $\lceil (p-1)/2 \rceil$.
- Phases B (LH) and C (HL): $p-1$ threads each.
- At 2 threads, phase A takes 0.25 of $T_1$, and LH and HL take 0.25
  each, each on one thread. That's 0.75 of $T_1$, exactly 1.33x, which
  explains why DCP2 and DCP3 match there.

| t  | measured | ideal model | idle-spawner model |
|---:|---------:|------------:|-------------------:|
| 2  | 1.33     | 1.94        | 1.33               |
| 3  | 1.60     | --          | 1.60               |
| 4  | 1.82     | 3.20        | 1.78               |
| 8  | 3.03     | 4.00        | 2.84               |
| 16 | 3.93     | 4.20        | 3.88               |

- The model matches t=2 and t=3 exactly and t=16 to within about 1%.
- In between it is slightly pessimistic, which is expected: real threads
  aren't tied to fixed groups and can help other subtrees. Over all 16
  thread counts, measured / idle-spawner model is 1.00-1.03 for t <= 4
  and t >= 13, and 1.03-1.11 for t = 5-12 (largest at t=6: 2.63 vs
  2.37).
- Another user's job was running during the sweep, which may explain
  the 5-8% rep spread at 5-8 threads. It doesn't explain the medians,
  since the model fits them without it.

## 04-DCP4: DCP3 with the spawner kept busy (parallel)

### DCP4.1: task LL, HH inline, taskwait, LH and HL inline

#### Introduction

DCP3.1 reached 3.93x at 16 threads against the ideal model's 4.20, and
below it at lower thread counts (1.33 vs 1.94 at 2 threads, 1.82 vs 3.20
at 4). The DCP3.1 Conclusion's hypothesis: a thread at taskwait runs only
its own child tasks, and idle threads take each newly queued task first,
so the spawning thread idles; the idle-spawner model fits DCP3.1 and
DCP2.1. Plan (student): keep the spawner busy.

#### Hypothesis

Predicted (student): the curve moves to the ideal model's values (about
1.9 at 2 threads, 3.2 at 4, 4.0 at 8, 4.2 at 16; DCP3.1 Hypothesis,
K = 5 row). If it does, it confirms the mechanism for DCP2 as well.

#### Design

Plan (student):
- Call LH and HL directly instead of as tasks. Nothing may run beside
  them anyway.
- In phase A, spawn only LL as a task and run HH inline before the
  taskwait.

Decision (user): new directory `04-DCP4` (the plan was first labelled
DCP3.2 in the record).

```
dcp(node, d):
    if d >= depth or node is a leaf: dcq(node)            # sequential DCQ2
    else:
        task dcp(LL, d+1)
        dcp(HH, d+1)                                      # inline
        taskwait
        dcp(LH, d+1)                                      # inline
        dcp(HL, d+1)                                      # inline
top: parallel -> single -> dcp(whole, 0)
```

- LH and HL are direct calls to the recursive dcp (as they were dcp
  tasks in DCP3), so each still parallelizes inside.
- A direct dcp call returns only after its own taskwait and its own
  LH/HL, so no taskwait follows HH, LH or HL.
- OpenMP semantics: a direct call runs inside the caller's task, so the
  tasks it spawns are children of that same task, and a taskwait waits
  for all child tasks of the current task, including any spawned earlier
  in the same task (e.g. the LL task while HH runs inline).
- Without -fopenmp: quadrant order LL, HH, LH, HL, as in DCP2 and DCP3.
- Copied from DCP3 (Makefile, run.sh, kernel); only dcp's body changed.
  Defaults unchanged: leaf_size 4096, depth 5.

#### Implementation

`04-DCP4/` (Makefile and run.sh copied from `04-DCP3`, variant name
`DCP4`; kernel in `src/PolyMult.c`). Built with no warnings. Gate PASSED:
oracle 42/42 and gold 14/14, on both `PolyMult.check` and
`PolyMult.check-par` (leaf_size=64, depth=5; parallel check at OpenMP's
default 16 threads). One gate run; a race that the gate happens not to
expose in one run cannot be ruled out by a single pass.

#### Experiment

Settings as DCP3.1: DCP4's own sequential baseline, then a 1-16 thread
sweep at the defaults (leaf_size=4096, depth=5, so K = 5).

```
./sweep.sh --variant-dir 04-DCP4 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 04-DCP4 --dA 100000 --dB 100000 --threads 1:16:1 --reps 5 \
    --name 2026.11.01.002_threads_100000x100000
.venv/bin/python plot.py --csv 04-DCP4/results/2026.11.01.002_threads_100000x100000.csv \
    --tpp-per-core 35.2 --topic ThreadSweep100000x100000 \
    --title "DCP4 (tasks, task LL + HH inline, taskwait, LH/HL inline, leaf 4096, depth 5), 100000x100000"
```

Gate passed in both sweeps. Same machine conditions as DCP3.1: the other
user's python job (one thread at ~88% CPU, seen on cores 6-7, outside the
16-31 mask, not pinned) ran throughout; run and noted as for DCP3.1.
Load average 2.2 before, 9.4 after the thread sweep.

Recorded T(seq): 1.5101 s (13.24 GF/s), matching DCP3's 1.5106 s (same
sequential code). The thread sweep's T(seq) is the min of 3, which here
is the sweep's own t=1 median, 1.5099 s
(`seq_time_source: min of 3: this sweep's own t=1 median`).

#### Results

Median of 5. Speedup vs T(seq) = 1.5099 s; %TPP = GF/s / (35.2 x t);
"ideal model" is the DCP3.1 Hypothesis K = 5 row (powers of 2 only), the
values predicted here; "DCP3.1" is DCP3's measured speedup:

| t  | time (s) | GF/s | speedup | ideal model | DCP3.1 | % TPP | rep spread |
|---:|---------:|-----:|--------:|------------:|-------:|------:|-----------:|
| 1  | 1.5099   | 13.2 | 1.00    | 1.00        | 1.00   | 37.6  | 0.1%       |
| 2  | 1.1339   | 17.6 | 1.33    | 1.94        | 1.33   | 25.1  | 1.1%       |
| 3  | 0.9365   | 21.4 | 1.61    |             | 1.60   | 20.2  | 0.1%       |
| 4  | 0.9051   | 22.1 | 1.67    | 3.20        | 1.82   | 15.7  | 0.8%       |
| 5  | 0.8851   | 22.6 | 1.71    |             | 2.26   | 12.8  | 1.4%       |
| 6  | 0.8699   | 23.0 | 1.74    |             | 2.63   | 10.9  | 1.1%       |
| 7  | 0.8681   | 23.0 | 1.74    |             | 2.85   | 9.4   | 1.3%       |
| 8  | 0.8576   | 23.3 | 1.76    | 4.00        | 3.03   | 8.3   | 1.1%       |
| 9  | 0.8592   | 23.3 | 1.76    |             | 3.25   | 7.3   | 0.9%       |
| 10 | 0.8511   | 23.5 | 1.77    |             | 3.42   | 6.7   | 1.3%       |
| 11 | 0.8530   | 23.4 | 1.77    |             | 3.56   | 6.1   | 0.4%       |
| 12 | 0.8504   | 23.5 | 1.78    |             | 3.68   | 5.6   | 0.8%       |
| 13 | 0.8518   | 23.5 | 1.77    |             | 3.72   | 5.1   | 0.2%       |
| 14 | 0.8503   | 23.5 | 1.78    |             | 3.78   | 4.8   | 0.5%       |
| 15 | 0.8488   | 23.6 | 1.78    |             | 3.87   | 4.5   | 0.5%       |
| 16 | 0.8489   | 23.6 | **1.78** | 4.20       | 3.93   | 4.2   | 0.7%       |

- Surprise: the prediction failed. Speedup 1.78x at 16 threads (23.6
  GF/s), against the predicted 4.20 and below DCP3.1's 3.93.
- At 2 threads, 1.33x again (1.1339 s), the same as DCP2.1 and DCP3.1,
  against the predicted 1.94.
- At 3 threads DCP4 matches DCP3.1 (1.61 vs 1.60); from 4 threads on it
  falls behind, and the curve is nearly flat from about 6 threads
  (1.74 -> 1.78 over t = 6-16).
- Rep spread <= 1.4% at every thread count (DCP3.1 had 4.6-8.3% at
  t = 5-8 under the same machine conditions).
- 1 thread of the OpenMP build matches the sequential binary (1.5099 vs
  1.5101 s).

Plot: `04-DCP4/plots/2026.11.01.001.ThreadSweep100000x100000.xlsx`.

#### Conclusion

(To be stated by the student.)

## 04-DCP5: DCP4 with the taskwait replaced by a taskgroup (parallel)

### DCP5.1: taskgroup { task LL, HH inline }, LH and HL inline

#### Introduction

DCP4.1 kept the spawner busy (task LL, HH inline, taskwait, LH and HL
inline) and reached only 1.78x at 16 threads, against the predicted 4.20
and DCP3.1's 3.93. DCP5 replaces DCP4's taskwait with a taskgroup.

#### Hypothesis

Hypothesis

H1, the critical path is fixed. The end of a taskgroup waits only for tasks created inside it and their descendants. So the taskgroups nested in the inline HH chain don't wait for the outer LL. That removes DCP4's false dependency, and the span returns to S = W·(3/4)^K. At depth 5 the cap is W/S = 4.21, against 1.79 for DCP4.

H2, the spawning thread never sits idle. In every LL ∥ HH phase, the spawning thread runs HH itself. LH and HL are no longer lone tasks that another thread could take. If the 1.33x at 2 threads in DCP2 and DCP3 was the idle spawner, it should disappear.

Prediction (the ideal model, depth 5):

┌───────────────────────────────────────────────┬──────┬──────┬──────┬──────────┐
│                    threads                    │  2   │  4   │  8   │    16    │
├───────────────────────────────────────────────┼──────┼──────┼──────┼──────────┤
│ ideal                                         │ 1.94 │ 3.20 │ 4.00 │ 4.20     │
├───────────────────────────────────────────────┼──────┼──────┼──────┼──────────┤
│ with per-core rate loss (DCP1 lost ~6% at 16) │ ~1.9 │ ~3.1 │ ~3.8 │ ~3.9–4.2 │
└───────────────────────────────────────────────┴──────┴──────┴──────┴──────────┘

Thread counts that aren't powers of 2 should land between t end of a taskgroup should be short, because LL and HH arealmost equal in size.

The taskgroup will allow us to realize the gains expected in DCP4.

#### Design

Decision (user): replace the taskwait with a taskgroup. New directory
`04-DCP5` (Claude's choice, following the convention of one directory
per code change; not discussed).

```
dcp(node, d):
    if d >= depth or node is a leaf: dcq(node)            # sequential DCQ2
    else:
        taskgroup {
            task dcp(LL, d+1)
            dcp(HH, d+1)                                  # inline
        }                                                 # end: wait
        dcp(LH, d+1)                                      # inline
        dcp(HL, d+1)                                      # inline
top: parallel -> single -> dcp(whole, 0)
```

- The taskgroup spans the LL task and the inline HH call, i.e. exactly
  where DCP4's taskwait closed phase A.
- OpenMP semantics: the end of a taskgroup waits for the tasks generated
  inside that taskgroup region and all their descendants. A direct
  call's own taskgroup is nested inside its caller's region; its end
  waits only for the tasks generated inside the nested region, not for
  tasks the caller generated earlier (e.g. not for the LL task while HH
  runs inline). (DCP4's taskwait waited for all child tasks of the
  current task.)
- Without -fopenmp: quadrant order LL, HH, LH, HL, as in DCP2-DCP4.
- Copied from DCP4 (Makefile, run.sh, kernel); only the taskwait changed.
  Defaults unchanged: leaf_size 4096, depth 5.

#### Implementation

`04-DCP5/` (Makefile and run.sh copied from `04-DCP4`, variant name
`DCP5`; kernel in `src/PolyMult.c`). Built with no warnings. Gate PASSED:
oracle 42/42 and gold 14/14, on both `PolyMult.check` and
`PolyMult.check-par` (leaf_size=64, depth=5; parallel check at OpenMP's
default 16 threads). One gate run; a race that the gate happens not to
expose in one run cannot be ruled out by a single pass.

#### Experiment

Settings as DCP4.1: DCP5's own sequential baseline, then a 1-16 thread
sweep at the defaults (leaf_size=4096, depth=5, so K = 5).

```
./sweep.sh --variant-dir 04-DCP5 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 04-DCP5 --dA 100000 --dB 100000 --threads 1:16:1 --reps 5 \
    --name 2026.11.01.002_threads_100000x100000
.venv/bin/python plot.py --csv 04-DCP5/results/2026.11.01.002_threads_100000x100000.csv \
    --tpp-per-core 35.2 --topic ThreadSweep100000x100000 \
    --title "DCP5 (tasks, taskgroup{task LL + HH inline}, LH/HL inline, leaf 4096, depth 5), 100000x100000"
```

Gate passed in both sweeps. Same machine conditions as DCP3.1 and
DCP4.1: the other user's python job (one thread at ~90% CPU, seen on
cores 4 and 6, outside the 16-31 mask, not pinned) ran throughout; run
and noted as before. Load average 2.0 before, 5.3 after the thread sweep.

Recorded T(seq): 1.5107 s (13.24 GF/s), matching DCP3/DCP4 (same
sequential code). The thread sweep's T(seq) is this own entry
(`seq_time_source: min of 3: own`).

#### Results

Median of 5. Speedup vs T(seq) = 1.5107 s; %TPP = GF/s / (35.2 x t);
"ideal model" is the DCP3.1 Hypothesis K = 5 row (powers of 2 only);
"DCP3.1" and "DCP4.1" are their measured speedups:

| t  | time (s) | GF/s | speedup | ideal model | DCP3.1 | DCP4.1 | % TPP | rep spread |
|---:|---------:|-----:|--------:|------------:|-------:|-------:|------:|-----------:|
| 1  | 1.5108   | 13.2 | 1.00    | 1.00        | 1.00   | 1.00   | 37.6  | 0.1%       |
| 2  | 0.7800   | 25.6 | 1.94    | 1.94        | 1.33   | 1.33   | 36.4  | 0.1%       |
| 3  | 0.6422   | 31.1 | 2.35    |             | 1.60   | 1.61   | 29.5  | 8.3%       |
| 4  | 0.4901   | 40.8 | 3.08    | 3.20        | 1.82   | 1.67   | 29.0  | 2.9%       |
| 5  | 0.4626   | 43.2 | 3.27    |             | 2.26   | 1.71   | 24.6  | 1.2%       |
| 6  | 0.4360   | 45.9 | 3.47    |             | 2.63   | 1.74   | 21.7  | 1.4%       |
| 7  | 0.4156   | 48.1 | 3.64    |             | 2.85   | 1.74   | 19.5  | 1.1%       |
| 8  | 0.3918   | 51.0 | 3.86    | 4.00        | 3.03   | 1.76   | 18.1  | 1.1%       |
| 9  | 0.3832   | 52.2 | 3.94    |             | 3.25   | 1.76   | 16.5  | 1.1%       |
| 10 | 0.3801   | 52.6 | 3.97    |             | 3.42   | 1.77   | 14.9  | 0.7%       |
| 11 | 0.3760   | 53.2 | 4.02    |             | 3.56   | 1.77   | 13.7  | 0.8%       |
| 12 | 0.3714   | 53.8 | 4.07    |             | 3.68   | 1.78   | 12.7  | 1.0%       |
| 13 | 0.3701   | 54.0 | 4.08    |             | 3.72   | 1.77   | 11.8  | 0.5%       |
| 14 | 0.3698   | 54.1 | 4.09    |             | 3.78   | 1.78   | 11.0  | 0.4%       |
| 15 | 0.3685   | 54.3 | 4.10    |             | 3.87   | 1.78   | 10.3  | 0.4%       |
| 16 | 0.3645   | 54.9 | **4.15** | 4.20       | 3.93   | 1.78   | 9.7   | 0.4%       |

Measured / ideal model: 1.00 (t=2), 0.96 (t=4), 0.97 (t=8), 0.99
(t=16).

- Speedup 4.15x at 16 threads (54.9 GF/s), against the ideal model's
  4.20 (= W/S at K = 5); 1.06x DCP3.1's 3.93x and 2.3x DCP4.1's 1.78x.
- At 2 threads 1.94x (0.7800 s), matching the ideal model's 1.94; the
  first variant since DCP2 to move off 1.33x at 2 threads.
- Measured is within 4% of the ideal model at every power of 2.
- The curve rises at every thread count and flattens toward the W/S cap
  (3.86 at 8, 4.15 at 16).
- Rep spread <= 2.9% except t=3 (8.3%, one slow rep: 0.688 s vs
  ~0.64 s for the others; the median is unaffected).
- 1 thread of the OpenMP build matches the sequential binary (1.5108 vs
  1.5107 s).

Plot: `04-DCP5/plots/2026.11.01.001.ThreadSweep100000x100000.xlsx`.

#### Conclusion

(To be stated by the student.)

## 04-DCQ3: DCQ with BKQ7's tile body as the leaf (sequential)

### DCQ3.1: one zero-padded segment per b leaf, built once

#### Introduction

The DC kernels so far run their leaves at DCQ2's rate, 13.24 GF/s (37.6%
TPP), against BKQ7's 25.40 GF/s (72.2% TPP, PA3) for the best blocked
single-core kernel. DCP5.1's 4.15x at 16 threads was judged sufficient for
now (user); the next step is the leaf's rate, toward TPP, using BKQ7's
strategies. DCQ3 is a new sequential DC variant built from BKQ7.

#### Hypothesis

This should match BKQ7, achieving about 25 GF/s (about 72%), roughly flat for leaves of about 391–3125, since the recursion itself cost nothing measurable in DCQ2.2.

#### Design

Decisions (user): build from BKQ7; build all the copies once in
kernel_multiply, one padded segment per b leaf, and pass a pointer down
the recursion; split each side independently (so the b leaves are known
up front); leaf = one BKQ7 tile; a's split rounded to a multiple of 8;
directory `04-DCQ3`, leaf_size default 1024.

```
kernel_multiply:
    TJ = nleaves(nB)                       # b leaves from halving b alone
    4 copies of b, each TJ zero-padded segments (one per b leaf, left to right)
    dcq(a, nA, b, nB, copies, J=0, c)

dcq(a, na, b, nb, J, c):
    both na, nb > leaf:  LL, LH, HL, HH          # order as DCQ2
    only na > leaf:      a_lo, a_hi              # same b leaf J
    only nb > leaf:      b_lo (J), b_hi (J + nleaves(hb))
    neither:             leaf_tile(a, na, b leaf J, c)
```

- Split rule:
  - DCQ2's 4-way split ran until both sides were <= leaf, so b kept being
    split as long as a was too long (e.g. b down to length 1 for dB=3).
  - Now each side is split only while it is longer than leaf. The b
    leaves are then a fixed partition of b, enumerated once in
    kernel_multiply; J (index of the first b leaf of a b range) travels
    down the recursion.
  - hb = nb/2 rounded down to 16 floats (DCQ2's rule kept); ha = na/2
    rounded down to 8 rows (fallback na/2 when na < 16).
- Copies (BKQ7):
  - 4 copies; copy s, segment J holds seg[s + 7 + x] = b[jj + x] for the
    b leaf [jj, jj + w), zeros elsewhere.
  - Segment size from the widest b leaf, min(leaf, nB): w + 7 + 8 + 7 + 4
    rounded up to 16 floats.
  - Copies spaced a multiple of 1024 floats (4096 B), as BKQ6/7.
  - A struct with the buffer pointer, copy spacing and segment size is
    passed down the recursion.
- Leaf (BKQ7's tile body):
  - Rows in groups of R = 8. Row r reads copy s = (r + 1) % 4 through
    p[r] = seg + s + 7 - r.
  - The fused loop covers the group's whole trapezoid, u = 0 .. w + 6,
    rounded up to a multiple of 8. The extra products are a * 0.
  - Leftover rows (last a leaf only) run as scalar OPQ rows reading b
    directly.
  - The leaf is compiled with `no-associative-math` (BKQ3). It assumes
    finite inputs.
- The padded loop may add +0 to up to 7 elements of c past the leaf's
  own range (clamped to the end of c via a `climit` argument).
  Sequentially this changes no value. In a parallel version those
  elements can belong to a concurrently running leaf (the BKP5.1 race).
- Dropped from BKQ7: the block_size, block_width and copy_pad knobs (the
  tile is the leaf).
- Dropped from DCQ2: the aligned plain copy of b (the fused loop reads
  the segments; the leftover rows read b directly).
- Makefile and run.sh copied from DCQ2, variant name DCQ3.

#### Implementation

`04-DCQ3/` (Makefile and run.sh copied from `04-DCQ2`, variant name
`DCQ3`; kernel in `src/PolyMult.c`). Built with no warnings. Gate PASSED:
oracle 42/42 and gold 14/14, on both `PolyMult.check` and
`PolyMult.check-par` (gate tune leaf_size=64; the kernel has no OpenMP
code, so the parallel check runs the same sequential kernel).

#### Experiment

Same as DCQ2.1: sequential baseline at the default (leaf_size=1024),
recorded as DCQ3's T(seq) for 100000x100000.

```
./sweep.sh --variant-dir 04-DCQ3 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
```

Gate passed again inside the sweep. The other user's python job (one
thread at ~92% CPU, seen on core 4, not pinned) was running, as for
DCP3.1-DCP5.1; the timing core is 16. Load average 2.1 before, 2.8
after.

#### Results

Median of 7: 0.7864 s, **25.43 GF/s (72.3% TPP)**, reps 0.7862-0.7879 s
(within 0.2%).

| variant (leaf / block size) | time (s) | GF/s  | % TPP |
|-----------------------------|---------:|------:|------:|
| DCQ2 (4096), DCQ2.1 run 2   | 1.511    | 13.24 | 37.6  |
| **DCQ3 (1024)**             | 0.786    | 25.43 | 72.3  |
| BKQ7 (768), PA3 BKQ7.2      | -        | 25.40 | 72.2  |

- DCQ3 is 1.92x DCQ2 and matches BKQ7's best single-core rate (25.43 vs
  25.40 GF/s), the best single-core rate measured so far.
- At 100000 with leaf_size=1024, both sides halve 7 times, to leaves of
  ~781 x ~781 (b leaves rounded to 16 floats, a leaves to 8 rows).
- Building the 4 copies of b (once per call) is inside the timed region;
  its cost is not measured separately.
- Only the default leaf_size was timed; no leaf sweep yet.

#### Conclusion

(To be stated by the student.)

# NEXT

The experiment is a leaf-size sweep at 1 thread, plus the same perf counter groups as DCQ.3, compared against BKQ7.
### DCQ3.2: leaf size sweep

#### Introduction

DCQ3.1 ran at 72.3% TPP at the default leaf_size=1024, matching BKQ7.
DCQ.2's sweep of the OPQ-leaf DCQ had a plateau at leaf lengths
~195-3125 and dropped above 4096; this sweep checks how DCQ3's BKQ7 leaf
depends on leaf_size.

#### Hypothesis

(To be stated by the student.)

#### Design / Experiment

DCQ3.1 code unchanged. Same leaf-size list as DCQ.2, 1 thread, 7 reps:

```
./sweep.sh --variant-dir 04-DCQ3 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --tune leaf_size=16,32,64,96,128,256,512,1024,2048,4096,8192,16384 \
    --name 2026.11.01.002_leaf_sweep_100000x100000
.venv/bin/python plot.py --csv 04-DCQ3/results/2026.11.01.002_leaf_sweep_100000x100000.csv \
    --tpp-per-core 35.2 --topic LeafSizeSweep100000x100000 \
    --title "DCQ3 (BKQ7 tile leaf) leaf size sweep, 100000x100000, 1 core"
```

Gate passed inside the sweep. The other user's python job (one thread at
~92% CPU, seen on cores 4 and 12, not pinned) was running; the timing
core is 16. Load average 2.4 before, 3.1 after.

#### Results

Median of 7. Leaf counts and widths at 100001 coefficients are
arithmetic from the split rules (b at nb/2 rounded down to 16, a at na/2
rounded down to 8), not measured. Since the rounding makes the halves
unequal, leaves at one leaf_size can come from different depths (e.g. at
96, b leaves are 48-96 wide).

| leaf_size | b leaves | b leaf width | a leaf height | time (s) | GF/s  | % TPP | DCQ.2 % TPP |
|----------:|---------:|-------------:|--------------:|---------:|------:|------:|------------:|
| 16        | 6251     | 8-16         | 8-16          | 2.941    | 6.80  | 19.3  | 5.9         |
| 32        | 4097     | 16-32        | 16-32         | 1.818    | 11.00 | 31.3  | 11.3        |
| 64        | 2049     | 32-64        | 48-57         | 1.063    | 18.82 | 53.5  | 20.8        |
| 96        | 1130     | 48-96        | 48-96         | 0.925    | 21.62 | 61.4  | 20.8        |
| 128       | 1024     | 96-113       | 96-105        | 0.902    | 22.18 | 63.0  | 30.6        |
| 256       | 512      | 192-209      | 192-201       | 0.826    | 24.21 | 68.8  | 33.3        |
| 512       | 256      | 384-401      | 384-393       | 0.795    | 25.17 | 71.5  | 34.3        |
| 1024      | 128      | 768-785      | 776-785       | 0.786    | **25.44** | **72.3** | 32.7  |
| 2048      | 64       | 1552-1569    | 1560-1569     | 0.807    | 24.78 | 70.4  | 33.8        |
| 4096      | 32       | 3120-3137    | 3120-3129     | 0.794    | 25.19 | 71.6  | 34.4        |
| 8192      | 16       | 6240-6257    | 6248-6257     | 0.789    | 25.36 | 72.1  | 25.4        |
| 16384     | 8        | 12496-12513  | 12496-12505   | 0.787    | 25.43 | 72.2  | 26.1        |

Rep spread <= 0.3% everywhere.

- Plateau at 70.4-72.3% TPP from leaf_size 512 to 16384 (leaves ~390 to
  ~12500 long), a 2.7% range. Best: 25.44 GF/s (72.3%) at 1024, the
  default, with 16384 (25.43) and 8192 (25.36) within 0.3%.
- A shallow dip at 2048 (70.4%), below both 1024 and 4096. (BKQ7.2 had a
  ~2% dip at block size 1536-2048, not explained.)
- Unlike DCQ.2, no drop above 4096: 8192 and 16384 stay at ~72%, where
  DCQ's OPQ leaf fell to ~25-26%.
- Below 512 the rate falls steadily: 68.8% at 256, 63.0% at 128, 53.5% at
  64, 19.3% at 16.
- 64 and 96 now differ (53.5% vs 61.4%); in DCQ.2 they were equal
  (both ~49-long leaves). With DCQ3's rounded, independent splits,
  leaf_size=96 stops splitting at a mix of depths (leaves 48-96).
- Every leaf_size is faster than DCQ.2's at the same leaf_size, by 2.1x
  to 3.3x (2.1x at DCQ.2's best, 4096).
- The leaf_size=1024 point (0.7863 s) agrees with DCQ3.1's run (0.7864 s).

Plot: `04-DCQ3/plots/2026.11.01.001.LeafSizeSweep100000x100000.xlsx`.

#### Conclusion

(To be stated by the student.)


### DCQ3.3: perf comparison with BKQ7

**Hypothesis.**
- H1: DCQ3@1024 has the same per-FMA profile as BKQ7@768: cycles ~1.38
  per vector FMA (72%), the same instructions, ~2.25 load µops (9 loads x
  2 µops / 8 FMAs), and split loads near 0. The b copies are read at
  16-B offsets and the c window moves 8 floats per group. The recursion
  adds nothing measurable. Refuted if cycles or instructions per FMA
  differ by more than ~2%.
- H2: the 2048 dip is address placement, not leaf size: 4K aliasing or
  L1 set conflicts between the copies and c. Supported if
  `ld_blocks.address_alias` or L1 misses per FMA rise from DCQ3@1024 to
  DCQ3@2048, and BKQ7@2048 shows the same. Refuted if neither moves.
- H3: big leaves stay fast although the b segments (4 copies x ~50 KB
  at 16384) exceed L1. L1 misses per FMA rise at 16384, but cycles do
  not, because the streaming loads are prefetched from L2. Refuted if
  L1 misses do not rise (the working set still fits), or if cycles rise.

**Design / Experiment.** The existing gate-passed timing binaries in
`../PA4/04-DCQ3/bin` and `../PA4/03-BKQ7/bin` were used (sources and
`shared/` verified identical to this worktree). 100000x100000, 1 thread,
3 reps, `taskset -c 16`, one run at a time. Two groups each, both 100%
counted. Groups are the same as DCQ2.2 (G1: cycles, instructions,
all_loads, split_loads; G2: cycles, l1_hit, l1_miss, address_alias).
Configurations: DCQ3 leaf_size=1024 / 2048 / 16384; BKQ7 block_size=768 /
2048. Script and raw output: `04-DCQ3/results/perf_2026.11.01.003/`. Run
2026-11-01 20:53:53-~20:54:18, load average 1.6-2.0. Core 16 was clear
before every group except one: before bkq7_bs2048 g1, a long-lived,
mostly idle process of this user (`MainThread`, 0.2% lifetime CPU) was
listed at 2.5%. The two groups' cycle counts agree to 0.17% there and to
≤ 0.04% elsewhere. Wall times reproduce the sweeps (DCQ3@1024
0.786 s).

**Results.** Per vector FMA = 3 x 100001² / 8 = 3.75e9.

|                          | DCQ3 1024 | BKQ7 768 | DCQ3 2048 | BKQ7 2048 | DCQ3 16384 |
|--------------------------|----------:|---------:|----------:|----------:|-----------:|
| wall (s, per rep)        | 0.786     | 0.788    | 0.806     | 0.804     | 0.786      |
| cycles / FMA             | 1.378     | 1.381    | 1.414     | 1.411     | 1.379      |
| = % TPP                  | 72.6      | 72.4     | 70.7      | 70.9      | 72.5       |
| instructions / FMA       | 1.706     | 1.716    | 1.667     | 1.661     | 1.633      |
| load µops / FMA          | 2.291     | 2.301    | 2.271     | 2.270     | 2.254      |
| split loads / FMA        | 0.00000   | 0.00002  | 0.00000   | 0.00002   | 0.00000    |
| L1 misses / FMA (% loads)| 0.0031 (0.14%) | 0.0025 (0.11%) | **0.302 (13.3%)** | **0.296 (13.0%)** | 0.117 (5.2%) |
| address_alias / FMA      | 0.0029    | 0.0025   | **0.301** | **0.292** | 0.116      |

- Load µops are ~2.25-2.30 per FMA, as designed (9 loads x 2 µops / 8
  FMAs = 2.25, plus loop overhead). There are no split loads.
- DCQ3@1024 and BKQ7@768 agree within 0.6% on every core counter.
  DCQ3 is 0.2% faster in cycles.
- DCQ3@2048 and BKQ7@2048 agree with each other. Both show L1 misses
  about 100x higher than at 1024/768 (13% of loads) and address_alias
  rising by the same amount. Cycles rise only 2.6%: ~0.036 extra cycles
  per FMA for ~0.30 extra misses, so most of the miss latency is hidden.
- DCQ3@16384: L1 misses 5.2% of loads, fewer than at 2048, with no cycle
  cost (1.379, the same as 1024).
- In all five runs `address_alias` ≈ `l1_miss` (within 1-3%). In DCQ2.2,
  with the OPQ leaf, they were not equal (0.023 alias vs ~0.0065 misses
  per FMA). PA3 BKQ4.3 saw the two move together with this kind of
  copy layout and could not separate them.
- Instructions fall with leaf size (1.706 -> 1.633): fewer per-group and
  per-leaf setup instructions per FMA.

**Conclusion.**
- H1 supported. The DC recursion over BKQ7 tiles costs nothing
  measurable. DCQ3 is BKQ7's kernel at the same per-FMA cost (1.378 vs
  1.381 cycles).
- H2 supported in part. The 2048 dip comes with a large jump in L1
  misses and aliasing, the same in DCQ3 and BKQ7, so it belongs to the
  copy/tile geometry shared by both kernels, not to the recursion. Copy
  spacing is not the obvious difference. From the source, copies are
  135168 floats apart at 1024 and 133120 at 2048. Both are multiples of
  4096 B, and in both a segment is 128 B past a multiple of 4096 B
  (seg = 1056 / 2080 floats; sized from leaf_size, not from the actual
  leaf width). The missing piece is whether the cause
  is L1 set conflicts (8 b streams, spaced by multiples of 4096 B plus
  ≤ 16 B, sit in the same L1 set as each other, and c can add a 9th line
  to an 8-way set) or 4K aliasing. The counters cannot separate them, as
  in BKQ4.3. The non-monotonic miss rate (2048 > 16384 > 1024) fits a
  placement effect better than a capacity effect. This is an inference.
- H3 supported. At 16384 the L1 miss rate rises (0.14% -> 5.2%) with no
  cycle cost: the streams are prefetched.
- Headroom: 1.378 cycles per FMA against a load-port bound of ~1.15
  (2.29 load µops per FMA at an assumed 2 load µops per cycle, i.e.
  ~87%; the same cap as PA3's ~89% estimate). ~0.23 cycles per FMA are
  not explained by the loads. Port/topdown counters were not measured.
  They would be the next profile if 3b goes beyond 72%.

### DCQ3.4: top-down profile, which costs belong to which program features

Run by the student without Claude (perf runs and their summary are the
student's; reformatted here into the record's layout).

#### Introduction

DCQ3.2 left DCQ3 at 72.3% TPP (leaf_size=1024), with lower rates at
small leaves and a dip at 2048. The current kernel per 8 lanes does 9
vector loads (8 b windows + c), 8 FMAs (one dependent chain into c,
~6-cycle latency each, PA3 BKQ5.1) and 1 store. Measured: 1.378
cycles/FMA; load-port bound ~1.15.

Candidate strategies (student), with the profile as step 0:

0. **Profile first.** Measure topdown_be_bound.{all, non_mem_scheduler,
   mem_scheduler, register, reorder_buffer, alloc_restrictions} and
   uops_issued.any on DCQ3@1024 (the events PA3 BKQ4.2 used). This
   tells whether the remaining 0.23 cycles/FMA come from the load ports,
   the FMA latency chain (scheduler full) or allocation.
1. **Reuse each b window across rows 8 apart.** Row i, c vector v reads
   b[8v-i .. 8v-i+7]. Row i+8, c vector v+1 reads exactly the same
   window. With rows {i..i+3, i+8..i+11} per group, each loaded window
   feeds 2 FMAs (into c_v and c_{v+1}). That is 4 b loads + 1 c load per
   8 FMAs, 5 instead of 9, with a load bound of ~0.63 cycles/FMA. It uses
   ~14 of 16 ymm registers (8 broadcasts, 4 windows, 2 accumulators), and
   there are two independent chains live at once.
   - Risk: in C this is `p_r[u-8]`, a load from the previous vector
     iteration. GCC is unlikely to turn that into register reuse.
     Intrinsics or vector extensions would bypass the mandatory scalar
     `BPM_ACC` (PA3 BKQ5.1 note). That is a rules question for the
     instructor before any design.
2. **More independent chains.** Interleaving or unrolling (PA3 BKQ5.1:
   neutral at 1024, worse at 2048-3072). Idea 1 also gets this.
3. **Placement (copy_pad or per-call spacing).** Recovers the 2048 dip
   (~2%), but not past 72%.
4. Out of scope for "toward TPP": Karatsuba-style splitting (3
   sub-products instead of 4) reduces the FLOPs themselves and changes
   rounding behaviour.

#### Hypothesis

- H1: at leaf_size=1024 the kernel is backend-bound on the load side
  (memory scheduler / load buffer full), as in PA3 BKQ3.2, but less than
  there, because there are no split loads. The FP (non-memory) scheduler
  being full, i.e. the FMA chain, is the second limit. Retiring is ~70%
  of slots.
- H2: at leaf_size=64 the extra cost is per-leaf and per-group work.
  Zero-padded trapezoid products: tlen = roundup8(w+14) versus w useful,
  ~10-25% at w≈48-57. Per-group setup (8 broadcasts, 8 pointers) and
  recursion calls add instructions per useful FMA. Instructions and
  µops per FMA rise; the stall categories stay similar.
- H3: at 2048 the extra 0.036 cycles/FMA appear as load-side stall
  (memory scheduler, or load latency at retirement: ld_head), matching
  the L1 misses of DCQ3.3.
- Time outside the leaf (zeroing c, building the copies, harness input
  setup) is ≲ 1% (perf record).

#### Design / Experiment

Existing gate-passed binary `../PA4/04-DCQ3/bin/PolyMult.time` (source
identical). 100000x100000, 1 thread, 3 reps, `taskset -c 16`, one run at a time. leaf_size 1024, 64
and 2048, five counter groups each (the four PA3 BKQ3.2 groups, plus
uops_retired, ld_head, mem_bound_stalls.load, address_alias). There were
also two `perf record` runs (cycles, leaf_size 1024 and 64). Script, raw
output, `.data` files and core-16 log are in
`04-DCQ3/results/perf_2026.11.01.004/`. Run 2026-11-01 21:00:45-~21:01:32,
load average 1.6-2.1. Core 16 was clear before every run except one:
before leaf64 g3, the same idle `MainThread` process as in DCQ3.3 was
listed at 2.5%.

Caveat: groups 3 and 4 have 7 programmable events and were
multiplexed (counted 85% of the time, scaled by perf). Their ratios are
estimates. The other groups were counted 100%. Cycles agree across the
five groups to 0.06% (1024), 0.76% (64) and 0.05% (2048).

#### Results

Per vector FMA (useful, 3 x 100001² / 8 = 3.75e9). Slots =
5 per cycle (the sum of the level-1 categories is exactly 5.00 x cycles).

| per vector FMA              | leaf 1024 | leaf 64 | leaf 2048 |
|-----------------------------|----------:|--------:|----------:|
| cycles                      | 1.378     | 1.863   | 1.414     |
| instructions                | 1.706     | 3.378   | 1.667     |
| µops issued / retired       | 3.007 / 2.981 | 5.119 / 5.089 | 2.943 / 2.930 |
| load / store µops           | 2.291 / 0.259 | 3.030 / 0.499 | 2.271 / 0.255 |
| split loads                 | 0         | 0       | 0         |
| L1 misses                   | 0.003     | 0.012   | 0.302     |

| % of slots                         | leaf 1024 | leaf 64 | leaf 2048 |
|------------------------------------|----------:|--------:|----------:|
| retiring                           | 43.3      | 54.7    | 41.5      |
| backend bound                      | 53.4      | 43.0    | 56.7      |
| - non-memory (FP) scheduler full   | **49.9**  | 30.3    | 43.6      |
| - memory scheduler full            | 3.3       | 7.3     | **12.9**  |
| - reorder buffer full              | 0.1       | 4.9     | 0.1       |
| - register / alloc / serialization | 0.1       | 0.6     | 0.1       |
| frontend bound                     | 0.7       | 1.1     | 0.6       |
| bad speculation                    | 2.6       | 1.2     | 1.3       |

| % of cycles                 | leaf 1024 | leaf 64 | leaf 2048 |
|-----------------------------|----------:|--------:|----------:|
| load buffer full            | 0.23      | 1.09    | 4.67      |
| mem_bound_stalls.load       | 0.34      | 0.62    | **15.24** |
| ld_head (load blocking retirement) | 0.09 | 0.05 | 0.10      |

Where the time is (`perf record`, cycles): `leaf_tile` 99.67% at 1024
and 97.50% at 64. `dcq` (the recursion) is 0.02% at 1024 and 2.15% at
64. Copy building, c zeroing (`memset`) and harness input (`random`)
are ≤ 0.2% together.

Hot-loop samples at 1024 (`perf annotate`, subject to skid). 44% land
on the c store `vmovups` and 18% on the following `add`. The FMAs
together get ~29%: one late FMA has 12.7%, three others ~4.7% each, the
rest < 2%. The first b load gets 2.4%.

Arithmetic (Python replica of the split rules, not measured):

| leaf_size | leaves | 8-row groups | vector iterations / group | executed / useful products |
|---:|---:|---:|---:|---:|
| 1024 | 16384 | 1.60M | 98.7 | 1.010 |
| 64 | 4.20M | 25.6M | 7.1 | 1.164 |
| 2048 | 4096 | 0.80M | 196.3 | 1.005 |

Scalar leftover-row products are < 0.001% of useful products at every
size.

##### Cost → program features

At leaf_size=1024, out of 1.378 cycles per useful FMA (1.0 = TPP):

| program feature | counter evidence | approx. cost (cycles/FMA) |
|---|---|---|
| 1 FMA per cycle (the TPP floor) | — | 1.000 |
| **8-FMA dependent chain into each c vector** (`no-associative-math`; one accumulator per c vector, 6-cycle FMA latency) | FP scheduler full 49.9% of slots while the FMA port is busy only ~73% of cycles; samples pile up on the store that waits for the chain's last FMA | **~0.29** (the remainder after the rows below) |
| Loop exit at the end of every 8-row group (trip ~99) | bad speculation 2.6% of slots (≈ 2.6% × 1.378) | ~0.04 |
| Load side: 9 loads per 8 FMAs (8 b windows + c), load buffer | memory scheduler 3.3% of slots, load buffer full 0.2% of cycles | ~0.05 |
| Zero-padded trapezoid (tlen = roundup8(w+14)) | 1.0% extra products | ~0.01 |
| Recursion, copy build, c zeroing, harness | perf record: 0.3% outside `leaf_tile` | < 0.01 |

The slot fraction x cycles conversion is approximate; the categories are
measured per slot, not per cycle.

At leaf_size=64 (1.863 cycles/FMA, +0.485 over 1024):

| program feature | evidence | approx. extra cost |
|---|---|---|
| Zero padding of the trapezoid at w ≈ 32-64 | 16.4% extra products (arithmetic) | ~0.21 |
| Per-group setup and loop entry/exit (8 broadcasts, 8 pointers; 20x more groups, 7 iterations each) | instructions 3.38 vs 1.71/FMA; µops 5.1 vs 3.0; ROB full 4.9% of slots | ~0.23 (≈ 11 cycles per group) |
| Recursion (`dcq`, 5.6M calls) | perf record: 2.15% of cycles | ~0.04 |

At leaf_size=2048 (+0.036 over 1024): L1 misses (0.30 per FMA) show up as
mem_bound_stalls.load 15.2% of cycles, memory scheduler full 12.9% of
slots and load buffer full 4.7% of cycles. This is the copy/c placement
effect of DCQ3.3.

#### Conclusion

- H1 refuted in its ordering. At 1024 the load side is now minor (3.3%
  of slots). The dominant limit is the FP scheduler being full (49.9% of
  slots): the FMA latency chain. Retiring is 43%, not ~70%. With
  3.0 µops per FMA and 5 slots per cycle, retiring could reach at most
  ~60% at TPP. This is the mirror image of PA3 BKQ3.2 (load buffer full
  59%, FP scheduler 0%): aligned copies removed the load limit, and the
  chain is next, as BKQ4.2 already hinted (~30%).
- H2 supported. At 64 the extra cost splits roughly evenly between
  zero-padding (~16% extra products) and per-group/per-leaf setup. The
  recursion itself is only ~2%.
- H3 supported. The 2048 dip is load stalls from L1 misses, 15% of
  cycles, mostly hidden.
- Outside-the-leaf costs are negligible (≤ 0.3%).
- Implication for strategies (ideas section above):
  - Idea 2, more independent chains interleaved in program order, now
    targets the largest cost.
  - Idea 1, b-window reuse, is still worth it, but mainly because it
    gives two live accumulators. The load ports are no longer the
    limit.
  - Shortening the chain (for example 2 partial sums of 4 FMAs per c
    vector) would also address it. That changes the summation order,
    which is a correctness/rules question. PA3 BKQ2 showed GCC's
    associative-math version split the FMAs badly.

## 04-DCQ4: DCQ3 with interleaved c-vector accumulators (sequential)

### DCQ4.1: Stage A, M = 4 interleaved c vectors per step

#### Introduction

Student: the biggest target is now the FMA chain (DCQ3.4: FP scheduler
full 49.9% of slots at leaf_size=1024). The way to get at it is more
independent accumulators, interleaved in program order. Reusing b windows
(idea 1) might be worth doing, even if its main value now is that it
keeps two accumulators live at once, not the load savings.

Order of work (student): Stage A alone first, as its own variant (e.g.
DCQ4), measured on its own. Stage B, if done, comes later as a separate
variant, keeping one change per variant.

#### Hypothesis

Student:
- The FP-scheduler-full share drops well below today's 49.9% of slots.
- Cycles per FMA fall from 1.378 to about 1.13-1.15, which is about
  80-87% of TPP.
- Load µops stay at about 2.29 per FMA.
- Timed output is bitwise identical to DCQ3 at the same leaf_size.
- If the FP scheduler is still often full, either GCC didn't interleave
  the chains (visible in the assembly) or 4 chains aren't enough to hide
  the FMA latency.

#### Design

Stage A: interleave several c vectors (tackles the FMA chain). Each loop
step covers M consecutive c vectors, and the FMAs are issued row by row
across the M accumulators:

```
for each step u (stride 8*M):
    for r in 0..7:                 # rows, ascending, as now
        for m in 0..M-1:           # M independent accumulators
            C[m] += a_r * p_r[u + 8m]
tail (vectors left over when not a multiple of M): the existing 1-vector loop
```

- Order is unchanged. Each C[m] still gets rows 0..7 in order. The
  instruction stream now alternates between M independent chains,
  instead of running 8 dependent FMAs back to back.
- Registers: 8 broadcast a values plus M accumulators; M = 4 uses 12 of
  the 16 ymm registers, provided GCC folds each b window into its FMA as
  a memory operand (in today's loop, the accumulator register itself
  receives the first b load, so no separate temporary appears; the
  assembly will settle it). Loads stay at 9 per 8 FMAs.

Writing it in C with BPM_ACC (no intrinsics):
- Write each step as an inner 8-lane loop whose body lists the BPM_ACC
  statements in the interleaved (r, m) order, for example
  `BPM_ACC(c, comp, k0+u+8*m+l, a_r * p_r[u+8*m+l])`.
- The compiler isn't guaranteed to cooperate. GCC must vectorize the
  lane loop, keep the statement order, hold each C[m] in a register
  across its updates, and (for Stage B) merge the shared window loads.
- So check the assembly after every change; PA3's BKQ5 unroll came out
  as chains run one after another.
- The checking build runs the same loop structure in scalar form, so the
  gate still tests the real control flow.

Implementation choices (Stage A, user's go-ahead to implement):
- `04-DCQ4/` copied from `04-DCQ3` (Makefile, run.sh, kernel; variant
  name DCQ4). Only the leaf's fused loop changed; recursion, split rules,
  copies of b, leftover rows and `no-associative-math` are DCQ3's.
- M = 4, fixed (`#define M 4`); no new tune knob.
- Main loop: u steps by 8 * M = 32; inside, an 8-lane loop over l whose
  body is 8 `ROW_M(a_r, p_r)` macro calls, r = 0..7 in order, each
  expanding to 4 `BPM_ACC` statements for m = 0..3, i.e. the interleaved
  (r, m) order:
  `BPM_ACC(c, comp, k0 + u + 8m + l, a_r * p_r[u + 8m + l])`.
- Tail: DCQ3's 1-vector loop runs the remaining u (fewer than M vectors:
  up to 3 when tlen is not a multiple of 32, or when ulen is clamped by
  climit at the end of c).

Later, separate variant: Stage B, rows 8 apart share a b window (fewer
loads).
- Row r at c vector m reads window p_r[u+8m], and row r+8 at vector m+1
  reads exactly the same window. So make each group R rows instead of 8
  (8 < R <= about 12, still in ascending order).
- Within a step: rows 8..R-1 at vectors m >= 1 reuse the window that row
  r-8 loaded for vector m-1 in the same step. It's the same address in
  the same iteration, so the compiler can merge the two loads, but only
  if GCC keeps that register live, which only the assembly can show.
- At m = 0: the shared window belongs to the previous step. Reloading it
  is simplest; carrying it in a register also works.
- Live ranges: with rows in the outer loop, the window that row r loads
  for vector m is used again only at row r+8 for vector m+1, so rows
  0..R-9 each keep M-1 windows live across most of the step:
  ymm ~ R (broadcasts) + M (accumulators) + (R-8)(M-1) (carried windows).

  | R  | M | registers                              | loads per FMA |
  |---:|--:|----------------------------------------|--------------:|
  | 10 | 3 | 17: over the limit, so reloads or spills | -           |
  | 10 | 2 | 14                                     | 1.00          |
  | 9  | 3 | 14                                     | 1.04          |

- Reordering doesn't escape this. Running (r+8, m+1) right after (r, m)
  would need C[m+1] to be 8 rows ahead of C[m], which removes most of
  Stage A's interleaving. The core trade-off: window reuse costs either
  registers or interleaving.
- Limit: fusing two whole 8-row groups would need about 25 registers
  (16 broadcasts, 8 carried windows, at least 1 accumulator), and AVX2
  FMA can't take a broadcast directly from memory. So more window reuse
  means fewer interleaved chains.
- Side changes:
  - split_a has to round to a multiple of R, otherwise every leaf gets
    leftover scalar rows.
  - The b copies need at least R-1 leading zeros.
  - The trapezoid gets R-8 extra zero products per row.
  - The overrun into c stays at 7 elements or fewer (the loop range is
    still rounded up to a multiple of 8), as in DCQ3 now. It matters
    only for a future parallel variant that uses DCQ3's leaf, as in
    BKP5.1; DCP5 still uses DCQ2's plain leaf and has no overrun.

#### Implementation

`04-DCQ4/` (Makefile and run.sh copied from `04-DCQ3`, variant name
`DCQ4`; kernel in `src/PolyMult.c`). Built with no warnings. Gate PASSED:
oracle 42/42 and gold 14/14, on both `PolyMult.check` and
`PolyMult.check-par` (gate tune leaf_size=64; no OpenMP code, so the
parallel check runs the same sequential kernel). The checking build is
scalar (Kahan `BPM_ACC`), so the gate tests the loop structure and tail
handling, not the vectorized code or its instruction order. Assembly not
yet inspected.

#### Experiment

Same as DCQ3.1 + DCQ3.2: sequential baseline at the default
(leaf_size=1024), recorded as DCQ4's T(seq) for 100000x100000, then the
same leaf-size sweep, 1 thread, 7 reps.

```
./sweep.sh --variant-dir 04-DCQ4 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 04-DCQ4 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --tune leaf_size=16,32,64,96,128,256,512,1024,2048,4096,8192,16384 \
    --name 2026.11.01.002_leaf_sweep_100000x100000
.venv/bin/python plot.py --csv 04-DCQ4/results/2026.11.01.002_leaf_sweep_100000x100000.csv \
    --tpp-per-core 35.2 --topic LeafSizeSweep100000x100000 \
    --title "DCQ4 (BKQ7 tile leaf, Stage A M=4 interleave) leaf size sweep, 100000x100000, 1 core"
```

Gate passed inside both sweeps. The other user's python job (one thread
at ~90% CPU, seen on cores 4 and 5, not pinned) was running, as for
DCQ3.1/3.2; the timing core is 16. Load average 2.5 before, 3.1 after.
No perf counters and no assembly inspection in this run.

#### Results

Baseline (leaf_size=1024): median of 7 0.6912 s, **28.94 GF/s (82.2%
TPP)**, reps 0.6906-0.6921 s (within 0.2%); DCQ3.1: 0.7864 s, 25.43 GF/s
(72.3%).

Leaf sweep, median of 7. "TPP-relative cycles/FMA" is 1 / (fraction of
TPP), i.e. cycles per vector FMA if TPP is 1 vector FMA per cycle at the
TPP clock; derived from time, not measured with counters (DCQ3.4
measured 1.378 for DCQ3 at 1024).

| leaf_size | time (s) | GF/s  | % TPP | DCQ3 % TPP | DCQ4 / DCQ3 | TPP-rel. cycles/FMA | rep spread |
|----------:|---------:|------:|------:|-----------:|------------:|--------------------:|-----------:|
| 16        | 3.245    | 6.16  | 17.5  | 19.3       | 0.907       | 5.71                | 1.6%       |
| 32        | 1.912    | 10.46 | 29.7  | 31.3       | 0.951       | 3.36                | 0.7%       |
| 64        | 1.138    | 17.58 | 49.9  | 53.5       | 0.934       | 2.00                | 0.3%       |
| 96        | 0.853    | 23.44 | 66.6  | 61.4       | 1.084       | 1.50                | 0.2%       |
| 128       | 0.829    | 24.12 | 68.5  | 63.0       | 1.088       | 1.46                | 0.2%       |
| 256       | 0.737    | 27.15 | 77.1  | 68.8       | 1.122       | 1.30                | 0.2%       |
| 512       | 0.706    | 28.35 | 80.5  | 71.5       | 1.126       | 1.24                | 0.2%       |
| 1024      | 0.692    | **28.91** | **82.1** | 72.3    | **1.137**   | 1.22                | 0.2%       |
| 2048      | 0.780    | 25.66 | 72.9  | 70.4       | 1.035       | 1.37                | 0.4%       |
| 4096      | 0.960    | 20.84 | 59.2  | 71.6       | 0.827       | 1.69                | 0.8%       |
| 8192      | 0.954    | 20.97 | 59.6  | 72.1       | 0.827       | 1.68                | 1.9%       |
| 16384     | 0.964    | 20.74 | 58.9  | 72.2       | 0.816       | 1.70                | 0.6%       |

- Best: 28.91 GF/s (82.1% TPP) at leaf_size=1024, 1.14x DCQ3 at the
  same leaf_size and 1.14x BKQ7's 25.40 GF/s; the best single-core rate
  so far. The baseline run agrees (0.6912 vs 0.6916 s).
- Against the Hypothesis's 1.13-1.15 cycles/FMA: the TPP-relative value
  at 1024 is 1.22 (82%), between DCQ3's 1.378 and the predicted range.
- DCQ4 is faster than DCQ3 from 96 to 1024, by 8-14%, most at 512-1024,
  and by 3.5% at 2048.
- Surprise: from 4096 up, DCQ4 is 17-18% slower than DCQ3 (59% vs ~72%
  TPP), a flat level from 4096 to 16384; DCQ3 had no such drop. 2048
  sits between (72.9%, still above DCQ3's 70.4% dip).
- Below 96 DCQ4 is also slower than DCQ3 (5-9%).
- Rep spread <= 0.8% except leaf_size=16 (1.6%) and 8192 (1.9%).
- Not checked here: the Hypothesis's FP-scheduler share and load µops
  per FMA (need counters), bitwise-identical output to DCQ3 (the sweep
  does not compare outputs), and whether GCC interleaved the chains
  (assembly).

Plot: `04-DCQ4/plots/2026.11.01.001.LeafSizeSweep100000x100000.xlsx`.

#### Conclusion

(To be stated by the student.)

## 04-DCQ5: DCQ4 + Stage B, rows 8 apart share a b window (sequential)

### DCQ5.1: R = 10 rows per group, M = 2 interleaved c vectors

#### Introduction

DCQ4.1 (Stage A, M = 4, R = 8) reached 82.1% TPP at leaf_size=1024,
1.14x DCQ3, but fell to ~59% from leaf_size 4096 up. Stage B (DCQ4.1
Design, "Later, separate variant") reduces loads per FMA by letting rows
8 apart share a b window. The user chose to implement Stage B next.

#### Hypothesis

(To be stated by the student.)

#### Design

Decisions (user): Stage B with R = 10, M = 2 (DCQ4.1 Design table: 14 ymm
registers, 1.00 loads per FMA); new directory `04-DCQ5`, copied from
`04-DCQ4` (Stage A's step structure kept).

```
per 10-row group, per step u (stride 16):
    for l in 0..7:                                   # lane loop
        for r in 0..7:  C0 += a_r * p_r[u+l];     C1 += a_r * p_r[u+8+l]
        r = 8:          C0 += a_8 * p_0[u-8+l];   C1 += a_8 * p_0[u+l]    # = row 0's m=0 window
        r = 9:          C0 += a_9 * p_1[u-8+l];   C1 += a_9 * p_1[u+l]    # = row 1's m=0 window
tail (one vector left, or ulen clamped): 1-vector loop, rows 0..9
```

- Rows 8, 9 have no pointers of their own: p_{r+8} = p_r - 8 (same copy,
  since (r + 9) % 4 = (r + 1) % 4), so they are written as p_r[x - 8]. At
  m = 1 this is the identical expression row r used at m = 0 in the same
  step (`p0[u + l]`, `p1[u + l]`), which gives GCC the chance to merge the
  loads; at m = 0 they reload the previous step's window
  (`p0[u - 8 + l]`). (Claude's choice of how to express the sharing in C;
  not discussed.)
- Order: each c element gets rows 0..9 in ascending order;
  `no-associative-math` kept.
- Side changes for R = 10 (DCQ4.1 Design list):
  - split_a: ha = na/2 rounded down to a multiple of 10 (fallback na/2
    when na < 20).
  - Leading zeros per segment LZ = 11 (>= R - 1 = 9; LZ % 4 == 3 keeps
    p[r] = seg + s + LZ - r on a 16-byte boundary with s = (r + 1) % 4).
  - Trapezoid u = 0 .. w + 8, rounded up to a multiple of 8 (2 more zero
    products per row than R = 8).
  - Segment size w + R + LZ + 9 = w + 30 floats, rounded up to 16.
  - Overrun past a leaf's range of c stays <= 7 elements (clamped by
    climit).
- M = 2 and R = 10 fixed (`#define`); no new tune knob. Recursion, b
  split rule, copies' spacing, leftover rows unchanged from DCQ3/DCQ4.
- Written with `BPM_ACC` only. Whether GCC vectorizes the lane loop,
  merges the shared loads and keeps 10 broadcasts + 2 accumulators in
  registers is not guaranteed: assembly.

#### Implementation

`04-DCQ5/` (Makefile and run.sh copied from `04-DCQ4`, variant name
`DCQ5`; kernel in `src/PolyMult.c`). Built with no warnings. Gate PASSED:
oracle 42/42 and gold 14/14, on both `PolyMult.check` and
`PolyMult.check-par` (gate tune leaf_size=64; no OpenMP code, so the
parallel check runs the same sequential kernel). The checking build is
scalar (Kahan `BPM_ACC`), so the gate tests the loop structure, the
p[r] - 8 reads for rows 8-9, the R = 10 split and the tail, not the
vectorized code or its instruction order. Assembly not yet inspected.

#### Experiment

Same as DCQ4.1: sequential baseline at the default (leaf_size=1024),
recorded as DCQ5's T(seq) for 100000x100000, then the same leaf-size
sweep, 1 thread, 7 reps.

```
./sweep.sh --variant-dir 04-DCQ5 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.11.01.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 04-DCQ5 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --tune leaf_size=16,32,64,96,128,256,512,1024,2048,4096,8192,16384 \
    --name 2026.11.01.002_leaf_sweep_100000x100000
.venv/bin/python plot.py --csv 04-DCQ5/results/2026.11.01.002_leaf_sweep_100000x100000.csv \
    --tpp-per-core 35.2 --topic LeafSizeSweep100000x100000 \
    --title "DCQ5 (Stage B, R=10 M=2) leaf size sweep, 100000x100000, 1 core"
```

Gate passed inside both sweeps. Machine quieter than for DCQ3.1-DCQ4.1:
the other user's python job was gone; 2 users logged in, only this
session's processes using CPU (a `MainThread` at 1.6% seen on core 17
after the sweep). Load average 0.7 before, 1.5 after. No perf counters
and no assembly inspection in this run.

#### Results

Baseline (leaf_size=1024): median of 7 0.8073 s, 24.77 GF/s (70.4% TPP),
reps within 0.15%.

Leaf sweep, median of 7. TPP-relative cycles/FMA as in DCQ4.1 (1 / fraction
of TPP; derived from time, not counters):

| leaf_size | time (s) | GF/s  | % TPP | DCQ4 % TPP | DCQ3 % TPP | DCQ5 / DCQ4 | TPP-rel. cycles/FMA | rep spread |
|----------:|---------:|------:|------:|-----------:|-----------:|------------:|--------------------:|-----------:|
| 16        | 3.416    | 5.85  | 16.6  | 17.5       | 19.3       | 0.950       | 6.01                | 0.7%       |
| 32        | 2.131    | 9.39  | 26.7  | 29.7       | 31.3       | 0.897       | 3.75                | 0.2%       |
| 64        | 1.230    | 16.26 | 46.2  | 49.9       | 53.5       | 0.925       | 2.16                | 0.1%       |
| 96        | 1.027    | 19.47 | 55.3  | 66.6       | 61.4       | 0.831       | 1.81                | 0.1%       |
| 128       | 0.981    | 20.39 | 57.9  | 68.5       | 63.0       | 0.845       | 1.73                | 0.1%       |
| 256       | 0.874    | 22.88 | 65.0  | 77.1       | 68.8       | 0.843       | 1.54                | 0.2%       |
| 512       | 0.824    | 24.26 | 68.9  | 80.5       | 71.5       | 0.856       | 1.45                | 0.2%       |
| 1024      | 0.806    | 24.80 | 70.5  | **82.1**   | 72.3       | 0.858       | 1.42                | 0.2%       |
| 2048      | 0.817    | 24.47 | 69.5  | 72.9       | 70.4       | 0.954       | 1.44                | 0.1%       |
| 4096      | 0.812    | 24.64 | 70.0  | 59.2       | 71.6       | 1.182       | 1.43                | 0.1%       |
| 8192      | 0.805    | 24.84 | 70.6  | 59.6       | 72.1       | 1.184       | 1.42                | 0.2%       |
| 16384     | 0.801    | **24.96** | **70.9** | 58.9  | 72.2       | 1.204       | 1.41                | 0.1%       |

- Surprise: Stage B made the kernel slower. At leaf_size=1024, 70.5% TPP
  against DCQ4's 82.1% (0.858x) and below DCQ3's 72.3%.
- DCQ5 is below DCQ4 at every leaf_size up to 2048 (by 5-17%) and below
  DCQ3 at every leaf_size (by 1-14%).
- From 4096 up DCQ5 is 18-20% faster than DCQ4 and does not show DCQ4's
  drop to ~59%; it sits ~1-2 points below DCQ3 there.
- DCQ5's curve is nearly flat from 512 to 16384 (68.9-70.9% TPP), with
  the best point at 16384 (70.9%).
- Rep spread <= 0.7% everywhere.
- The baseline run agrees with the sweep's 1024 point (0.8073 vs
  0.8061 s).
- Not known from this run: whether GCC merged the shared loads, how many
  registers it used or whether it spilled, and whether the 2 chains are
  interleaved (assembly); loads and stall shares (counters).

Plot: `04-DCQ5/plots/2026.11.01.001.LeafSizeSweep100000x100000.xlsx`.

#### Conclusion

(To be stated by the student.)

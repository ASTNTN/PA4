# PA3 Record

Machine: E-cores 16-31, TPP = 35.2 GFLOPs/s per core (`--tpp-per-core 35.2`).
Binding: `_gate.sh` defaults (sequential runs pinned to core 16).

## 03-BKQ: Blocked OPQ (Part A, single core)

### BKQ.1: Basic 4-loop blocking

#### Introduction

PA3 Part A asks for a blocked version of OPQ, optimized on a single core.
Before any fine-grained optimization, we need a plain blocked kernel as a
baseline: does tiling OPQ's (i, j) loop nest by itself change single-core
performance, and how does performance depend on the block size? In PA2,
OPQ reached ~37% TPP at 1000x4000 and 8000x2000, limited by loads (2 loads +
1 store per vector FMA, load-buffer stalls ~1/3 of cycles; notes.md).

#### Hypothesis

BKQ performs about the same as OPQ (~37% TPP at these sizes), since the
inner loop, and so the number of loads and stores per FMA, is unchanged.
Small blocks lose some performance to loop overhead and the 4-wide/scalar
remainder loops.

#### Design

Tile both i and j of OPQ into square `bs x bs` blocks, 4-loop structure
(`ii`, `jj`, `i`, `j`). Edge blocks left incomplete: inner bounds are
`min(ii+bs, dA+1)` and `min(jj+bs, dB+1)`. Inner body unchanged from OPQ
(`BPM_ACC(c, comp, i + j, a[i] * b[j])`). Block size is a runtime knob,
`--tune block_size=N`, fallback 64 when absent.

#### Implementation

`03-BKQ/src/PolyMult.c`. Gate (`03-BKQ/run.sh`) PASSED: oracle 42/42,
gold 14/14.

Vectorization (`gcc -O3 -march=native -ffast-math -fopt-info-vec-all`):
inner `j` loop vectorized 8-wide (`vbroadcastss` + `vfmadd213ps ymm`), with
4-wide and scalar epilogues; the three outer loops are not vectorized. Same
hot loop as OPQ: 2 loads + 1 store per 8-lane FMA.

#### Experiment

Block-size sweep, 1 thread, 5 reps, at the two PA2 sizes:

```
./sweep.sh --variant-dir 03-BKQ --dA 1000 --dB 4000 --threads 1 --reps 5 \
    --tune block_size=16,24,32,48,64,96,128,192,256,384,512,1024 \
    --name 2026.10.18.001_bs_sweep_1000x4000
./sweep.sh --variant-dir 03-BKQ --dA 8000 --dB 2000 --threads 1 --reps 5 \
    --tune block_size=16,24,32,48,64,96,128,192,256,384,512,1024 \
    --name 2026.10.18.002_bs_sweep_8000x2000
```

#### Results

Median of 5, GFLOPs/s (% TPP):

| block_size | 1000x4000     | 8000x2000     |
|-----------:|---------------|---------------|
| 16         | 2.70 (7.7%)   | 2.70 (7.7%)   |
| 24         | 3.95 (11.2%)  | 3.94 (11.2%)  |
| 32         | 5.19 (14.7%)  | 5.16 (14.7%)  |
| 48         | 7.52 (21.4%)  | 7.53 (21.4%)  |
| 64         | 9.04 (25.7%)  | 8.90 (25.3%)  |
| 96         | 11.99 (34.1%) | 12.05 (34.2%) |
| 128        | 12.51 (35.5%) | 12.62 (35.9%) |
| 192        | 12.87 (36.6%) | 12.89 (36.6%) |
| 256        | 13.03 (37.0%) | 13.09 (37.2%) |
| 384        | 13.22 (37.6%) | 13.12 (37.3%) |
| 512        | 13.10 (37.2%) | 13.31 (37.8%) |
| 1024       | 12.70 (36.1%) | 12.71 (36.1%) |

OPQ reference (notes.md, OPP2): 12.73 (36.2%) at 1000x4000, 13.04 (37.0%)
at 8000x2000.

- Large blocks (192-512) match OPQ, at most ~2-4% above it.
- Small blocks are far worse than expected: bs=16 runs at about 1/5 of OPQ,
  and performance climbs roughly in proportion to bs up to ~96.
- The small-block numbers are nearly identical at both problem sizes.
- Reps are tight (within ~1-2%), except bs=512 at 1000x4000, where reps 1-2
  were ~10% slower than reps 3-5.
- Every block size tested is a multiple of 8, so the 4-wide/scalar remainder
  path was never exercised at a block boundary; that part of the hypothesis
  is untested.

Plots (made with the project venv, `.venv/bin/python plot.py ...
--tpp-per-core 35.2`; system Python lacks `xlsxwriter`):

- `03-BKQ/plots/2026.10.18.001.BlockSizeSweep1000x4000.xlsx`
- `03-BKQ/plots/2026.10.18.002.BlockSizeSweep8000x2000.xlsx`

#### Conclusion

Large-block hypothesis confirmed: plain blocking doesn't change single-core
performance, consistent with the per-FMA load/store limit being unchanged.
The small-block penalty is much larger than "some loop overhead" and is not
yet explained.

## 03-BKQ2: BKQ + unroll-and-jam (Part A, single core)

### BKQ2.1: R = 8 unroll-and-jam inside each block

#### Introduction

BKQ.1 showed that blocking alone leaves single-core performance at OPQ's
~37% TPP: the inner loop still does 2 loads and 1 store per vector FMA, and
an E-core can start only one 256-bit load per cycle. PA2-report-Nick.html
(Experiment 6, step 1) cut loads per FMA with unroll-and-jam: handle R rows
together so that each vector of c is loaded and stored once per R FMAs
instead of once per FMA. Here we apply that inside each BKQ block.

#### Hypothesis

With R = 8, loads per FMA fall from 2 to 9/8, and BKQ2 rises well above
BKQ's ~37% TPP, to ~55-60% (Nick: 57.7% at this step). The compiler's
`-ffast-math` regrouping (seen in the assembly: 12 FP ops per 8 FMAs of
work) holds it under 67%. Small blocks still suffer, since the fused loop
covers only bs - 7 of each row and the rest runs as plain rows.

#### Design

Trick 1 from PA2-report-Nick.html (Experiment 6, step 1). BKQ's 4-loop
tiling, square blocks, edge blocks incomplete, `--tune block_size`, fallback
64. Inside a block, rows are taken R = 8 at a time and their j loops are
fused into one loop over t: row r of the group uses j = t - r, so all 8 rows
add into the same `c[i0 + t]`:

```
for (t = jj + 7; t < jend; t++) {
    BPM_ACC(c, comp, i0 + t, a0 * b[t]);
    BPM_ACC(c, comp, i0 + t, a1 * b[t - 1]);
    ...
    BPM_ACC(c, comp, i0 + t, a7 * b[t - 7]);
}
```

The 8 values of a are hoisted into locals. Row r's ragged ends
(`j < jj + 7 - r` and `j >= jend - r`), blocks narrower than 8, and leftover
rows when the block height isn't a multiple of 8 run as plain OPQ rows. R is
fixed at 8 (not a knob). Goal: cut loads per FMA from 2 to 9/8.

#### Implementation

`03-BKQ2/` (copied from `03-BKQ`, variant name `BKQ2`; kernel in
`src/PolyMult.c`). Gate PASSED: oracle 42/42, gold 14/14 (both binaries).

Vectorization (`-fopt-info-vec`): the fused loop and all remainder loops are
vectorized 8-wide. Fused-loop assembly, per 8 outputs:

```
vmulps (%r11,%rax,1),%ymm14,%ymm1
vmulps (%r8,%rax,1),%ymm12,%ymm0
vfmadd231ps (%r14,%rax,1),%ymm15,%ymm1
vfmadd231ps (%r9,%rax,1),%ymm13,%ymm0
vaddps %ymm0,%ymm1,%ymm1
vmulps (%rsi,%rax,1),%ymm10,%ymm0
vfmadd231ps (%rdi,%rax,1),%ymm11,%ymm0
vaddps (%rdx,%rax,1),%ymm0,%ymm0      ; + c (one load)
vaddps %ymm1,%ymm0,%ymm0
vmulps (%rbx,%rax,1),%ymm8,%ymm1
vfmadd231ps (%rcx,%rax,1),%ymm9,%ymm1
vaddps %ymm0,%ymm1,%ymm0
vmovups %ymm0,(%rdx,%rax,1)           ; store c (one store)
```

- c is loaded once and stored once per 8 rows; 8 loads of b: 9 loads +
  1 store per 8 FMAs (was 16 + 8).
- `-ffast-math` regrouped the 8 products into pairs: 4 mul + 4 FMA + 4 add =
  12 FP ops for 8 FMAs of work, which caps this loop at 8/12 = 67% TPP.
  Same as Nick's step 1; not addressed in this step.

#### Experiment

Block-size sweep, 1 thread, 5 reps, same sizes as BKQ.1; bs=100 added as the
first size that is not a multiple of 8, to exercise the remainder paths:

```
BS=64,96,100,128,192,256,384,512,768,1024
./sweep.sh --variant-dir 03-BKQ2 --dA 1000 --dB 4000 --threads 1 --reps 5 \
    --tune block_size=$BS --name 2026.10.18.001_bs_sweep_1000x4000
./sweep.sh --variant-dir 03-BKQ2 --dA 8000 --dB 2000 --threads 1 --reps 5 \
    --tune block_size=$BS --name 2026.10.18.002_bs_sweep_8000x2000
```

#### Results

Median of 5, GFLOPs/s (% TPP); BKQ (BKQ.1) for comparison:

| block_size | BKQ2 1000x4000 | BKQ2 8000x2000 | BKQ 8000x2000 |
|-----------:|----------------|----------------|---------------|
| 64         | 7.84 (22.3%)   | 7.74 (22.0%)   | 8.90 (25.3%)  |
| 96         | 9.75 (27.7%)   | 9.85 (28.0%)   | 12.05 (34.2%) |
| 100        | 10.11 (28.7%)  | 10.38 (29.5%)  | -             |
| 128        | 10.03 (28.5%)* | 11.19 (31.8%)  | 12.62 (35.9%) |
| 192        | 12.97 (36.8%)* | 13.06 (37.1%)  | 12.89 (36.6%) |
| 256        | 12.84 (36.5%)* | 14.47 (41.1%)  | 13.09 (37.2%) |
| 384        | 13.04 (37.1%)* | 15.82 (44.9%)  | 13.12 (37.3%) |
| 512        | 11.26 (32.0%)* | 17.33 (49.2%)  | 13.31 (37.8%) |
| 768        | 12.83 (36.5%)* | 17.57 (49.9%)  | -             |
| 1024       | 12.78 (36.3%)  | 18.96 (53.9%)  | 12.71 (36.1%) |

\* reps spread -12% to +21% around the median.

- 8000x2000: reps tight (within ~2-4%). Rises steadily with block size, to
  53.9% at 1024, 1.49x BKQ's best; no plateau reached within the range
  tested.
- Below bs=192, BKQ2 is slower than BKQ (64: 22% vs 25%; 96: 28% vs 34%).
- bs=100 (not a multiple of 8) sits on the trend between 96 and 128.
- 1000x4000: bs=128-768 are unreliable. Within each of those block sizes the
  5 reps get steadily faster (e.g. bs=384: 0.710, 0.681, 0.614, 0.597,
  0.542 ms; the last rep is 18.6 GFLOPs/s, 53% TPP). During the run another
  user's rsync was active (load average ~2.6). Not established as the cause.
  bs=64-100 at this size were tight and match 8000x2000.

Plots:

- `03-BKQ2/plots/2026.10.18.001.BlockSizeSweep1000x4000.xlsx`
- `03-BKQ2/plots/2026.10.18.002.BlockSizeSweep8000x2000.xlsx`

#### Conclusion

At 8000x2000 the hypothesis is supported in direction (54% vs 37%), within
the predicted 55-60% at the largest block tested and under the 67% cap. The
peak block size is not yet bracketed (best is the largest tested). The
1000x4000 medians above 100 are not trustworthy and need a re-run.

### BKQ2.1 (continued): large problem sizes, BKQ2 and BKQ

#### Introduction

The small sizes used so far run in about a millisecond per rep, which made
the 1000x4000 BKQ2 sweep sensitive to disturbances, and they don't reach the
regime where OPQ's rows overflow L1. At large sizes OPQ falls to ~27% TPP
(100K x 100K: 26.8% in PA2-report-Nick.html; 160K x 160K: 26.5% in
notes.md), which is where blocking should matter. BKQ2's best block size
was also still the largest tested. So both BKQ2 and BKQ are swept over
square sizes from 20000x20000 to 100000x100000, with block sizes extended
upward to 4096.

#### Hypothesis

Blocking keeps each tile's working set in L1 regardless of problem size, so
BKQ2 holds ~50-55% TPP at every size, and BKQ stays at its ~37% plateau
(above OPQ's ~27% at these sizes). Best block ~1024-2048: a tile touches
~bs floats of b and ~2*bs of c, ~12*bs bytes, so it should outgrow the
32 KB L1 near bs ~2,700 and drop at 3072/4096.

#### Experiment

BKQ2 first, then BKQ as a comparison at the same sizes and block sizes:

```
BS=256,512,768,1024,1536,2048,3072,4096; n=3
for N in 20000 40000 60000 80000 100000; do
  ./sweep.sh --variant-dir 03-BKQ2 --dA $N --dB $N --threads 1 --reps 7 \
      --tune block_size=$BS --name 2026.10.18.00${n}_bs_sweep_${N}x${N}
  n=$((n+1))
done
# then the same loop with --variant-dir 03-BKQ (also .003-.007)
```

All BKQ2 sweeps first, then all BKQ sweeps, one at a time. Another user's
rsync was active throughout (~6% CPU); at the end it had migrated onto core
16, our pinned core. Rep spread: every configuration within ~0.5% of its
median except one rep (+3%, BKQ2 80000, bs=256), so no visible effect.

#### Results

Median of 7, GFLOPs/s (% TPP). 40K-100K agree to within ~0.1 GFLOPs/s;
20K is up to 0.9 lower for BKQ2 and 0.3 lower for BKQ at bs=4096.
100000x100000 shown:

| block_size | BKQ           | BKQ2          | BKQ2 / BKQ |
|-----------:|---------------|---------------|-----------:|
| 256        | 13.1 (37.2%)  | 14.5 (41.2%)  | 1.11       |
| 512        | 13.4 (38.0%)  | 17.1 (48.6%)  | 1.28       |
| 768        | 12.6 (35.8%)  | 17.7 (50.3%)  | 1.40       |
| 1024       | 12.8 (36.4%)  | 18.8 (53.4%)  | 1.47       |
| 1536       | 13.0 (36.9%)  | 19.1 (54.3%)  | 1.47       |
| 2048       | 13.1 (37.2%)  | 19.6 (55.7%)  | 1.50       |
| 3072       | 13.2 (37.5%)  | 19.9 (56.5%)  | 1.51       |
| 4096       | 12.8 (36.4%)  | 20.0 (56.8%)  | 1.56       |

- Both variants are independent of problem size from 20K to 100K
  (BKQ2 at 20K is ~0.3-1 GFLOPs/s lower at bs >= 512).
- BKQ: flat at 36-38% for every block size, the same as its small-size
  plateau. OPQ at comparable sizes was ~27% (other measurements, see
  hypothesis), so blocking alone is worth ~1.4x at large sizes.
- BKQ2: rises with block size all the way to 4096 (56.8%), flattening
  (2048 -> 4096 adds ~1 point). No drop at 3072 or 4096.

Plots: `03-BKQ/plots/2026.10.18.00{3..7}.BlockSizeSweep<N>x<N>.xlsx`,
`03-BKQ2/plots/2026.10.18.00{3..7}.BlockSizeSweep<N>x<N>.xlsx`.

#### Conclusion

Size independence supported for both variants. BKQ2 reaches 56.8% TPP,
within the 55-60% predicted for trick 1 alone, under the 67% regrouping cap.
The predicted drop above bs ~2,700 did not happen: the L1-footprint
estimate is wrong, or exceeding L1 at these sizes costs little (not
measured). The best block size is still not bracketed.

## 03-BKQ3: BKQ2 + FMA chain kept (Part A, single core)

### BKQ3.1: no-associative-math on the kernel

#### Introduction

BKQ2's assembly showed that `-ffast-math` lets GCC regroup the 8 products of
the fused loop into pairs: 4 multiplies + 4 FMAs + 4 adds, 12 FP
instructions for 8 FMAs of work. Since the core issues one 256-bit FP
operation per cycle, that caps the loop at 8/12 = 67% TPP. BKQ2 reached
56.8%. Nick's Experiment 6, step 2, restored the single chain of 8 FMAs by
disabling reassociation on the kernel function only.

#### Hypothesis

With the 12-op cap gone, BKQ3 beats BKQ2's 56.8% and levels off around
60-67% TPP. All 8 FMAs for one vector of c then form one dependent chain
(6-cycle FMA latency), which becomes the next limit (Nick: 57.7% -> 67.0% at
this step). Well above 67% would mean latency isn't the limit; no gain over
BKQ2 would mean the regrouping wasn't the constraint.

#### Design

Trick 2 from PA2-report-Nick.html (Experiment 6, step 2). BKQ2's code
unchanged except `__attribute__((optimize("no-associative-math")))` on
`kernel_multiply`, so `-ffast-math` (timed build) can no longer regroup the 8
products into pairs. Only this function is affected; the rest of the build
keeps `-ffast-math`. Goal: remove BKQ2's 12-op / 67% cap.

#### Implementation

`03-BKQ3/` (copied from `03-BKQ2`, variant name `BKQ3`; kernel in
`src/PolyMult.c`). Gate PASSED: oracle 42/42, gold 14/14 (both binaries).
All loops still vectorized 8-wide. Fused-loop assembly, per 8 outputs:

```
vmovups     (%r14,%rax,1),%ymm0         ; b window, row 0
vfmadd213ps (%rdx,%rax,1),%ymm15,%ymm0  ; * a0, + c (one load)
vfmadd231ps (%r11,%rax,1),%ymm14,%ymm0  ; + a1 * b window, row 1
vfmadd231ps (%r9,%rax,1),%ymm13,%ymm0
vfmadd231ps (%r8,%rax,1),%ymm12,%ymm0
vfmadd231ps (%rdi,%rax,1),%ymm11,%ymm0
vfmadd231ps (%rsi,%rax,1),%ymm10,%ymm0
vfmadd231ps (%rcx,%rax,1),%ymm9,%ymm0
vfmadd231ps (%rbx,%rax,1),%ymm8,%ymm0   ; + a7 * b window, row 7
vmovups     %ymm0,(%rdx,%rax,1)         ; store c (one store)
```

8 FMAs, 9 loads, 1 store per 8 outputs (BKQ2: 4 mul + 4 FMA + 4 add). All 8
FMAs write ymm0: one dependent chain per vector of c.

#### Experiment

Same setup as the BKQ/BKQ2 large-size set:

```
BS=256,512,768,1024,1536,2048,3072,4096; n=1
for N in 20000 40000 60000 80000 100000; do
  ./sweep.sh --variant-dir 03-BKQ3 --dA $N --dB $N --threads 1 --reps 7 \
      --tune block_size=$BS --name 2026.10.18.00${n}_bs_sweep_${N}x${N}
  n=$((n+1))
done
```

The other user's rsync was still active (cores 20-23 before, 11-12 after; not
seen on core 16). Every rep within 0.3% of its median.

#### Results

Median of 7, GFLOPs/s (% TPP), 100000x100000; 40K-100K agree within ~0.1
GFLOPs/s, 20K is up to 0.5 lower:

| block_size | BKQ2          | BKQ3          | BKQ3 / BKQ2 |
|-----------:|---------------|---------------|------------:|
| 256        | 14.5 (41.2%)  | 15.2 (43.1%)  | 1.04        |
| 512        | 17.1 (48.6%)  | 17.9 (50.8%)  | 1.05        |
| 768        | 17.7 (50.3%)  | 18.6 (52.7%)  | 1.05        |
| 1024       | 18.8 (53.4%)  | 19.7 (55.8%)  | 1.04        |
| 1536       | 19.1 (54.3%)  | 20.0 (56.8%)  | 1.05        |
| 2048       | 19.6 (55.7%)  | 20.5 (58.2%)  | 1.05        |
| 3072       | 19.9 (56.5%)  | 20.8 (59.1%)  | 1.04        |
| 4096       | 20.0 (56.8%)  | 20.8 (59.1%)  | 1.04        |

- BKQ3 is 4-6% faster than BKQ2 at every block size and size; best 59.1%.
- Curve has the same shape as BKQ2's; 3072 and 4096 are now equal (flat).

Plots: `03-BKQ3/plots/2026.10.18.00{1..5}.BlockSizeSweep<N>x<N>.xlsx`.

#### Conclusion

Partly supported: keeping the FMA chain helps, but by ~5%, not the ~16% Nick
saw at this step, and the result (59.1%) is just under the predicted 60-67%.
BKQ2 at 56.8% was already below its 67% cap, so the regrouping was not the
main limit. Something else holds BKQ3 near 59%; candidates (unmeasured): the
FMA latency chain, split loads of the unaligned b windows, load-buffer
pressure.

### BKQ3.2: perf profile of BKQ3

#### Introduction

BKQ3 gained only ~5% over BKQ2 (59.1% TPP), far less than Nick's ~16% at the
same step, so the limit we expected after removing the regrouping may not
be the real one. Nick's next two tricks target different limits: trick 3
(interleaved accumulators) the FMA latency chain, trick 4 (aligned copies
of b) split loads. Rather than guess, measure which limit actually holds
BKQ3 back. Measurement only, no code change.

#### Hypothesis

(Not stated explicitly before the run; reconstructed from BKQ3.1's
hypothesis.) BKQ3.1 predicted the FMA latency chain as the next limit. If
so, the FP (non-memory) scheduler should be full for a large share of
pipeline slots, as Nick saw (41%). If instead the backend stall is in the
memory scheduler / load buffer, or split loads are frequent, the limit is
load-side. L1 misses should be negligible, since BKQ2/BKQ3 showed no drop
at large block sizes.

#### Design

Candidates and the counters that test them: FMA latency chain
(`topdown_be_bound.non_mem_scheduler`), split loads of the unaligned b
windows (`mem_uops_retired.split_loads`), load/store-buffer pressure
(`mem_scheduler_block.*`, `topdown_be_bound.mem_scheduler`), L1 misses
(`mem_load_uops_retired.l1_hit/l1_miss`), plus top-down level 1 and
cycles/instructions/µops for context.

#### Experiment

BKQ3 timing binary, 100000x100000, bs=3072, 3 reps, core 16. Four separate
`perf stat` runs, one at a time, each group small enough to count 100% of
the time (no multiplexing):

```
P="./bin/PolyMult.time -dA 100000 -dB 100000 -t 1 -r 3 --tune block_size=3072"
taskset -c 16 perf stat -e cpu_atom/cycles/,cpu_atom/instructions/,cpu_atom/uops_issued.any/,cpu_atom/topdown_be_bound.all/,cpu_atom/topdown_be_bound.mem_scheduler/,cpu_atom/topdown_be_bound.non_mem_scheduler/ $P
taskset -c 16 perf stat -e cpu_atom/mem_uops_retired.all_loads/,cpu_atom/mem_uops_retired.all_stores/,cpu_atom/mem_uops_retired.split_loads/,cpu_atom/mem_load_uops_retired.l1_hit/,cpu_atom/mem_load_uops_retired.l1_miss/ $P
taskset -c 16 perf stat -e cpu_atom/mem_scheduler_block.all/,cpu_atom/mem_scheduler_block.ld_buf/,cpu_atom/mem_scheduler_block.st_buf/,cpu_atom/mem_scheduler_block.rsv/,cpu_atom/topdown_be_bound.register/,cpu_atom/topdown_be_bound.reorder_buffer/ $P
taskset -c 16 perf stat -e cpu_atom/topdown-retiring/,cpu_atom/topdown-fe-bound/,cpu_atom/topdown-be-bound/,cpu_atom/topdown-bad-spec/,cpu_atom/topdown_be_bound.alloc_restrictions/,cpu_atom/topdown_be_bound.serialization/ $P
```

Timing during profiling: 20.78-20.80 GFLOPs/s, same as the sweep.

#### Results

Whole-process counts (kernel is ~2.89 s of ~2.89 s). Normalized per vector
FMA = 3 x 100001^2 / 8 = 3.75e9; slots = 5 x cycles.

| per vector FMA            | value |
|---------------------------|-------|
| cycles (1.0 = TPP)        | 1.687 |
| instructions              | 1.849 |
| µops issued               | 3.104 |
| load µops                 | 2.303 |
| store µops                | 0.266 |
| split loads               | 0.438 (19.0% of load µops) |
| L1 load misses            | 0.002 (0.099% of loads) |
| load-buffer-full cycles   | 0.478 (28.4% of cycles) |

| % of pipeline slots                     |       |
|-----------------------------------------|-------|
| Retiring                                | 36.8% |
| Backend bound                           | 62.0% |
| - memory scheduler full                 | 59.3% |
| - non-memory (FP) scheduler full        | 0.01% |
| - reorder buffer full                   | 2.4%  |
| - register / alloc restrictions         | 0.2%  |
| Frontend bound                          | 0.8%  |
| Bad speculation                         | 0.5%  |

mem_scheduler_block: ld_buf 1.794e9 cycles of 1.794e9 total; st_buf 0.23e6,
rsv 0.06e6.

- 1.687 cycles per FMA matches the measured 59.1% TPP (1/1.687 = 59.3%).
- Load µops per FMA = 2.30, exactly 9 256-bit loads per 8 FMAs (2 µops
  each), as designed.
- FP scheduler is essentially never full: the FMA latency chain is not
  the limit here (Nick saw it full 41% of slots at this step).
- L1 misses are negligible even at bs=3072, consistent with no drop at
  3072/4096 in the sweeps.
- Nearly all backend stall is the memory scheduler, and all of that is the
  load buffer being full.
- 0.438 split loads per FMA, ~19% of load µops.

#### Conclusion

BKQ3 is load-side bound: the load buffer is full and ~1 in 5 load µops is a
cache-line split. Not latency bound, not cache-miss bound. This points at
the split loads (Nick's trick 4, aligned copies of b) rather than at
interleaved accumulators (trick 3).

## 03-BKQ4: BKQ3 + aligned copies of b (Part A, single core)

### BKQ4.1: four shifted, 64-byte-aligned copies of b

#### Introduction

BKQ3.2's profile showed BKQ3 is load-side bound: the load buffer is full
28.4% of cycles, the FP scheduler is essentially never full (so the FMA
latency chain is not the limit), and 0.438 split loads per vector FMA, ~19%
of load µops, straddle a cache line. The 8 rows of the fused loop read b
starting one float apart, so their windows can't all be aligned in one copy
of b. Nick's Experiment 6 used four shifted copies of b so every row can
read from 16-byte-aligned addresses (trick 4), which removed his split
loads.

#### Hypothesis

With the copies, split loads of b fall from ~0.44 per vector FMA to near
zero (loads of c, 1 per 8 FMAs, are not aligned and may still split), and
BKQ4 rises above BKQ3's 59.1% TPP. The copies add footprint: a tile now
reads b windows from up to 4 copies, so the best block size may move down
from 3072-4096. (Earlier footprint estimates overpredicted L1 overflow, so
the exact block size is left to measurement.)

#### Design

BKQ3 unchanged except:

- Once per call, before the tile loops, build 4 copies of b: copy s is b
  shifted right by s floats on a 64-byte-aligned base,
  `bc[s][x + s] = b[x]` (`aligned_alloc(64, ...)`, 4 x (dB + 4) floats,
  freed at the end). This setup is inside the timed kernel.
- For each block, the fused loop starts at t0 = jj + 7 and steps 8 floats.
  Row r reads b[t - r] = bc[s][t - r + s], with s chosen per row so that
  (t0 - r + s) % 4 == 0: every load of row r starts on a 16-byte boundary.
  Rows r and r + 4 use the same copy.
- Only the fused loop reads the copies; ragged-end and leftover-row loops
  read b directly. c loads/stores are not aligned.
- `no-associative-math` attribute kept from BKQ3.

#### Implementation

`03-BKQ4/` (copied from `03-BKQ3`, variant name `BKQ4`; kernel in
`src/PolyMult.c`). Gate PASSED: oracle 42/42, gold 14/14 (both binaries).

Fused loop vectorized 8-wide; no alignment peeling reported by
`-fopt-info-vec-all`, so the vector loop starts at t0 as the copy selection
assumes. Hot loop has the same shape as BKQ3's (1 vmovups of b, 8 FMAs with
memory operands, 1 store of c), now reading from the copies:

```
vmovups     (%rsi,%rax,1),%ymm0
vfmadd213ps (%rdx,%rax,1),%ymm8,%ymm0   ; + c
vfmadd231ps (%rdi,%rax,1),%ymm7,%ymm0
... 5 more vfmadd231ps ...
vfmadd231ps (%r15,%rax,1),%ymm1,%ymm0
vmovups     %ymm0,(%rdx,%rax,1)
```

Whether the loads are actually aligned at run time is not visible in the
assembly (vmovups is used either way); the split-load counter will show it.

#### Experiment

Same setup as BKQ3.1, for direct comparison:

```
BS=256,512,768,1024,1536,2048,3072,4096; n=1
for N in 20000 40000 60000 80000 100000; do
  ./sweep.sh --variant-dir 03-BKQ4 --dA $N --dB $N --threads 1 --reps 7 \
      --tune block_size=$BS --name 2026.10.18.00${n}_bs_sweep_${N}x${N}
  n=$((n+1))
done
```

The other user's rsync was still active (cores 20-23, not seen on core 16).
Reps within ~1-2% of the median except one rep at 20K, bs=256 (+11%).

#### Results

Median of 7, % TPP (BKQ4 / BKQ3 at the same size and block size):

| block_size | 20K           | 40K           | 60K           | 80K           | 100K          |
|-----------:|---------------|---------------|---------------|---------------|---------------|
| 256        | 45.8% (1.08)  | 45.1% (1.05)  | 45.2% (1.05)  | 45.4% (1.06)  | 45.2% (1.05)  |
| 512        | 54.9% (1.10)  | 53.8% (1.06)  | 53.9% (1.06)  | 53.9% (1.06)  | 53.9% (1.06)  |
| 768        | 57.1% (1.10)  | 57.1% (1.08)  | 57.2% (1.09)  | 57.3% (1.09)  | 57.2% (1.08)  |
| 1024       | 59.6% (1.10)  | 58.3% (1.05)  | 59.0% (1.06)  | 59.0% (1.06)  | 58.9% (1.06)  |
| 1536       | 61.1% (1.09)  | 59.1% (1.04)  | 61.0% (1.07)  | 60.6% (1.07)  | 60.3% (1.06)  |
| 2048       | 59.9% (1.04)  | 59.9% (1.03)  | 59.3% (1.02)  | 59.4% (1.02)  | 53.8% (0.92)  |
| 3072       | 61.5% (1.05)  | 61.6% (1.04)  | 61.3% (1.04)  | 61.3% (1.04)  | 55.3% (0.94)  |
| 4096       | 62.3% (1.06)  | 62.8% (1.06)  | 62.2% (1.05)  | 62.2% (1.05)  | 55.9% (0.95)  |

- Best: 62.8% TPP (22.1 GFLOPs/s), 40K, bs=4096; 62.2-62.8% at bs=4096 for
  20K-80K.
- 20K-80K: BKQ4 is 2-10% faster than BKQ3 at every block size.
- 100K: same as the other sizes up to bs=1536 (60.3%), but at bs >= 2048
  it drops to 54-56%, below BKQ3 (0.92-0.95x). Reps at those points are
  tight (within 0.2%), so this is not noise. Not explained.
- bs=2048 dips below both 1536 and 3072 at every size (~1-2 points).
- The curve no longer flattens at 3072-4096 for 20K-80K (still rising).

Plots: `03-BKQ4/plots/2026.10.18.00{1..5}.BlockSizeSweep<N>x<N>.xlsx`.

#### Conclusion

Partly supported. BKQ4 beats BKQ3's 59.1% at 20K-80K, reaching 62.8%, but
the gain (~5%) is small for removing what BKQ3.2 measured as ~19% of load
µops being splits; whether the splits are actually gone is not yet
measured. At 100K with bs >= 2048, BKQ4 is slower than BKQ3: something
about that combination (not seen at 80K) costs ~10%. The planned perf check
should measure split loads and L1 misses, comparing 100K against 80K at a
large block size.

### BKQ4.2: perf profile of BKQ4

#### Introduction

BKQ4.1 gained only ~5% over BKQ3 at 20K-80K, and at 100K with bs >= 2048 it
was ~5-8% slower than BKQ3. We need to know whether the aligned copies
actually removed the split loads, and what differs at 100K.

#### Hypothesis

Split loads per vector FMA fall from BKQ3's 0.438 to near zero. The 100K
large-block drop shows up as a counter that differs from 80K at the same
block size; L1 misses are the likeliest candidate, since the copies
multiply b's footprint.

#### Design

Same four counter groups as BKQ3.2 (100% counted, no multiplexing), BKQ4
timing binary, 3 reps, core 16, one run at a time, three configurations:
100K bs=3072 (direct comparison with BKQ3.2), 80K bs=3072 (same block,
unaffected size), 100K bs=1536 (100K's best block, before the drop).

#### Experiment

```
for cfg in "100000 3072" "80000 3072" "100000 1536"; do
  set -- $cfg
  P="./bin/PolyMult.time -dA $1 -dB $1 -t 1 -r 3 --tune block_size=$2"
  # the four `taskset -c 16 perf stat -e ...` groups from BKQ3.2, on $P
done
```

Timing during profiling matched the sweeps (100K/3072: 19.4-19.5,
80K/3072: 21.5-21.6, 100K/1536: 21.0-21.3 GFLOPs/s). The other user's
rsync was on core 6.

#### Results

Per vector FMA = 3 x (N+1)^2 / 8; slots = 5 x cycles. BKQ3 from BKQ3.2.

|                          | BKQ3 100K/3072 | BKQ4 100K/3072 | BKQ4 80K/3072 | BKQ4 100K/1536 |
|--------------------------|---------------:|---------------:|--------------:|---------------:|
| cycles / FMA             | 1.687          | 1.806          | 1.627         | 1.654          |
| instructions / FMA       | 1.849          | 1.856          | 1.862         | 2.083          |
| load µops / FMA          | 2.303          | 2.311          | 2.313         | 2.372          |
| split loads / FMA        | 0.438          | 0.064          | 0.064         | 0.065          |
| L1 misses, % of loads    | 0.10%          | 29.9%          | 9.6%          | 9.3%           |
| load buffer full, % cyc  | 28.4%          | 23.8%          | 15.9%         | 12.9%          |
| Retiring, % slots        | 36.7%          | 34.4%          | 38.3%         | 40.3%          |
| Backend bound, % slots   | 62.0%          | 63.1%          | 59.3%         | 55.4%          |
| - memory scheduler full  | 59.3%          | 61.5%          | 29.4%         | 23.9%          |
| - FP scheduler full      | 0.0%           | 1.0%           | 28.8%         | 30.4%          |
| Frontend bound, % slots  | 0.8%           | 1.7%           | 1.7%          | 3.0%           |

- Split loads fell 85%, 0.438 -> 0.064 per FMA, in all three configurations.
  The remainder is consistent with the unaligned c loads (not verified).
- L1 misses appeared: 0.1% in BKQ3 -> ~9-10% in BKQ4 at 80K/3072 and
  100K/1536, and ~30% at 100K/3072.
- 100K/3072 vs 80K/3072, same block size: 3x the L1 miss rate, memory
  scheduler full 61.5% vs 29.4%. This matches the 100K drop in BKQ4.1.
- Where misses are ~10%, the stall splits roughly evenly between the memory
  scheduler and the FP scheduler (~24-29% and ~29-30% of slots). The FP
  scheduler being full is new: in BKQ3 it was 0%.
- 100K/1536 retires ~12% more instructions per FMA than the 3072 runs
  (smaller blocks: more ragged-edge work).

#### Conclusion

Supported: the copies removed ~85% of split loads, and the extra footprint
of the copies caused L1 misses. Why 100K/3072 misses 3x more than 80K/3072
with the same block size is not explained. The copies are spaced by
(dB + 4 rounded up to 16) floats, so their relative placement in L1 sets
changes with dB; L1 set conflicts between the copy windows and c are a
possible cause (not measured). With splits gone and misses moderate, the
FMA latency chain (FP scheduler full ~30%) now appears as a limit, as Nick
saw at his step 2.

### BKQ4.3: padding between the copies of b

#### Introduction

BKQ4.2 found that BKQ4's copies of b cause L1 misses (~10% of loads at
80K/3072 and 100K/1536) and that at 100K/3072 the miss rate is 3x that at
80K/3072 with the same block size (30% vs 10%), matching BKQ4.1's 100K
drop. The copies are placed back to back, (dB + 4 rounded up to 16) floats
apart, so their positions relative to each other in L1's sets change with
dB. If the copy windows collide in the same sets, moving the copies apart
should change the miss rate; if L1 is simply too small for the tile, it
shouldn't.

#### Hypothesis

At 100K/3072 the extra misses are set conflicts between the copies: some
padding values between the copies bring the miss rate down toward 80K's
~10% and the rate back up to ~61-62% TPP, while others keep it near 55%.
If time and miss rate don't change with padding, the misses are capacity
misses and the remedy is smaller blocks or fewer copies.

#### Design

Runtime knob `--tune copy_pad=N` in BKQ4: N floats of padding between
consecutive copies, rounded up to a multiple of 16 so each copy stays
64-byte aligned. Default 0 reproduces BKQ4.1 exactly. Only the copies'
addresses change; values read and loop structure are identical.

#### Implementation

`03-BKQ4/src/PolyMult.c` (in place; no new directory). Copy length becomes
`dB + 1 + 4 + pad` rounded up to 16 floats. Gate PASSED (oracle 42/42,
gold 14/14, both binaries); the gate runs the default copy_pad = 0 only
(the shared gate tune list has no copy_pad). Hot loop unchanged. Smoke
test at 2000x2000, bs=64, copy_pad = 0/16/1024: 7.53/7.47/7.50 GFLOPs/s,
and copy_pad appears as its own column in the raw output.

#### Experiment

Core 16's L1D (from `/sys/devices/system/cpu/cpu16/cache/index0`): 32 KB,
8-way, 64 sets, 64-byte lines, so set placement repeats every 4096 bytes.
(`reference/Procinfo1.md` lists "48 KB per core" for L1 data; that appears
to be the P-core figure.) 64 pads, one cache line apart, cover every
placement of the copies relative to each other mod 4096 bytes:

```
./sweep.sh --variant-dir 03-BKQ4 --dA 100000 --dB 100000 --threads 1 --reps 5 \
    --tune block_size=3072 --tune copy_pad=0:1008:16 \
    --name 2026.10.18.006_copy_pad_sweep_100000x100000
```

Then one perf run per pad at pad = 0 (default), 16 (typical), 336 (best),
864 (worst), 3 reps, core 16, adding `ld_blocks.address_alias` (on the
E-core: loads blocked by a 4K-alias check against an older store):

```
taskset -c 16 perf stat -e cpu_atom/cycles/,cpu_atom/mem_uops_retired.all_loads/,\
cpu_atom/mem_uops_retired.split_loads/,cpu_atom/mem_load_uops_retired.l1_hit/,\
cpu_atom/mem_load_uops_retired.l1_miss/,cpu_atom/ld_blocks.address_alias/,\
cpu_atom/mem_scheduler_block.ld_buf/ \
  ./bin/PolyMult.time -dA 100000 -dB 100000 -t 1 -r 3 --tune block_size=3072 --tune copy_pad=$pad
```

7 events: each was counted 85% of the time (multiplexed and scaled by
perf), unlike the 100%-counted groups of BKQ3.2/BKQ4.2.

#### Results

Sweep (median of 5, reps within 0.7%), "stride" = spacing between copies
mod 4096 bytes:

| copy_pad (floats)  | stride mod 4096   | % TPP         |
|--------------------|-------------------|---------------|
| 0 (default)        | 2752              | 55.2%         |
| 16-256, 400-640, 704-800, 880-992 (most pads) | various | 61.2-62.1% |
| 272, 656, 672, 816 | 3840, 1280, 1344, 1920 | 59.5-60.7% |
| 336                | 0                 | 63.1% (best, 22.22 GFLOPs/s) |
| 848                | 2048              | 62.4%         |
| 288-320            | 3904-4032         | 48.6-51.8%    |
| 352-384            | 64-192            | 47.1-53.6%    |
| 688                | 1408              | 52.8%         |
| 832, 864           | 1984, 2112        | 46.0%, 45.6% (worst) |
| 1008               | 2688              | 52.7%         |

Full table in the csv. Bad pads sit just next to, but not at, stride
mod 4096 = 0 and 2048 (and a few other phases); exactly 0 and 2048 are
among the best.

Perf, per vector FMA:

| copy_pad | GFLOPs/s | cycles | split loads | L1 misses (% loads) | address_alias | load buf full |
|---------:|---------:|-------:|------------:|--------------------:|--------------:|--------------:|
| 0        | 19.42    | 1.800  | 0.064       | 0.681 (29.4%)       | 0.670         | 23.9% cyc     |
| 16       | 21.59    | 1.618  | 0.064       | 0.214 (9.2%)        | 0.213         | 15.7% cyc     |
| 336      | 22.14    | 1.578  | 0.064       | 0.165 (7.1%)        | 0.182         | 12.7% cyc     |
| 864      | 16.00    | 2.183  | 0.064       | 1.301 (56.3%)       | 1.291         | 35.7% cyc     |

- Split loads are identical (0.064) at every pad: padding only moves the
  copies, as designed.
- L1 misses vary 8x with padding at the same block size, so most of
  BKQ4's "L1 misses" are not a capacity effect.
- Surprise: `ld_blocks.address_alias` equals the L1 miss count to within
  ~2% at pads 0, 16 and 864 (10% at 336). Two different events track each
  other almost exactly. From these counts alone I can't tell whether the
  loads are genuinely missing L1 (set conflicts), being blocked by 4K
  aliasing against the stores to c, or whether one event is counting the
  other.
- Cycles track these events closely: between the four pads, each extra
  event per FMA costs ~0.5 cycles (derived from the four points, not a
  fit).

Plot: `03-BKQ4/plots/2026.10.18.006.CopyPadSweep100000x100000.xlsx`.

#### Conclusion

Supported, with a caveat. Moving the copies changes the 100K/3072 rate from
45.6% to 63.1%; most pads give ~61.4%, matching the other problem sizes, and
the default (pad 0) happens to land on a bad placement. So the 100K drop in
BKQ4.1 is an address-placement effect, not L1 capacity. Whether the
mechanism is L1 set conflicts or 4K aliasing with the c stores is
unresolved: the two counters move together. Since the bad placements
depend on dB (the copy spacing is dB-dependent), a fixed pad would not fix
other sizes; the spacing would need to be chosen per call.

### BKQ4.4: padding sweep at other sizes

#### Introduction

BKQ4.3 showed that at 100K/3072 the rate depends strongly on where the
copies of b sit relative to each other (45.6% to 63.1%), but the copy
spacing is dB-dependent, and it is unresolved whether the bad placements
involve only the copies (L1 set conflicts) or also c (4K aliasing against
the c stores). Repeating the sweep at other sizes records how the bad
spacings move with dB.

#### Hypothesis

If the effect is purely between the copies, % TPP is a function of the
copy spacing mod 4096 bytes alone: the bad spacings sit at the same
spacing values at every size (and so at different copy_pad values). If c's
position matters, the bad spacings move with size.

#### Design

Same sweep as BKQ4.3 at 80000x80000 (default pad was fine there: 61.3%)
and 40000x40000. 64 pads one cache line apart, so each size covers every
spacing mod 4096. No code change.

#### Experiment

```
n=7
for N in 80000 40000; do
  ./sweep.sh --variant-dir 03-BKQ4 --dA $N --dB $N --threads 1 --reps 5 \
      --tune block_size=3072 --tune copy_pad=0:1008:16 \
      --name 2026.10.18.00${n}_copy_pad_sweep_${N}x${N}
  n=$((n+1))
done
```

Spacing for a given pad: `S = 4 * roundup16(N + 5 + roundup16(pad))`
bytes. Default (pad 0) spacing mod 4096: 100K 2752, 80K 576, 40K 320.

#### Results

Lined up by spacing mod 4096 (pads differ per size), % TPP, median of 5
(all reps within 2%):

| S mod 4096          | 100K   | 80K    | 40K    |
|---------------------|--------|--------|--------|
| 0                   | 63.1%  | 63.1%  | 63.1%  |
| 64                  | 47.1%  | 47.0%  | 46.9%  |
| 128                 | 50.9%  | 50.8%  | 50.7%  |
| 192                 | 53.6%  | 53.1%  | 53.4%  |
| 256-1216            | 61.3-62.1% | 61.2-61.9% | 61.0-61.8% |
| 1280                | 60.6%  | 60.5%  | 60.3%  |
| 1344                | 59.5%  | 59.5%  | 59.3%  |
| 1408                | 52.8%  | 52.7%  | 52.5%  |
| 1472-1856           | 61.3-61.6% | 61.2-61.4% | 61.1-61.3% |
| 1920                | 60.7%  | 60.5%  | 60.4%  |
| 1984                | 46.0%  | 45.9%  | 45.8%  |
| 2048                | 62.4%  | 62.4%  | 62.2%  |
| 2112                | 45.6%  | 45.4%  | 45.4%  |
| 2176-2624           | 61.3-61.7% | 61.2-61.7% | 61.0-61.5% |
| 2688                | 52.7%  | 52.7%  | 52.5%  |
| 2752                | 55.2%  | 55.1%  | 55.0%  |
| 2816-3776           | 61.2-61.9% | 61.2-61.8% | 61.0-61.7% |
| 3840                | 60.0%  | 60.0%  | 59.8%  |
| 3904                | 50.3%  | 50.2%  | 50.2%  |
| 3968                | 51.8%  | 51.7%  | 51.6%  |
| 4032                | 48.6%  | 48.3%  | 48.4%  |

- At every spacing, the three sizes agree to within ~0.3 points
  (40K runs ~0.2 lower throughout). The bad spacings do not move.
- The bad spacings cluster just next to, but not at, 0, 2048, and about
  1365 and 2731 (4096/3 and 2 x 4096/3). Equivalently (arithmetic on the
  table, not measured separately): a spacing is bad when S, 2S or 3S mod
  4096 lands within roughly 64-192 bytes of a multiple of 4096 without
  being one. The copies sit at 0, S, 2S, 3S, so S, 2S and 3S are the
  distances between pairs of copies.
- Exactly 0 (63.1%) and exactly 2048 (62.4%) are the two best spacings at
  every size.
- 100K's default spacing (2752) is a bad one; 80K's (576) and 40K's (320)
  are not, which explains why only 100K dropped in BKQ4.1.

Plots: `03-BKQ4/plots/2026.10.18.00{6,7,8}.CopyPadSweep<N>x<N>.xlsx`
(100K, 80K, 40K).

#### Conclusion

Supported: % TPP is a function of the copy spacing mod 4096 alone, at all
three sizes. The bad placements depend on the distances between pairs of
copies, not on dB. Caveat: this doesn't fully rule out c. c and the copies
are large allocations, likely mmap'd at a fixed offset within a page, so
c's position mod 4096 relative to the copies may also be the same at every
size (not checked). A spacing that is a multiple of 4096 bytes gave the
best rate (63.1%) at all three sizes.

## 03-BKP1: BKQ4 parallelized over tile rows with an array reduction (Part B)

### BKP1.1: static outer-loop split, reduction(+:c[:n])

#### Introduction

PA3 Part B: parallelize across blocks, using Part A's single-core kernel
inside each block. Part A ended with BKQ4 at ~61-63% TPP on one core, with
the best results when the copies of b are spaced a multiple of 4096 bytes
apart (BKQ4.3/4.4). The simplest race-free way to split the tiles is an
array reduction: each thread accumulates into its own private copy of c,
and the copies are summed at the end. PA3.md lists the reduction clause as
one of the approaches to explore.

#### Hypothesis

Near-linear scaling, limited by load imbalance. schedule(static) deals out
whole tile rows: at 100K there are 98 / 66 / 33 rows for bs = 1024 / 1536 /
3072, so at 16 threads the busiest thread has 7 / 5 / 3 rows against an
average of 6.1 / 4.1 / 2.1, capping speedup at ~14.0x / ~13.2x / ~11x.
Smaller blocks should scale better although larger blocks are faster on
one core. Zeroing and merging the private copies of c (~200K floats per
thread) should be negligible. Speedups well below those caps would point
at a shared resource; Nick's PA2 array reduction showed a per-cluster
ceiling, with drops at 5, 9, 13 threads.

#### Design

BKQ4 unchanged except:

- Copy spacing rounded up to a multiple of 1024 floats (4096 bytes) by
  default, before copy_pad is added.
- Outer tile loop (`ii`) split across threads:
  `#pragma omp parallel for schedule(static) reduction(+:c[:n])`; in the
  checking build `reduction(+:c[:n], comp[:n])` so the Kahan compensation
  array is reduced the same way.
- c is zeroed and the copies of b are built before the parallel region
  (serial); the copies are shared read-only.
- 4-loop structure retained (VARIANTS/StudentInstruction: BKP variants
  keep the 4 loops).

#### Implementation

`03-BKP1/` (copied from `03-BKQ4`, variant name `BKP1`). Its `*Q` ancestor
for T(seq) is `03-BKQ` (from the directory name). Gate PASSED: oracle 42/42,
gold 14/14, both `.check` and `.check-par`.

- `PolyMult.time-par`: the outlined parallel loop
  (`kernel_multiply._omp_fn.0`) still has the 8-FMA chain (vfmadd213ps +
  7 vfmadd231ps), so `no-associative-math` carried into the outlined
  function; the reduction merge is vectorized (vaddps).
- `PolyMult.time` (no -fopenmp) has no outlined function: the pragma is
  ignored and it is BKQ4 with the 4096-byte spacing.
- Smoke test (1 rep, not a measurement), 100K, bs=3072, bound as in
  `_gate.sh`: t=1 22.24 GFLOPs/s (63.2%), t=16 205.9 GFLOPs/s; no crash
  (Nick's PA2 reduction segfaulted when the private c copies, on the
  thread stacks, outgrew them; at 100K each copy is 800 KB).

#### Experiment

```
# sequential baseline (sweep.sh refuses --tune with --record-seq: T(seq)
# must be the untuned default, i.e. BKP1's fallback block_size=64)
./sweep.sh --variant-dir 03-BKP1 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.10.18.001_seq_100000x100000 --record-seq
n=2
for bs in 1024 1536 3072; do
  ./sweep.sh --variant-dir 03-BKP1 --dA 100000 --dB 100000 --threads 1:16:1 \
      --reps 5 --tune block_size=$bs \
      --name 2026.10.18.00${n}_threads_bs${bs}_100000x100000
  n=$((n+1))
done
.venv/bin/python plot.py \
    --csv 03-BKP1/results/2026.10.18.002_threads_bs1024_100000x100000.csv --label "bs=1024" \
    --csv 03-BKP1/results/2026.10.18.003_threads_bs1536_100000x100000.csv --label "bs=1536" \
    --csv 03-BKP1/results/2026.10.18.004_threads_bs3072_100000x100000.csv --label "bs=3072" \
    --tpp-per-core 35.2 --topic ThreadSweep100000x100000 \
    --title "BKP1 (static tile rows + reduction), 100000x100000"
```

The recorded untuned T(seq) is 2.591 s (bs=64). Each sweep's csv used its
own t=1 median instead (`seq_time_source: min of 2: this sweep's own t=1
median`): 0.963 / 0.954 / 0.897 s for bs = 1024 / 1536 / 3072, so Speedup
below is relative to the same block size on 1 thread.

The other user's rsync was active (load average up to ~5 at the end).
Reps within ~1% except a few points at 10-16 threads (bs=1536 up to
-3.1%/+2.4%).

#### Results

Median of 5. Speedup vs own t=1; "cap" = the static-imbalance limit,
computed from the actual tile-row heights (last row partial) and libgomp's
static split (contiguous chunks, the first T mod t threads get one extra
row).

| t  | bs=1024 GFLOPs/s, speedup / cap | bs=1536            | bs=3072            |
|---:|---------------------------------|--------------------|--------------------|
| 1  | 20.8, 1.00 / 1.0                | 21.0, 1.00 / 1.0   | 22.3, 1.00 / 1.0   |
| 2  | 41.2, 1.98 / 2.0                | 41.3, 1.97 / 2.0   | 42.6, 1.91 / 1.9   |
| 4  | 81.0, 3.90 / 3.9                | 80.1, 3.82 / 3.8   | 80.5, 3.61 / 3.6   |
| 5  | 101.2, 4.87 / 4.9               | 95.9, 4.57 / 4.7   | 101.8, 4.56 / 4.7  |
| 8  | 155.6, 7.49 / 7.5               | 148.8, 7.10 / 7.2  | 142.2, 6.38 / 6.5  |
| 9  | 174.4, 8.40 / 8.9               | 163.3, 7.79 / 8.1  | 169.5, 7.60 / 8.1  |
| 12 | 222.8, 10.72 / 10.9             | 212.0, 10.11 / 10.9| 219.8, 9.86 / 10.9 |
| 13 | 239.4, 11.52 / 12.2             | 204.3, 9.75 / 10.9 | 208.2, 9.34 / 10.9 |
| 14 | 273.8, 13.18 / 14.0             | 240.8, 11.48 / 13.0| 203.5, 9.13 / 10.9 |
| 16 | 283.1, 13.62 / 14.0 (50.3% TPP) | 248.5, 11.85 / 13.0 (44.1%) | 205.2, 9.20 / 10.9 (36.4%) |

(All 16 thread counts in the csvs.)

- Best: 283.1 GFLOPs/s at 16 threads, bs=1024, 13.6x, 50.3% of the
  16-core TPP (563.2).
- The speedup curves follow the imbalance cap's staircase, e.g. bs=3072 is
  flat from 7->8, 9->10 and 11->16 threads, exactly where the busiest
  thread's row count doesn't change.
- Measured speedup is 94-100% of the cap for bs=1024 at every t, 88-100%
  for bs=1536 and 84-100% for bs=3072; the shortfall grows with thread
  count and block size.
- No drops at 5, 9, 13 beyond what the cap predicts (bs=1536 at 13 is the
  exception: 9.75 vs 10.11 at 12).
- Smaller blocks scale better and win from 4 threads up, although bs=3072
  is fastest on 1 thread (63.3% vs 59.0%).

Plot: `03-BKP1/plots/2026.10.18.001.ThreadSweep100000x100000.xlsx`.

#### Conclusion

Supported: load imbalance from dealing whole tile rows statically explains
the shape and most of the loss; the predicted caps (~14.0x / ~13.2x /
~11x) match the measured staircase. A further 2-16% beyond imbalance
appears at higher thread counts, more for larger blocks; its cause is not
measured (candidates: the serial copy/zeroing setup, the reduction merge,
shared-L2 pressure within a cluster). The reduction itself did not show
the per-cluster ceiling of Nick's PA2 version.

## 03-BKP2: BKP1 + collapse(2) over the tile loops (Part B)

### BKP2.1: collapse(2) on ii and jj

#### Introduction

BKP1.1 showed that dealing whole tile rows statically caps speedup through
load imbalance (98 / 66 / 33 rows at 100K for bs = 1024 / 1536 / 3072),
which explained the staircase shape and most of the loss; a further 2-16%
at high thread counts was unexplained. Collapsing the two tile loops makes
the unit of work a single tile, decoupling parallel granularity from block
size. The reduction already makes any tile order race-free, so collapse is
legal here.

#### Hypothesis

With 98^2 / 66^2 / 33^2 = 9,604 / 4,356 / 1,089 tiles, static imbalance is
negligible (at most one extra tile per thread), so every block size moves
close to linear scaling and the staircase disappears. bs=3072, the fastest
on one core, becomes the best at 16 threads: ~15x of 22.3 GFLOPs/s, about
330 GFLOPs/s. A remaining shortfall from linear would be the part BKP1.1
left unexplained.

#### Design

BKP1 unchanged except: `collapse(2)` added to the `parallel for` (both the
checking and timed variants of the pragma), and `iend` moved from between
the ii and jj loops to inside the jj loop, so the two tile loops are
perfectly nested. 4-loop structure retained. Static schedule: each thread
gets a contiguous chunk of the row-major (ii, jj) tile order.

#### Implementation

`03-BKP2/` (copied from `03-BKP1`, variant name `BKP2`). Gate PASSED:
oracle 42/42, gold 14/14, both binaries. Outlined parallel loop still has
the 8-FMA chain.

#### Experiment

Same set as BKP1.1:

```
./sweep.sh --variant-dir 03-BKP2 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.10.18.001_seq_100000x100000 --record-seq
n=2
for bs in 1024 1536 3072; do
  ./sweep.sh --variant-dir 03-BKP2 --dA 100000 --dB 100000 --threads 1:16:1 \
      --reps 5 --tune block_size=$bs \
      --name 2026.10.18.00${n}_threads_bs${bs}_100000x100000
  n=$((n+1))
done
```

As in BKP1.1, each sweep's T(seq) is its own t=1 median (0.963 / 0.956 /
0.898 s), not the untuned recorded value. Reps within ~1-3.6%. Other user's
rsync still active.

#### Results

Median of 5; speedup vs own t=1; BKP1 for comparison:

| t  | bs=1024: GF/s, %TPP, speedup (BKP1) | bs=1536                    | bs=3072                    |
|---:|-------------------------------------|----------------------------|----------------------------|
| 1  | 20.8, 59.0%, 1.00 (1.00)            | 20.9, 59.4%, 1.00 (1.00)   | 22.3, 63.3%, 1.00 (1.00)   |
| 4  | 82.6, 58.7%, 3.98 (3.90)            | 82.3, 58.5%, 3.93 (3.82)   | 87.4, 62.1%, 3.93 (3.61)   |
| 8  | 156.1, 55.4%, 7.52 (7.49)           | 155.0, 55.0%, 7.41 (7.10)  | 162.3, 57.6%, 7.29 (6.38)  |
| 12 | 232.0, 54.9%, 11.18 (10.72)         | 229.3, 54.3%, 10.96 (10.11)| 231.3, 54.8%, 10.39 (9.86) |
| 13 | 253.5, 55.4%, 12.21 (11.52)         | 248.6, 54.3%, 11.88 (9.75) | 234.7, 51.3%, 10.54 (9.34) |
| 16 | 314.3, 55.8%, 15.14 (13.62)         | 298.7, 53.0%, 14.28 (11.85)| 268.6, 47.7%, 12.06 (9.20) |

(All 16 thread counts in the csvs.)

- Best: 314.3 GFLOPs/s at 16 threads, bs=1024, 15.1x, 55.8% of 16-core TPP
  (BKP1 best: 283.1, 13.6x, 50.3%); +11% over BKP1 at that point, +20% for
  bs=1536 and +31% for bs=3072 at 16 threads.
- The staircase is gone: speedup now rises at every added thread for all
  three block sizes.
- bs=3072 did not become the best: at 16 threads it is the slowest of the
  three (268.6). Its per-thread rate falls steadily with thread count:
  ~62% TPP at 2-6 threads, ~58% at 7-9, ~55% at 10-12, ~48-51% at 13-16.
  bs=1024's falls from ~59% to ~55-56% by 6 threads and then stays flat.
  Static imbalance can't explain this (at most 1 extra tile per thread:
  1,089 tiles / 16 threads -> 69 vs 68.1, >= 98.6%).

Plots: `03-BKP2/plots/2026.10.18.001.ThreadSweep100000x100000.xlsx`;
BKP1 vs BKP2 (bs=1024 and 3072):
`plots/2026.10.18.001.BKP1vsBKP2ThreadSweep100000x100000.xlsx`.

#### Conclusion

Partly supported: collapse removed the imbalance staircase and improved
every block size at high thread counts, giving the best result so far
(314 GFLOPs/s, 15.1x). Refuted for bs=3072: with imbalance removed, a
per-thread slowdown that grows with thread count and with block size
remains, and it makes the smallest block the best. Its cause is not
measured; it looks like contention for something threads share (the
cluster's L2, the L3/memory, or the serial setup and reduction merge),
growing faster for larger tiles.

### BKP2.2: perf comparison, bs=1024 vs 3072, 4 vs 16 threads

#### Introduction

BKP2.1 removed the static imbalance, but bs=3072's per-thread rate kept
falling as threads were added (~62% TPP at 4 threads, ~48% at 16) while
bs=1024's levelled off at ~55-56%, making bs=1024 the best at 16 threads.
Something shared between threads slows larger tiles more. Each 4-core
cluster shares one L2, so the cluster L2 is the first candidate.

#### Hypothesis

From 4 threads (one per cluster, no L2 sharing) to 16 (four per cluster),
bs=3072 shows a large rise in L2-related stalls per FMA and bs=1024 a much
smaller one. If L2 misses per FMA grow much more at bs=3072, the shared L2
is the limit.

#### Design

BKP2 timing binary, 100000x100000, 3 reps, bound as in `_gate.sh`
(4 threads land on cores 16, 20, 24, 28: one per cluster). Configurations:
bs in {1024, 3072} x threads in {4, 16}. Three counter groups per
configuration, one run at a time; counts are summed over all threads:

- cycles, instructions, `mem_load_uops_retired.{l1_miss,l2_hit,l2_miss,
  l3_hit,dram_hit}`, `ld_blocks.address_alias`
- cycles, `mem_bound_stalls.{load,load_l2_hit,load_llc_hit,load_dram_hit}`,
  `mem_scheduler_block.ld_buf`, `topdown_be_bound.non_mem_scheduler`
- cycles, `l2_request.{all,miss}`, `longest_lat_cache.{reference,miss}`,
  `mem_uops_retired.all_loads`, `topdown_be_bound.mem_scheduler`

#### Experiment

```
PL='{16},{20},{24},{28},{17},{21},{25},{29},{18},{22},{26},{30},{19},{23},{27},{31}'
for bs in 1024 3072; do for t in 4 16; do
  # for each of the three event groups:
  OMP_PROC_BIND=close OMP_PLACES="$PL" taskset -c 16-31 perf stat -e <group> \
      ./bin/PolyMult.time-par -dA 100000 -dB 100000 -t $t -r 3 --tune block_size=$bs
done; done
```

Despite groups of 7-8 events, perf multiplexed them: each event was
counted 74-87% of the time (scaled). Timing during the runs matched
BKP2.1 (bs=1024: 82 / ~300 GFLOPs/s; bs=3072: 87 / ~263).

#### Results

Per vector FMA (3 x 100001^2 / 8 = 3.75e9), counts summed over threads:

|                               | bs1024 t4 | bs1024 t16 | bs3072 t4 | bs3072 t16 |
|-------------------------------|----------:|-----------:|----------:|-----------:|
| GFLOPs/s                      | 82.1      | 304.0      | 86.9      | 264.2      |
| cycles (sum over threads)     | 1.702     | 1.822      | 1.596     | 2.064      |
| instructions                  | 2.299     | 2.323      | 1.856     | 1.870      |
| L1 misses (% of loads)        | 0.011 (0.44%) | 0.018 (0.76%) | 0.170 (7.4%) | 0.330 (14.3%) |
| L2 misses                     | 0.00005   | 0.00008    | 0.00003   | 0.00025    |
| `ld_blocks.address_alias`     | 0.056     | 0.063      | 0.188     | 0.324      |
| L2 requests                   | 0.020     | 0.024      | 0.292     | 0.313      |
| mem-bound load stall cycles   | 0.009     | 0.016      | 0.137     | 0.552      |
| - of which waiting on L2 hits | 0.008     | 0.014      | 0.136     | 0.551      |
| stall cycles per L2 request   | 0.40      | 0.59       | 0.46      | 1.76       |
| load buffer full, cycles      | 0.170     | 0.168      | 0.225     | 0.599      |
| FP scheduler full, % slots    | 37.0%     | 34.1%      | 35.6%     | 18.5%      |
| memory scheduler full, % slots| 13.6%     | 12.6%      | 20.9%     | 38.2%      |

- bs=3072, 4 -> 16 threads: cycles per FMA +0.47 (1.596 -> 2.064), and
  memory-bound stall cycles waiting on L2 hits +0.41 (0.136 -> 0.551),
  ~88% of the increase. Stall per L2 request rises 3.8x (0.46 -> 1.76).
  L1 misses per FMA double (7.4% -> 14.3% of loads), while L2 requests
  per FMA rise only 7%. L2 misses stay negligible (everything is served by
  L2).
- bs=1024: L1 misses stay under 1% of loads at both thread counts; L2
  stall cycles are tiny (0.008 -> 0.014); cycles per FMA still rise by
  0.12 (7%), which these counters don't account for.
- bs=3072's FP scheduler share halves at 16 threads (35.6% -> 18.5%) as
  the memory scheduler share nearly doubles (20.9% -> 38.2%): the limit
  moves from FMA latency to the memory side.
- bs=1024 does more instructions per FMA than bs=3072 (2.30 vs 1.86:
  more ragged-edge work in smaller tiles).
- As in BKQ4.3, `ld_blocks.address_alias` tracks L1 misses at bs=3072
  (0.188 vs 0.170 and 0.324 vs 0.330), but not at bs=1024 (0.056 vs 0.011).

#### Conclusion

Supported for bs=3072: its loss with thread count is load stalls waiting
on L2 hits. Each L2 access gets ~4x slower when four threads share a
cluster's L2, and L1 misses per FMA double. bs=1024 hardly misses L1, so
sharing the L2 barely affects it, which is why it scales better. Not
explained: why the L1 miss rate per FMA doubles with more threads (each
thread runs the same kernel on tiles of the same size), and what costs
bs=1024 its 7%. One possible reading of the L1-miss doubling (not
measured): each thread's private reduction copy of c sits at a different
address, so with 16 threads some land at the bad placements found in
BKQ4.3/4.4 relative to the copies of b.

## 03-BKP3: checkerboard tiles, no reduction (Part B, diagnostic)

### BKP3.1: literal (I+J)-parity checkerboard

#### Introduction

PA3.md's second Part B approach is to drop the reduction and exploit the
pattern of races between tiles: "a tile has a race only with its immediate
four neighbors", so a checkerboard pattern of tiles should be race-free.
Before implementing, the overlap between tiles in our (i, j) tiling was
checked by brute force (bs=4, 5x5 tiles): tile (I, J) writes
c[(I+J)*bs .. (I+J+2)*bs - 2], so two tiles overlap exactly when their
I + J differ by 0 or 1 (rule confirmed for every pair). Tiles overlapping
tile (2,2), marked #:

```
. . . # #
. . # # #
. # X # .
# # # . .
# # . . .
```

Besides its four edge neighbours, every tile on the same anti-diagonal
(same I + J) writes the same range of c. Those tiles have the same
checkerboard colour, so the literal checkerboard races: 30 same-colour
overlapping pairs in the 5x5 example. This does not match PA3.md's
"four neighbors" statement for this tiling (possibly the lecture assumed a
different index space; not resolved). Decision (user): implement the
literal checkerboard anyway as a diagnostic, to show the race and its cost
before designing a race-free version.

#### Hypothesis

The parallel checking build fails the gate (shared-c races between
same-diagonal tiles), except where a case has a single tile row (no two
same-colour tiles share a diagonal). The sequential checking build passes
(one thread, no race).

#### Design

BKP2 without the reduction. Two phases, `colour` = 0 then 1; each phase is
`#pragma omp parallel for collapse(2) schedule(static)` over the (ii, jj)
tile grid, skipping tiles with `((ii/bs + jj/bs) & 1) != colour`. The
implicit barrier at the end of each parallel for separates the phases.
Threads accumulate straight into the shared c (and shared comp in the
checking build). Everything else (kernel inside a tile, 4096-byte copy
spacing) as BKP2.

#### Implementation

`03-BKP3/` (copied from `03-BKP2`, variant name `BKP3`). Builds cleanly;
outlined parallel loop keeps the 8-FMA chain.

Gate, run twice: FAILED both times, as expected.

- `PolyMult.check` (sequential): oracle 0/42, gold 0/14 failed.
- `PolyMult.check-par`: oracle 11/42 and 12/42 failed, gold 4/14 both
  times. Every failing case has dA, dB >= 500 (several tile rows at the
  gate's bs=64); cases with dA or dB in {0, 3} (one tile row or column)
  pass. Typical damage: 500x500 constants 789/1001 and 758/1001 outputs
  wrong; 20000x20000 random-positive 30873/40001 and 32832/40001 wrong,
  worst error 3e4-4e4 times the tolerance bound.

#### Experiment

Diagnostic timing (results go to `results/diagnostic/`, preamble
`gate_status=FAILED`; `--record-seq` is refused with
`--allow-gate-failure`, so Speedup uses each sweep's own t=1 time):

```
n=1
for bs in 1024 3072; do
  ./sweep.sh --variant-dir 03-BKP3 --dA 100000 --dB 100000 --threads 1:16:1 \
      --reps 5 --tune block_size=$bs --allow-gate-failure \
      --name 2026.10.18.00${n}_threads_bs${bs}_100000x100000
  n=$((n+1))
done
```

Hypothesis for the timing: without private copies, zeroing and merging,
BKP3 runs at least as fast as BKP2, possibly faster at bs=3072 if some of
BKP2's L2 pressure came from the private copies of c; if slower, from
cache-line ping-pong on c between threads and the extra barrier.

#### Results

Median of 5 (results are numerically wrong; timing only):

| t  | BKP3 bs=1024 GF/s (BKP2) | BKP3 bs=3072 GF/s (BKP2) |
|---:|--------------------------|--------------------------|
| 1  | 10.7 (20.8)              | 11.1 (22.3)              |
| 4  | 42.5 (82.6)              | 39.5 (87.4)              |
| 8  | 61.8 (156.1)             | 78.2 (162.3)             |
| 12 | 80.5 (232.0)             | 88.1 (231.3)             |
| 16 | 97.3 (314.3), 9.1x       | 123.6 (268.6), 11.1x     |

Rep spread up to ~20% at some thread counts (BKP2: <= 3.6%).

- BKP3 is about half of BKP2 already at 1 thread, where nothing can race,
  and 0.30-0.46x at 16 threads.
- Follow-up checks (single runs, 100K, bs=1024, core 16):
  - BKP3 `PolyMult.time` (no OpenMP): 20.6-20.7 GFLOPs/s, full speed.
    `PolyMult.time-par` at t=1: 10.7. So the halving is in the OpenMP
    build.
  - `-fopt-info-vec` on the `-fopenmp` build: BKP3's fused loop is
    "versioned for vectorization because of possible aliasing"; BKP2's is
    not.
  - `perf record`/`perf annotate` of BKP3 `time-par` at t=1: the hot loop
    stores c (`vmovups %ymm0,-0x20(%rax)`) after every FMA, 8 stores per 8
    FMAs, instead of the single store per 8 FMAs of BKQ2-BKP2. Inside the
    OpenMP-outlined function the shared c is reached through a pointer
    without the `restrict` guarantee, so the compiler can't keep c[i0+t]
    in a register across the 8 rows, which undoes the unroll-and-jam's
    store saving. In BKP2 each thread's private reduction copy of c is a
    local array, provably separate from the copies of b.

Plot (cross-variant):
`plots/2026.10.18.002.BKP2vsBKP3diagThreadSweep100000x100000.xlsx`.

#### Conclusion

Refuted, for a reason unrelated to the race: dropping the reduction halves
single-thread speed because the compiler loses the guarantee that c
doesn't alias the copies of b, and stores c after every FMA. The timing
therefore can't isolate the race's cost or the barrier's. Any version
without the reduction (including a race-free diagonal-parity BKP4) needs
c to be provably non-aliased inside the parallel region again (for
example a `float *restrict` local inside the region, or the tile body in
a separate function with restrict-qualified parameters), checked in the
assembly.

### BKP3.2: tile body in a restrict-qualified function

#### Introduction

BKP3.1 found that without the reduction, the OpenMP build of the tile
kernel ran at half speed even on one thread: inside the outlined parallel
loop, c is reached through a pointer without `restrict`, so GCC versions
the fused loop for possible aliasing and stores c after every FMA. Any
version without the reduction needs c provably non-aliased inside the
parallel region again before its timing means anything.

#### Hypothesis

With the tile body in its own function whose pointer parameters are
`restrict`-qualified, the fused loop goes back to one load and one store
of c per 8 FMAs, the aliasing versioning disappears, and the OpenMP binary
at 1 thread runs at the sequential binary's / BKP2's speed (~20.7-20.8
GFLOPs/s at 100K, bs=1024). The gate still fails (the race is unchanged).

#### Design

In `03-BKP3` (in place): the body of one tile (fused loop, ragged ends,
leftover rows) moved verbatim into

```
__attribute__((noinline, optimize("no-associative-math")))
static void bkq_tile(const float *restrict a, const float *restrict b,
                     float *restrict c COMP_PARAM,
                     const float *const *restrict bc,
                     int ii, int iend, int jj, int jend);
```

`COMP_PARAM` adds `, double *restrict comp` in the checking build only
(the production BPM_ACC never uses comp). `noinline` keeps the function,
and its restrict parameters, a separate unit. The two colour phases and
the collapsed (ii, jj) tile loops stay in kernel_multiply and call
bkq_tile per tile; the i/j loops are inside it (4-loop structure
retained).

#### Implementation

Gate: FAILED as expected (sequential check 0/42, 0/14; parallel check
oracle 12/42, gold 4/14 failed).

- `-fopt-info-vec` on the `-fopenmp` build: no "versioned ... because of
  possible aliasing" any more.
- `PolyMult.time-par`, bkq_tile's fused loop: `vmovups` (b), `vfmadd213ps`
  with c as memory operand, 7 `vfmadd231ps`, one `vmovups` store of c:
  one c store per 8 FMAs again.
- 1 thread, 100K, bs=1024, 3 reps, core 16: `PolyMult.time` 20.72,
  `PolyMult.time-par` 20.66-20.70 GFLOPs/s (BKP3.1: 10.7; BKP2: 20.8).

#### Conclusion

Supported: the restrict-qualified tile function restores the kernel's code
generation in the OpenMP build; 1-thread speed matches the sequential
binary and BKP2. The BKP3.1 timings are superseded and should be re-run.

### BKP3.3: diagnostic timing of BKP3.2

#### Introduction

With BKP3.2's code generation fixed, the gap between BKP3 and BKP2 should
now reflect only the parallel strategy: shared, racy writes to c and an
extra barrier (BKP3) versus private copies of c and a merge (BKP2).

#### Hypothesis

BKP3 matches BKP2 at 1 thread and stays within a few percent of it at all
thread counts, possibly ahead where BKP2 pays for its private copies; any
shortfall would come from threads writing the same cache lines of c
(same-diagonal tiles running at the same time) and from the barrier.

#### Design / Experiment

Same as BKP3.1's diagnostic timing, on the BKP3.2 code:

```
n=3
for bs in 1024 3072; do
  ./sweep.sh --variant-dir 03-BKP3 --dA 100000 --dB 100000 --threads 1:16:1 \
      --reps 5 --tune block_size=$bs --allow-gate-failure \
      --name 2026.10.18.00${n}_threads_bs${bs}_100000x100000
  n=$((n+1))
done
```

#### Results

Median of 5 (numerically wrong results; timing only), BKP3 / BKP2:

| t  | bs=1024 GF/s (BKP2), ratio | bs=3072 GF/s (BKP2), ratio |
|---:|----------------------------|----------------------------|
| 1  | 20.7 (20.8), 1.00          | 22.3 (22.3), 1.00          |
| 2  | 41.2 (41.3), 1.00          | 38.2 (43.8), 0.87          |
| 3  | 43.2 (61.6), 0.70          | 65.4 (65.5), 1.00          |
| 4  | 82.1 (82.6), 0.99          | 72.9 (87.4), 0.83          |
| 5  | 102.7 (103.2), 1.00        | 107.8 (107.7), 1.00        |
| 6  | 97.7 (119.8), 0.82         | 113.6 (128.7), 0.88        |
| 8  | 133.5 (156.1), 0.86        | 134.4 (162.3), 0.83        |
| 12 | 164.5 (232.0), 0.71        | 187.6 (231.3), 0.81        |
| 16 | 222.2 (314.3), 0.71        | 229.1 (268.6), 0.85        |

Rep spread up to 12.5% (BKP2: <= 3.6%).

- 1 thread now matches BKP2 exactly (BKP3.1: half).
- At some thread counts BKP3 equals BKP2 (bs=1024: t = 1, 2, 4, 5;
  bs=3072: t = 1, 3, 5); at the others it is 7-33% slower. From 6 threads
  up it is slower at every count, 0.71x (bs=1024) and 0.85x (bs=3072) at
  16.
- The pattern of which thread counts lose is not explained. One possible
  reading (not measured): the static split of the collapsed tile order
  decides whether threads happen to work on same-diagonal tiles, which
  write the same cache lines of c, at the same time.

Plot (cross-variant):
`plots/2026.10.18.003.BKP2vsBKP32diagThreadSweep100000x100000.xlsx`.

#### Conclusion

Refuted: even ignoring correctness, the racy checkerboard is slower than
BKP2's reduction from 6 threads up, with much noisier timing. Dropping the
private copies doesn't pay off when concurrently running tiles write the
same range of c. A race-free schedule (diagonal parity: tiles on
diagonals d and d + 2 write disjoint ranges of c, apart from at most one
shared cache line at each boundary) would also avoid most of that
sharing.

### BKP4.1: diagonal parity (race-free, no reduction)

#### Introduction

BKP3 showed that dropping BKP2's private copies of c only pays off if
concurrently running tiles don't write the same part of c. Tile (I, J)
writes c[(I+J)*bs .. (I+J+2)*bs - 2], so all tiles on one anti-diagonal
d = I + J write the same range, and diagonals d and d + 2 write disjoint
ranges. That gives a race-free schedule with no reduction: hand out
whole diagonals of one parity at a time, each diagonal run serially by
one thread. This is Part B's pattern (b), race-free tiles without a
reduction clause.

#### Hypothesis

BKP4 passes the correctness gate (no race) and runs at 1 thread at BKP2's
speed. At 16 threads it matches or beats BKP2 (314 GF/s at bs=1024),
since it skips the private copies of c and their merge, and threads write
disjoint ranges of c (they can only share the one cache line at each
boundary between ranges). Load imbalance should be small: a greedy
simulation of dynamic scheduling in diagonal order (tile cost = 1, edge
tiles ignored) puts 16-thread efficiency at 99.5% (bs=1024), 99.0%
(1536) and 98.6% (3072). The costs it adds are one more barrier (between
the two phases) and, within a diagonal, a thread walking tiles that each
read a different block of a and of b.

#### Design

In `03-BKP4` (copied from BKP3.2, keeping the restrict-qualified
`noinline` bkq_tile and the copies of b):

```
int TI = (dA + bs) / bs, TJ = (dB + bs) / bs;
for (int parity = 0; parity < 2; parity++) {
    #pragma omp parallel for schedule(dynamic, 1)
    for (int d = parity; d <= TI + TJ - 2; d += 2)
        for (int I = max(0, d-(TJ-1)); I <= min(d, TI-1); I++)
            bkq_tile(..., I*bs, iend, (d-I)*bs, jend);
}
```

- One loop iteration is one whole diagonal, so no two threads ever run
  tiles of the same diagonal; inside a phase the diagonals differ by
  multiples of 2 and their c ranges are disjoint.
- The implicit barrier at the end of each `parallel for` separates the
  even and odd phases (diagonals d and d + 1 overlap).
- `schedule(dynamic, 1)`, because diagonal lengths run 1 .. min(TI, TJ)
  and back.
- No reduction, so threads add straight into the shared c (and, in the
  checking build, comp).

#### Implementation

- Built cleanly, no warnings. Gate PASSED, 3 times out of 3 runs (`.check`
  and `.check-par`: oracle 0/42, gold 0/14 failed).
- `-fopt-info-vec` on the `-fopenmp` build: no aliasing versioning.
- `PolyMult.time-par`, bkq_tile's fused loop: `vmovups` (b),
  `vfmadd213ps` with c as memory operand, 7 `vfmadd231ps`, one `vmovups`
  store of c (one c store per 8 FMAs, same as BKP3.2).
- 1 thread, 100K, bs=1024, core 16: `PolyMult.time-par` 20.72 GF/s (BKP2:
  20.8).

#### Experiment

Same set as BKP1.1/BKP2.1:

```
./sweep.sh --variant-dir 03-BKP4 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.10.18.001_seq_100000x100000 --record-seq
n=2
for bs in 1024 1536 3072; do
  ./sweep.sh --variant-dir 03-BKP4 --dA 100000 --dB 100000 --threads 1:16:1 \
      --reps 5 --tune block_size=$bs \
      --name 2026.10.18.00${n}_threads_bs${bs}_100000x100000
  n=$((n+1))
done
.venv/bin/python plot.py \
    --csv 03-BKP4/results/2026.10.18.002_threads_bs1024_100000x100000.csv --label "bs=1024" \
    --csv 03-BKP4/results/2026.10.18.003_threads_bs1536_100000x100000.csv --label "bs=1536" \
    --csv 03-BKP4/results/2026.10.18.004_threads_bs3072_100000x100000.csv --label "bs=3072" \
    --tpp-per-core 35.2 --topic ThreadSweep100000x100000 \
    --title "BKP4 (diagonal parity, no reduction), 100000x100000"
.venv/bin/python plot.py \
    --csv 03-BKP2/results/2026.10.18.002_threads_bs1024_100000x100000.csv --label "BKP2 bs=1024" \
    --csv 03-BKP2/results/2026.10.18.004_threads_bs3072_100000x100000.csv --label "BKP2 bs=3072" \
    --csv 03-BKP4/results/2026.10.18.002_threads_bs1024_100000x100000.csv --label "BKP4 bs=1024" \
    --csv 03-BKP4/results/2026.10.18.004_threads_bs3072_100000x100000.csv --label "BKP4 bs=3072" \
    --tpp-per-core 35.2 --topic BKP2vsBKP4ThreadSweep100000x100000 \
    --title "BKP2 (collapse + reduction) vs BKP4 (diagonal parity), 100000x100000"
```

Recorded untuned T(seq): 2.626 s (bs=64, 7.6 GF/s). As before, each sweep
uses its own t=1 median as T(seq).

#### Results

Gate passed on every sweep. Median of 5, GF/s, BKP2 in brackets, ratio
BKP4/BKP2, %TPP = GF/s / (35.2 x t):

| t  | bs=1024                    | bs=1536                    | bs=3072                    |
|---:|----------------------------|----------------------------|----------------------------|
| 1  | 20.7 (20.8) 1.00, 58.9%    | 21.0 (20.9) 1.00, 59.6%    | 22.3 (22.3) 1.00, 63.3%    |
| 2  | 41.3 (41.3) 1.00, 58.7%    | 41.8 (41.2) 1.02, 59.4%    | 44.4 (43.8) 1.01, 63.0%    |
| 4  | 82.7 (82.6) 1.00, 58.7%    | 83.3 (82.3) 1.01, 59.1%    | 88.7 (87.4) 1.02, 63.0%    |
| 6  | 123.7 (119.8) 1.03, 58.6%  | 123.8 (120.5) 1.03, 58.6%  | 128.8 (128.7) 1.00, 61.0%  |
| 8  | 164.6 (156.1) 1.05, 58.5%  | 164.7 (155.0) 1.06, 58.5%  | 174.1 (162.3) 1.07, 61.8%  |
| 10 | 205.7 (195.8) 1.05, 58.4%  | 202.4 (191.0) 1.06, 57.5%  | 199.2 (193.9) 1.03, 56.6%  |
| 11 | 224.1 (214.8) 1.04, 57.9%  | 223.7 (210.5) 1.06, 57.8%  | 210.0 (212.7) 0.99, 54.2%  |
| 12 | 246.7 (232.0) 1.06, 58.4%  | 238.5 (229.3) 1.04, 56.5%  | 224.3 (231.3) 0.97, 53.1%  |
| 14 | 282.6 (272.6) 1.04, 57.3%  | 274.2 (262.9) 1.04, 55.6%  | 256.6 (241.2) 1.06, 52.1%  |
| 16 | **327.1** (314.3) 1.04, 58.1% | 318.2 (298.7) 1.07, 56.5% | 286.7 (268.6) 1.07, 50.9% |

(All 16 thread counts are in the CSVs and plots.)

- BKP4 equals BKP2 at 1-5 threads and is ahead at almost every count
  from 6 up, by 3-7%; the exceptions are bs=3072 at t = 11 and 12
  (0.99x, 0.97x). New best: 327.1 GF/s at 16 threads, bs=1024
  (15.8x over its own t=1, 58.1% of TPP).
- bs=1024 holds 57.3-58.9% of TPP at every thread count: close to
  linear scaling, the per-thread rate barely drops.
- bs=3072 still falls from 63% of TPP at 1-4 threads to 51% at 16, the
  same shape as in BKP2. BKP2.2 traced that to stalls on L2 hits. Since
  BKP4 has no private copies of c and still shows it, the copies aren't
  its main cause (not measured with perf here).
- Timing is much steadier than BKP2: rep spread <= 0.7% everywhere at
  bs=1024/1536 except t=12, bs=1024 (10.5%: one rep at 0.0896 s, the
  other four within 0.3%). bs=3072 spreads up to 2.5%. BKP2's spread was
  up to 5.9%.

Plots: `03-BKP4/plots/2026.10.18.001.ThreadSweep100000x100000.xlsx`,
`plots/2026.10.18.004.BKP2vsBKP4ThreadSweep100000x100000.xlsx`,
`plots/2026.10.18.005.BKP2vsBKP4bs1024ThreadSweep100000x100000.xlsx`
(bs=1024 only).

#### Conclusion

Supported: the diagonal-parity schedule is race-free (gate passes), loses
nothing at 1 thread, and at 6+ threads beats BKP2's reduction by 3-7%,
reaching 327 GF/s (58.1% of TPP) at 16 threads with bs=1024. Removing the
private copies of c and their merge is worth a few percent; the barrier
between phases and the diagonal-length imbalance cost too little to show.
bs=1024's per-core rate is now nearly flat with thread count, so the
remaining gap to TPP at bs=1024 is mostly the single-core kernel
(~59%), while larger blocks are still limited by the L2 effect from
BKP2.2.

## 03-BKQ5: BKQ4 + unrolled fused loop (Part A, single core)

### BKQ5.1: unroll the fused t loop by 4

#### Introduction

BKQ4.2 showed that, with the split loads gone, the FP scheduler is full
~30% of slots: each output vector of c goes through a chain of 8
dependent FMAs (6-cycle latency, ~48 cycles per chain), and the core has
to find other chains to overlap. Nick's trick 3 is to give it more
independent accumulators per loop pass. This is the first option for the
single-core kernel, which now limits BKP4 at bs=1024 (~59% of TPP).

#### Hypothesis

Unrolling the vectorized fused loop by 4 puts 4 independent chains of 8
FMAs in each pass, close together in program order, so the out-of-order
core needs to hold fewer waiting FMAs to keep the FMA unit busy. The FP
scheduler-full share falls and single-core % TPP rises above BKQ4's ~63%
(bs=3072) / ~59% (bs=1024). The load port stays at 9 loads per 8 FMAs,
so the gain is limited to the latency part of the stall.

#### Design

In `03-BKQ5` (copied from BKQ4):

- copy spacing rounded up to a multiple of 4096 bytes before copy_pad,
  as in BKP1 onward (the best placement from BKQ4.3/4.4), so BKQ5 at
  copy_pad=0 is comparable with the BKP4 kernel at 1 thread;
- `#pragma GCC unroll 4` on the fused t loop. The pragma applies to the
  vectorized loop, so each pass covers 4 vectors (32 floats) of c. Each
  element still gets its 8 products in the same order: the result is
  unchanged.

Explicit interleaving of the 4 chains in program order is not available
from plain C with the mandatory BPM_ACC: intrinsics would bypass the
macro. GCC's pre-allocation scheduler (`optimize("schedule-insns")`) was
tried on a scratch copy: it interleaves chains two at a time but adds a
`vmovaps` register copy for nearly every FMA, so it was not used.

#### Implementation

- Gate PASSED (oracle 0/42, gold 0/14).
- `PolyMult.time` fused loop: 4 blocks per pass, each `vmovups` (b),
  `vfmadd213ps` with c as memory operand, 7 `vfmadd231ps`, `vmovups`
  store of c, at offsets 0, 0x20, 0x40, 0x60. The chains are one after
  another, not interleaved; all of them reuse ymm0 (register renaming
  keeps them independent).
- Quick timing, 100K, core 16, 3 reps (median GF/s), repeated twice with
  matching results (within 0.1%):

| bs   | BKQ5 (unroll 4) | control (BKQ5 without the pragma, scratch build) | BKP4 at 1 thread |
|-----:|----------------:|-------------------------------------------------:|-----------------:|
| 1024 | 20.71           | 20.74                                            | 20.72            |
| 2048 | 18.17           | -                                                | 21.12            |
| 3072 | 17.37           | 22.20                                            | 22.25            |

- Surprise: the unroll is neutral at bs=1024 but costs 14% at bs=2048 and
  22% at bs=3072. The control build matches BKP4, so the loss comes from
  the unroll itself, not from the copy spacing or inlining. Not yet
  explained.

## 03-BKQ6: rectangular tiles (Part A, single core)

### BKQ6.1: tile width sweep, 1 x n to n x n

#### Introduction

BKQ5.1 showed that unrolling the fused loop in plain C doesn't interleave
the FMA chains, and that it costs speed at large blocks; interleaving
would need intrinsics, which the mandatory BPM_ACC rules out. So BKQ5 is
set aside for now and we move to the next open point from BKQ4.2: L1
misses rose from 0.1% to ~9-10% of loads once the four copies of b were
added. A tile that is tall in i and narrow in j touches a narrower window
of the copies of b (and of c) while its rows are processed, which may cut
those misses.

#### Hypothesis

With height n fixed (n = 3072, the best square single-core block, and
n = 1024, BKP4's best block), widening the tile from 1 to n raises the
rate at first because the scalar part shrinks: the ragged ends and
narrow tiles run as plain OPQ rows, and per group of 8 rows the ragged
ends are 56 of 8w products (w = 64: 11%, w = 256: 2.7%, w = 1024: 0.7%);
below w = 8 the whole tile is scalar. Beyond a few hundred columns the
scalar share is small, and if L1 misses from the copy window matter, some
width below n beats the square tile (n x n). If not, the rate is flat from
there up to n.

#### Design

In `03-BKQ6` (copied from BKQ5, `#pragma GCC unroll` removed, so the
kernel equals BKQ4 with 4096-byte copy spacing, i.e. the BKP4 kernel):

- new knob `block_width` (default = block_size): block_size is the tile
  height (rows of a, the ii loop), block_width the tile width (columns
  of b, the jj loop);
- nothing else changed.

#### Implementation

- Gate PASSED (oracle 0/42, gold 0/14, both checking builds). The shared
  gate tune (`BPM_GATE_TUNE` in `shared/include/kernel.h`) has no
  block_width entry, so the gate only exercises square 64 x 64 tiles.
  `kernel.h` says to add an entry for every new key, but it's shared
  infrastructure, so it was not changed (needs approval). Instead, scratch
  copies of the checking binary were built with a scratch kernel.h adding
  block_width = 1, 5, 8, 24, 40, 64 to the gate tune (block_size 64): all
  six passed (oracle 0/42, gold 0/14).
- Probe, 100K, height 3072, 1 rep: w = 1: 36.8 s (0.54 GF/s), w = 8:
  15.1 s (1.33), w = 64: 2.43 s (8.24).

#### Experiment

```
./sweep.sh --variant-dir 03-BKQ6 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.10.18.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 03-BKQ6 --dA 100000 --dB 100000 --threads 1 --reps 3 \
    --tune block_width=1,2,4,8,16,32,64,128,256,512,1024,2048,3072 \
    --tune block_size=3072 --name 2026.10.18.002_width_bs3072_100000x100000
./sweep.sh --variant-dir 03-BKQ6 --dA 100000 --dB 100000 --threads 1 --reps 3 \
    --tune block_width=1,2,4,8,16,32,64,128,256,512,1024 \
    --tune block_size=1024 --name 2026.10.18.003_width_bs1024_100000x100000
```

(The two width sweeps were run back to back, one at a time, as above.)

#### Results

Median of 3, GF/s (% TPP of one core):

| width w | height 3072   | height 1024   |
|--------:|---------------|---------------|
| 1       | 0.55 (1.6%)   | 0.54 (1.5%)   |
| 2       | 0.97 (2.8%)   | 0.97 (2.7%)   |
| 4       | 0.79 (2.2%)   | 0.79 (2.2%)   |
| 8       | 1.33 (3.8%)   | 1.33 (3.8%)   |
| 16      | 2.45 (7.0%)   | 2.45 (7.0%)   |
| 32      | 4.82 (13.7%)  | 4.81 (13.7%)  |
| 64      | 8.20 (23.3%)  | 8.23 (23.4%)  |
| 128     | 12.23 (34.7%) | 12.26 (34.8%) |
| 256     | 16.05 (45.6%) | 16.07 (45.7%) |
| 512     | 19.03 (54.1%) | 19.05 (54.1%) |
| 1024    | 20.75 (58.9%) | 20.75 (58.9%) |
| 2048    | 21.16 (60.1%) | -             |
| 3072    | 22.24 (63.2%) | -             |

Rep spread <= 0.3% everywhere except height 1024, w = 1 (one rep at
54.8 s vs 37.3 s; the median is unaffected).

- The rate rises with width all the way to the square tile; no width
  narrower than n beats n x n, at either height.
- The height makes no difference: at every width the two heights agree
  to within 0.4%. At w = 1024, 1024 x 1024 and 3072 x 1024 both give
  20.75; the square 3072 tile's advantage (22.24) comes from its width.
- w = 4 is slower than w = 2 (0.79 vs 0.97), not explained.
- Below w = 8 the tile is entirely scalar (0.5-1.3 GF/s).
- A simple cost model fits the w >= 32 points to within ~4% (w = 16: 12%
  high): time per group of 8 rows = x * (vector iterations of the fused
  loop, floor((w-7)/8)) + y * (scalar products: 56 ragged-end products +
  8 per leftover fused-loop iteration, (w-7) mod 8) + z. The fit gives
  one scalar product costing ~0.25 of an 8-FMA vector iteration (~2
  vector FMAs, ~16x more per flop); z is negligible. So the narrow-width
  loss is the scalar edge work, not memory: at w = 64 that edge is 64
  scalar products against 56 vector FMAs per group.

Plots: `03-BKQ6/plots/2026.10.18.001.WidthSweepH3072100000x100000.xlsx`,
`03-BKQ6/plots/2026.10.18.002.WidthSweepH1024100000x100000.xlsx` (plot.py
refuses several CSVs on a non-thread axis, so one plot per height).

#### Conclusion

Refuted: narrow tiles don't help. The rate depends on the tile width only
and increases monotonically up to the square tile, because each tile row
group pays a fixed scalar edge (~56-64 scalar products) that the fused
loop's length must amortize; tall tiles neither help nor hurt. Any L1
benefit from a narrower copy window, if present, is too small to see
under that cost. The ~9-10% L1 misses of BKQ4.2 remain unexplained; this
result points instead at the scalar edge work (avenue 5) as worth
removing, since even the square 1024 tile spends ~0.7% of its products
there at ~16x the cost per flop (roughly 10% of its time, by the model).

## 03-BKQ7: vectorized edge work (Part A, single core)

### BKQ7.1: zero-padded b segments, fused loop over the whole trapezoid

#### Introduction

BKQ6.1's cost model put the remaining scalar work of each 8-row group
(56 ragged-end products plus the fused loop's leftover iterations, ~64
scalar products) at ~10% of the time of a square 1024 tile, and it is
the whole reason narrow tiles are slow. This variant removes that scalar
work from every full row group.

#### Hypothesis

With every product of a full row group done by the vectorized fused loop,
single-core rate at bs=1024 rises by up to ~10% (the model's estimate of
the scalar share, ~20.75 -> ~23 GF/s), and narrow tiles lose most of
their penalty. The cost is 14 extra iterations of zero products per group
(at most 2 vector iterations), ~1.4% at w = 1024.

#### Design

In `03-BKQ7` (copied from BKQ6, block_width knob kept):

- The copies of b are rebuilt as one zero-padded segment per tile column
  J: in copy s, segment J holds seg[s + 7 + x] = b[jj + x] for the
  tile's w = jend - jj columns and zeros elsewhere; each segment is
  whole 64-byte lines (w + 29 floats rounded up to 16), copies spaced a
  multiple of 4096 bytes (+ copy_pad), as before.
- Row r reads through p[r] = seg + s + 7 - r with s = (r + 1) % 4, so
  p[r][u] = b[jj + u - r] inside the tile and 0 outside, and s + 7 - r is
  a multiple of 4 (loads start on 16-byte boundaries, as in BKQ4). The
  copy choice is now fixed per row because every segment starts on a
  64-byte boundary.
- The fused loop covers the whole trapezoid of the group, u = 0 ..
  w + 6, rounded up to a multiple of 8 (so the vector loop has no
  remainder), clamped so k0 + u < n. Products outside the tile are
  a * 0 and leave c unchanged (finite inputs assumed; only zero products
  are cut by the clamp). In the checking build those zero terms still go
  through Kahan: they fold the running compensation into c, which is
  still a valid compensated sum.
- The ragged-end loops and the narrow-tile special case are gone; only
  the leftover rows of the last tile row (height not a multiple of 8)
  stay scalar.
- Each element now receives a tile's products in row order inside one
  loop, a different summation order from BKQ6 in the timed build.

#### Implementation

- Gate PASSED (oracle 0/42, gold 0/14, both checking builds). Scratch
  checking builds with block_width = 1, 5, 8, 24, 40, 64 added to the
  gate tune (as in BKQ6.1): all passed.
- `PolyMult.time` fused loop: one load of b, `vfmadd213ps` with c as
  memory operand, 7 `vfmadd231ps` with b as memory operands, one store of
  c, as before. The first b load is `vmovaps` (GCC treats it as
  32-byte aligned).
- Quick timing, 100K, core 16, 3 reps, median GF/s (BKQ6.1 in brackets):

| height x width | BKQ7  | BKQ6  | ratio |
|----------------|------:|------:|------:|
| 1024 x 1024    | 25.38 (72.1% TPP) | 20.75 | 1.22 |
| 3072 x 3072    | 25.25 | 22.24 | 1.14 |
| 3072 x 256     | 24.80 | 16.05 | 1.55 |
| 3072 x 64      | 21.98 | 8.20  | 2.68 |

- The gain at 1024 x 1024 (22%) is about twice the model's estimate of
  the scalar share; the model underestimated the cost of the edge work
  (or BKQ7 gains something else as well, not identified).

### BKQ7.2: block size sweep and comparison with earlier variants

#### Introduction

BKQ7.1's quick timing showed a 14-22% single-core gain. Removing the
scalar edge work changes what a small block costs (each tile's edge was a
fixed scalar overhead), so BKQ7's best block size may differ from
BKQ3/BKQ4's 1536-4096.

#### Hypothesis

BKQ7 beats BKQ4 at every block size, by most at small blocks (where the
edge work was the largest share), and its rate is nearly flat across
block sizes: without the edge cost, the remaining per-tile overhead is
small, so blocks from ~512 up should be within a few percent of each
other.

#### Design / Experiment

Same block-size set as BKQ3.1/BKQ4.1 at 100K, then every single-core
variant re-timed at its best block size from those sweeps (BKQ6: square
3072, its best width-sweep tile; BKQ5 left out, it was never swept):

```
./sweep.sh --variant-dir 03-BKQ7 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.10.18.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 03-BKQ7 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --tune block_size=256,512,768,1024,1536,2048,3072,4096 \
    --name 2026.10.18.002_bs_sweep_100000x100000
.venv/bin/python plot.py --csv 03-BKQ7/results/2026.10.18.002_bs_sweep_100000x100000.csv \
    --tpp-per-core 35.2 --topic BlockSizeSweep100000x100000 \
    --title "BKQ7 block size sweep, 100000x100000, 1 core"
for cfg in "03-BKQ 3072 008" "03-BKQ2 4096 008" "03-BKQ3 4096 006" \
           "03-BKQ4 1536 009" "03-BKQ6 3072 004" "03-BKQ7 768 003"; do
  set -- $cfg
  ./sweep.sh --variant-dir $1 --dA 100000 --dB 100000 --threads 1 --reps 7 \
      --tune block_size=$2 --name 2026.10.18.$3_best_bs${2}_100000x100000
done
.venv/bin/python plot.py \
    --csv 03-BKQ/results/2026.10.18.008_best_bs3072_100000x100000.csv  --label "BKQ bs=3072" \
    --csv 03-BKQ2/results/2026.10.18.008_best_bs4096_100000x100000.csv --label "BKQ2 bs=4096" \
    --csv 03-BKQ3/results/2026.10.18.006_best_bs4096_100000x100000.csv --label "BKQ3 bs=4096" \
    --csv 03-BKQ4/results/2026.10.18.009_best_bs1536_100000x100000.csv --label "BKQ4 bs=1536" \
    --csv 03-BKQ6/results/2026.10.18.004_best_bs3072_100000x100000.csv --label "BKQ6 bs=3072" \
    --csv 03-BKQ7/results/2026.10.18.003_best_bs768_100000x100000.csv  --label "BKQ7 bs=768" \
    --tpp-per-core 35.2 --topic BKQvariantsBestBlock100000x100000 \
    --title "BK single-core variants at their best block size, 100000x100000"
```

plot.py refuses several CSVs on a block_size axis, so the cross-variant
plot uses fresh one-configuration runs (thread axis, t = 1 only) rather
than the old sweep CSVs.

#### Results

Block-size sweep, median of 7, GF/s (% TPP); BKQ..BKQ4 from their earlier
100K sweeps:

| bs   | BKQ          | BKQ2         | BKQ3         | BKQ4         | BKQ7             |
|-----:|--------------|--------------|--------------|--------------|------------------|
| 256  | 13.13 (37.3) | 14.54 (41.3) | 15.17 (43.1) | 15.90 (45.2) | 24.74 (70.3)     |
| 512  | 13.36 (37.9) | 17.12 (48.6) | 17.90 (50.8) | 18.97 (53.9) | 25.26 (71.8)     |
| 768  | 12.58 (35.7) | 17.70 (50.3) | 18.55 (52.7) | 20.12 (57.2) | **25.39 (72.1)** |
| 1024 | 12.79 (36.3) | 18.81 (53.4) | 19.66 (55.8) | 20.74 (58.9) | 25.38 (72.1)     |
| 1536 | 13.02 (37.0) | 19.10 (54.3) | 20.00 (56.8) | 21.22 (60.3) | 24.77 (70.4)     |
| 2048 | 13.13 (37.3) | 19.60 (55.7) | 20.50 (58.2) | 18.95 (53.8) | 24.89 (70.7)     |
| 3072 | 13.22 (37.6) | 19.90 (56.5) | 20.79 (59.1) | 19.48 (55.3) | 25.25 (71.7)     |
| 4096 | 12.78 (36.3) | 20.00 (56.8) | 20.80 (59.1) | 19.68 (55.9) | 25.33 (71.9)     |

BKQ7 rep spread <= 0.2% at every block size.

- BKQ7 is nearly flat: 24.74-25.39 GF/s (70.3-72.1% TPP) across 256-4096,
  a 2.6% range. 768 and 1024 tie for best (25.39 / 25.38).
- BKQ7 beats BKQ4 at every block size, by 56% at 256 and 22% at 1024,
  shrinking to 17% at 1536, the edge-work trend expected. (BKQ4's
  2048-4096 points are depressed by its dB-dependent copy spacing,
  BKQ4.3; BKQ6, the same kernel with 4096-byte spacing, gives 22.23 at
  3072, so BKQ7's gain there is 14%.)
- A shallow dip at 1536-2048 (~2%) appears in BKQ7 as well; not
  explained.

Best block size, fresh runs (median of 7):

| variant (bs)  | GF/s  | % TPP |
|---------------|------:|------:|
| BKQ (3072)    | 13.22 | 37.6  |
| BKQ2 (4096)   | 19.99 | 56.8  |
| BKQ3 (4096)   | 20.82 | 59.1  |
| BKQ4 (1536)   | 21.24 | 60.3  |
| BKQ6 (3072)   | 22.23 | 63.2  |
| BKQ7 (768)    | 25.40 | 72.2  |

All within 0.1 GF/s of their earlier sweep values.

Plots: `03-BKQ7/plots/2026.10.18.001.BlockSizeSweep100000x100000.xlsx`,
`plots/2026.10.18.006.BKQvariantsBestBlock100000x100000.xlsx`.

#### Conclusion

Supported: BKQ7 is the best single-core variant at every block size, 72.2%
of TPP at its best (bs=768; 1024 ties), and the rate is now almost
independent of block size (2.6% range over 256-4096), which leaves the
block size free to be chosen for the parallel version's load balance and
cache sharing. With 9 loads per 8 FMAs the load port caps the kernel at
~89% of TPP, so ~17 points of headroom remain on one core.

## 03-BKP5: BKP4 schedule + BKQ7 kernel (Part B)

### BKP5.1: block size sweep across threads, best vs BKP4

#### Introduction

BKQ7 raised the single-core kernel from ~59% to ~72% of TPP by doing the
edge work of each row group in the vector loop, and made the rate nearly
independent of block size. BKP4's diagonal-parity schedule scaled almost
linearly at bs=1024 (57-59% of TPP at every thread count). Combining the
two should carry the kernel gain into the parallel result.

#### Hypothesis

BKP5 runs at BKQ7's single-core rate at 1 thread and keeps BKP4's
near-linear scaling, so at 16 threads it reaches ~22% more than BKP4
(327 GF/s -> ~400 GF/s, ~71% of TPP). Since BKQ7's rate is flat across
block sizes, the best block at 16 threads is set by the parallel side:
small enough for load balance and L2 sharing (BKP2.2: large blocks stall
on L2 hits with 4 threads per cluster), large enough to keep the barrier
and diagonal overheads small; most likely 768-1536.

#### Design

In `03-BKP5` (copied from BKP4):

- bkq_tile is BKQ7's tile body: per-tile-column zero-padded segments in
  each of the 4 copies (now 15 leading zeros, seg[s + 15 + x] =
  b[jj + x], segments w + 40 rounded up to 16 floats), row r through
  p[r] = seg + s + 15 - r with s = (r + 1) % 4, fused loop over the
  whole trapezoid; only leftover rows of the last tile row are scalar.
- Race fix specific to the parallel version: BKQ7 pads each group's loop
  with zero products up to a multiple of 8 iterations, past the top of
  the tile's range of c. Adding 0 is still a read-modify-write, and the
  top of a tile's range borders diagonal d + 2, which runs concurrently,
  so BKP5 keeps the padding inside [ii + jj - 1, iend + jend - 2]: the
  extra iterations go above the group's range where there is room
  (every group but the last of a tile) and otherwise one element below
  (diagonal d - 2 ends at ii + jj - 2). Only the last group of each tile
  starts one element early, and its loads are then not 16-byte aligned.
- Schedule unchanged: two parity phases, whole diagonals dealt with
  schedule(dynamic, 1), square tiles.

#### Implementation

- Gate PASSED (oracle 0/42, gold 0/14, both checking builds).
- The race fix was also checked by enumeration (Python, same formulas as
  the C code): for 308 cases (gate sizes, 100K at bs 768/1024, edge
  shapes, 300 random dA, dB in 0..3000 with bs in {8, 16, 24, 64, 100,
  256}), the written range of every diagonal d ends below the start of
  diagonal d + 2; all writes are within [0, dA + dB].
- `PolyMult.time-par`, bkq_tile's fused loop: one load of b,
  `vfmadd213ps` with c as memory operand, 7 `vfmadd231ps`, one store of c
  (8 chained FMAs, one c store).
- 1 thread, 100K, core 16, 3 reps: 25.12 (bs=768), 25.13 (bs=1024) GF/s
  (BKQ7: 25.39 / 25.38, ~1% higher).

#### Experiment

```
./sweep.sh --variant-dir 03-BKP5 --dA 100000 --dB 100000 --threads 1 --reps 7 \
    --name 2026.10.18.001_seq_100000x100000 --record-seq
./sweep.sh --variant-dir 03-BKP5 --dA 100000 --dB 100000 --threads 1:16:1 --reps 5 \
    --tune block_size=256,512,768,1024,1536,2048,3072,4096 \
    --name 2026.10.18.002_threads_x_bs_100000x100000
.venv/bin/python plot.py --csv 03-BKP5/results/2026.10.18.002_threads_x_bs_100000x100000.csv \
    --tpp-per-core 35.2 --topic ThreadsxBlockSize100000x100000 \
    --title "BKP5 (diagonal parity + BKQ7 kernel), threads x block size, 100000x100000"
# best block at 16 threads (512), as a plain thread sweep for the cross-variant plot
./sweep.sh --variant-dir 03-BKP5 --dA 100000 --dB 100000 --threads 1:16:1 --reps 5 \
    --tune block_size=512 --name 2026.10.18.003_threads_bs512_100000x100000
.venv/bin/python plot.py \
    --csv 03-BKP4/results/2026.10.18.002_threads_bs1024_100000x100000.csv --label "BKP4 bs=1024" \
    --csv 03-BKP5/results/2026.10.18.003_threads_bs512_100000x100000.csv --label "BKP5 bs=512" \
    --tpp-per-core 35.2 --topic BKP4vsBKP5bestThreadSweep100000x100000 \
    --title "BKP4 (bs=1024) vs BKP5 (bs=512), best block each, 100000x100000"
```

(plot.py won't overlay a two-axis CSV with another CSV, hence the separate
bs=512 thread sweep.) Recorded untuned T(seq): bs=64.

#### Results

Threads x block size, median of 5, GF/s:

| t  | 256   | 512       | 768   | 1024  | 1536  | 2048  | 3072  | 4096  |
|---:|------:|----------:|------:|------:|------:|------:|------:|------:|
| 1  | 24.4  | 25.1      | 25.1  | 25.1  | 24.6  | 24.6  | 25.1  | 25.2  |
| 2  | 48.1  | 50.1      | 50.0  | 50.1  | 49.0  | 49.2  | 50.0  | 50.2  |
| 4  | 95.3  | 100.0     | 100.0 | 100.3 | 97.9  | 98.4  | 100.0 | 100.4 |
| 6  | 142.7 | 149.9     | 149.3 | 150.0 | 145.7 | 145.9 | 146.0 | 148.6 |
| 8  | 189.8 | 199.9     | 198.7 | 199.9 | 194.4 | 193.8 | 197.5 | 181.7 |
| 10 | 236.9 | 249.1     | 247.8 | 249.3 | 239.7 | 230.8 | 226.3 | 222.8 |
| 12 | 282.8 | 299.0     | 296.1 | 298.3 | 282.9 | 280.7 | 257.1 | 264.6 |
| 14 | 329.8 | 348.1     | 344.4 | 342.3 | 324.4 | 303.4 | 273.7 | 221.1 |
| 16 | 375.8 | **397.4** | 393.9 | 396.9 | 378.7 | 323.2 | 302.4 | 225.9 |

(all 16 thread counts in the CSV and plot). Rep spread <= 3% except at
bs = 3072/4096 for t >= 10 (up to 6.4%).

- 512, 768 and 1024 are within 1% of each other at every thread count
  and scale almost perfectly: bs=512 goes 25.1 -> 397.4 GF/s (15.8x).
- 256 is ~5% lower throughout (also ~3% lower at 1 thread, as in BKQ7).
- Large blocks fall away above ~8 threads: 2048 reaches 323, 3072 302,
  and 4096 drops sharply from 13 threads (265 at 12 -> 217 at 13, flat
  ~225 after). With 100K and bs=4096 there are only 25 x 25 tiles and
  49 diagonals (25 per phase), so 13-16 threads have fewer than two
  diagonals each per phase, and the longest diagonal (25 tiles) is ~8%
  of a phase: likely load imbalance (not measured), on top of the L2
  effect seen in BKP2.2.

Best block (bs=512) vs BKP4's best (bs=1024), median of 5:

| t  | BKP5 bs=512 | BKP4 bs=1024 | ratio | BKP5 % TPP |
|---:|------------:|-------------:|------:|-----------:|
| 1  | 25.1        | 20.7         | 1.21  | 71.3%      |
| 2  | 50.0        | 41.3         | 1.21  | 71.0%      |
| 4  | 100.0       | 82.7         | 1.21  | 71.0%      |
| 8  | 199.6       | 164.6        | 1.21  | 70.9%      |
| 12 | 299.0       | 246.7        | 1.21  | 70.8%      |
| 14 | 347.6       | 282.6        | 1.23  | 70.5%      |
| 16 | **396.6**   | 327.1        | 1.21  | 70.4%      |

- BKP5 is 21-23% faster at every thread count; the per-core rate stays at
  70.4-71.3% of TPP from 1 to 16 threads.
- Rep spread <= 0.4% except t=9 (17.5%, one slow rep; the median is
  unaffected).

Plots: `03-BKP5/plots/2026.10.18.001.ThreadsxBlockSize100000x100000.xlsx`,
`plots/2026.10.18.007.BKP4vsBKP5bestThreadSweep100000x100000.xlsx`.

#### Conclusion

Supported: the BKQ7 kernel carries over intact. BKP5 at bs=512 reaches
396.6-397.4 GF/s at 16 threads (70.4% of TPP, 15.8x its own 1-thread
rate), 21% above BKP4, with near-linear scaling. 512-1024 are equally
good; the parallel side now penalizes only large blocks (>= 2048), so
the remaining gap to TPP is almost entirely the single-core kernel
(~71%; load-port ceiling ~89%).

### BKP5.2: perf profile of BKP5 at bs=512, 1 vs 16 threads

#### Introduction

BKP5 holds 70.4-71.3% of TPP per core from 1 to 16 threads, so almost
all of the gap to TPP is inside the single-core kernel. BKQ4.2 found the
kernel then limited by the load buffer (split loads, L1 misses) with the
FP scheduler full ~30% of slots; BKQ7/BKP5 changed the copies of b and
removed the scalar edges, so the limit needs to be measured again.

#### Hypothesis

The memory side is no longer the limit: L1 misses and split loads are
small (the per-tile-column segments keep each tile's b window small and
aligned), and the FP scheduler is full a larger share of slots than in
BKQ4.2, i.e. the 8-FMA chain latency (and the load port, 9 loads per
8 FMAs) bounds the kernel. 1 and 16 threads show the same profile, since
the per-core rate barely changes.

#### Design

BKP5 `PolyMult.time-par`, 100K, bs=512, 3 reps, bound as in `_gate.sh`,
t = 1 and t = 16, one run at a time. Five counter groups of 5-6 events
(the four BKQ3.2/BKQ4.2 groups plus an L2/alias group from BKP2.2), all
counted 100% of the time (no multiplexing). Script:
`03-BKP5/perf_groups.sh` (`perf_groups.sh <threads> <outdir>`, run from
`03-BKP5`). Counts are user-mode only (`/u`, as perf is set up here) and
summed over threads; they include setup and, at 16 threads, OpenMP
waiting at the barriers.

#### Experiment

```
cd 03-BKP5
./perf_groups.sh 1 <outdir>; ./perf_groups.sh 16 <outdir>
```

Timing during profiling: 25.11-25.19 GF/s (t=1), 391.1-392.2 (t=16),
matching BKP5.1.

#### Results

Per useful vector FMA (3 x 100001^2 / 8 = 3.75e9; the zero-padded
iterations add ~1-2% FMAs that are counted but not useful). Slots =
5 x cycles. BKQ4.2 (100K, bs=1536, 1 core) for comparison.

|                               | BKQ4 1536 | BKP5 t=1 | BKP5 t=16 |
|-------------------------------|----------:|---------:|----------:|
| cycles / FMA (1.0 = TPP)      | 1.654     | 1.393    | 1.426     |
| instructions / FMA            | 2.083     | 1.826    | 1.830     |
| µops issued / FMA             | -         | 3.119    | 3.137     |
| load µops / FMA               | 2.372     | 2.344    | 2.345     |
| split loads / FMA             | 0.065     | 0.009    | 0.009     |
| L1 misses, % of loads         | 9.3%      | 0.20%    | 0.24%     |
| load buffer full, % cycles    | 12.9%     | 0.8%     | 1.3%      |
| L2 requests / FMA             | -         | 0.008    | 0.008     |
| `ld_blocks.address_alias`/FMA | -         | 0.006    | 0.006     |
| Retiring, % slots             | 40.3%     | 44.7%    | 43.9%     |
| Backend bound, % slots        | 55.4%     | 54.3%    | 54.7%     |
| - FP scheduler full           | 30.4%     | 48.3%    | 47.3%     |
| - memory scheduler full       | 23.9%     | 2.0%     | 2.2%      |
| - reorder buffer full         | -         | 3.9%     | 3.9%      |
| Frontend bound, % slots       | 3.0%      | 0.7%     | 1.3%      |
| Serialization, % slots        | -         | 0.0%     | 1.1%      |

- 1.393 cycles per FMA matches the measured 71.3% of TPP (1/1.393 =
  71.8%; the padding FMAs account for the difference).
- The memory side has dropped out: L1 misses 9.3% -> 0.2% of loads,
  split loads -86%, load buffer full 12.9% -> 0.8% of cycles, memory
  scheduler full 23.9% -> 2.0% of slots, L2 traffic negligible.
- The FP scheduler is full 48% of slots, nearly all of the backend-bound
  share: FMAs waiting in the scheduler for their operands. Each output
  vector is a chain of 8 dependent FMAs (6-cycle latency each, 48 cycles
  per chain); at ~1.4 cycles per FMA about 48 / (8 x 1.39) ~ 4.3 chains
  must be in flight, ~35 waiting FMAs, which apparently fills the FP
  scheduler (its size is not documented in what we have; not measured).
- Load port: 2.34 load µops per FMA (each 256-bit load is 2 µops; 9 loads
  per 8 FMAs plus padding). With two 128-bit load pipes that is a floor
  of ~1.17 cycles per FMA (~85% of TPP) for the current loop. The kernel
  is at 1.39, so ~0.22 cycles per FMA (~16%) is lost above that floor.
- 16 threads vs 1: +2.4% cycles per FMA, made up of a little more
  frontend and serialization (OpenMP barrier waiting, 1.1% of slots) and
  load-buffer time; the per-thread profile is otherwise identical.
- Issue is not a limit (3.1 µops per FMA against 5 slots per cycle, 45%
  used); bad speculation 0.2%.

#### Conclusion

Supported: BKP5's kernel is bound by the FMA dependency chains (FP
scheduler full ~48% of slots), not by memory. Two ceilings remain above
it: the load port at ~85% of TPP for 9 loads per 8 FMAs, and FMA
throughput at 100%. Reaching the first needs more independent FMA chains
in flight per output (interleaving, which BKQ5 couldn't get from GCC
without intrinsics, or shorter chains); going past it needs fewer loads
per FMA (b-vector reuse across rows, avenue 2). Threading costs only
~2.4%.

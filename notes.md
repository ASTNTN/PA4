# PA2

## 01 GSP1

### Initial Test

NOTES: originally represented as OPP1, but actually implemented as GSP

#### Introduction

Parallelizing the GSQ implementation will allow us to test how well it scales.

#### Design

Parallelized GSQ with round-robin scheduling on the outer loop, such that the outer loop determines the written-to index and the inner loop derives the read-from indices.

Sweep was run with dA=dB=2000 averaged across 5 runs, expectation for near-perfect speedup.

#### Results

`2026.09.20.001.GSP12000x2000124thr.xlsx`

Speedup was near-perfect up to 15 threads, then dropped off to an abrupd negative speedup delta, then gradual increase.

#### Conclusion

This drop could be due to context switching between threads once we saturate the 16 physical E-cores with threads.

### Overriding the core limits

#### Introduction

Overriding the default cores should allow for a perfect speedup all the way through 32 threads.

#### Design

Claude overrode the default core limits, using 1 thread per P-core and then one thread per E-core.

- `BPM_CORESET=0-31`
- `BPM_OMP_PLACES='{0},{2},{4},{6},{8},{10},{12},{14},{16},{20},{24},{28},{17},{21},{25},{29},{18},{22},{26},{30},{19},{23},{27},{31}'`

#### Results

`2026.09.20.002.GSP1PthenE2000x2000.xlsx`

In this case we see two regimes of near-perfect linear trends. When we use P-cores, we get a speedup trend approximately double that we get with E-cores.

#### Conclusion

Because our baseline is using a P-core, this makes sense, and indicates that we are getting virtually perfect speedup for P-cores, then virtually perfect speedup for additional E-cores, but seeing a comparatively worse result for the E-cores because the baseline is higher.

We will use only E-cores, and ranges of 1-16 threads, going forward.

## 01 OPQ

Claude wrote an implementation of OPQ and it passed the gate check.

### OPP1

Trying to parallelize the inner loop with round-robin scheduling. This should afford some speedup, but it will likely be far from perfect because the thread pool is created and destroyed every time the outer loop iterates.

#### Design

Added schedule(static, 1) clause to internal loop.

#### Results

`2026.09.20.001.OPP1x2000x2000x116thr.xlsx`

Speedup is negative as thread count increases

#### Conclusions

Thread overhead may be dominating in a more significant way than expected.

### OPP11

#### Introduction

Is there a way to reuse threads between outer-loop iterations, so we don't pay the cost of recreating the thread pool?

#### Hypothesis

There's no contents to the outer loop other than the inner loop, so splitting the parallel from the for may allow us to keep threads alive between iterations. I believe that this will allow us to see a positive relationship between thread count and speedup.

#### Design

Claude split the parallel clause from the for clause, keepin the for in the inner loop and moving the parallel to the outer loop.

#### Results

Very marginal increase in speedup, but not substantial enough to warrant further development.

Taking a look at the total runtime vs thread count, we get a roughly linear relationship, indicating that each additional thread is incurring a constant overhead instead of spreading the total work.

#### Conclusions

The curve moves from worse than 1/p to approximately 1/p, indicating that some improvement was made, but that the program is effectively running on a single thread.

The cost of creating threads is not dominating for this parallelization.

### OPP12

#### Introduction

If multiple threads have sequential j values, they will be writing within the same cache line, causing false sharing.

`getconf LEVEL1_DCACHE_LINESIZE` tells us that our cache size is 64, a common size.

To test this, we will switch the schedule from a chunk size of 1 to 64, so a single thread will fill out a cache line.

#### Hypothesis

I hypothesize that increasing our chunk size to 64 will allow individual threads to write to independent caches and avoid false sharing, letting parallelism occur and bringing speedup to a positive slope.

#### Design

Derived from OPP11, changed chunk size to 64

#### Results

We now see near-flat speedup, indicating that the program is taking approximately the same amount of time regardless of thread count.

Despite the fact that speedup is flat, the total amount of work relative to TPP declines with thread count, indicating that each thread is doing less work.

### OPP13

#### Introduction

If cache-sharing is still having any effect, we may be able to reduce that by using normal static sharing to keep threads in control of larger contiguous portions of memory.

#### Design

Based on OPP12, replace `schedule(static, 64)` with `schedule(static)`

#### Results

We see a brief positive curve for thread counts under four, which then declines again, even beyond `schedule(static, 64)`.

#### Conclusion

This indicates that the kernel benefits from static scheduling more at lower thread counts, when large portions of work can be spread between threads with small contention zones, and less at large counts with more contention zones. We will revert to `schedule(static, 64)` for now.

### OPP14

#### Introduction

I had Claude instrument the program to test how many iterations each thread was performing; threads are sharing the workload.

#### Hypothesis

The program appears to never exceed single-threaded performance because the work is not being properly allocated between threads

#### Design

Instrumented each thread to print the number of iterations it had performed, along with it's identity and the total thread number.

#### Results

```
OPP14 thread 0/1 iters=4004001
OPP14 thread 0/2 iters=2002001
OPP14 thread 1/2 iters=2002000
OPP14 thread 0/3 iters=1334672
OPP14 thread 1/3 iters=1334672
OPP14 thread 2/3 iters=1334657
OPP14 thread 0/4 iters=1001008
OPP14 thread 1/4 iters=1001008
OPP14 thread 2/4 iters=1000993
OPP14 thread 3/4 iters=1000992
OPP14 thread 0/5 iters=800801
OPP14 thread 2/5 iters=800800
OPP14 thread 1/5 iters=800800
OPP14 thread 3/5 iters=800800
OPP14 thread 4/5 iters=800800
OPP14 thread 0/6 iters=667344
OPP14 thread 3/6 iters=667328
OPP14 thread 2/6 iters=667329
OPP14 thread 1/6 iters=667344
OPP14 thread 4/6 iters=667328
OPP14 thread 5/6 iters=667328
OPP14 thread 0/7 iters=572001
OPP14 thread 3/7 iters=572000
OPP14 thread 2/7 iters=572000
OPP14 thread 1/7 iters=572000
OPP14 thread 4/7 iters=572000
OPP14 thread 5/7 iters=572000
OPP14 thread 6/7 iters=572000
OPP14 thread 0/8 iters=500512
OPP14 thread 3/8 iters=500496
OPP14 thread 2/8 iters=500497
OPP14 thread 1/8 iters=500512
OPP14 thread 4/8 iters=500496
OPP14 thread 5/8 iters=500496
OPP14 thread 6/8 iters=500496
OPP14 thread 7/8 iters=500496
OPP14 thread 0/9 iters=444896
OPP14 thread 4/9 iters=444896
OPP14 thread 3/9 iters=444896
OPP14 thread 2/9 iters=444896
OPP14 thread 1/9 iters=444896
OPP14 thread 6/9 iters=444880
OPP14 thread 5/9 iters=444881
OPP14 thread 7/9 iters=444880
OPP14 thread 8/9 iters=444880
OPP14 thread 0/10 iters=400401
OPP14 thread 4/10 iters=400400
OPP14 thread 3/10 iters=400400
OPP14 thread 2/10 iters=400400
OPP14 thread 1/10 iters=400400
OPP14 thread 7/10 iters=400400
OPP14 thread 6/10 iters=400400
OPP14 thread 5/10 iters=400400
OPP14 thread 8/10 iters=400400
OPP14 thread 9/10 iters=400400
OPP14 thread 0/11 iters=364001
OPP14 thread 4/11 iters=364000
OPP14 thread 3/11 iters=364000
OPP14 thread 2/11 iters=364000
OPP14 thread 1/11 iters=364000
OPP14 thread 7/11 iters=364000
OPP14 thread 6/11 iters=364000
OPP14 thread 5/11 iters=364000
OPP14 thread 8/11 iters=364000
OPP14 thread 9/11 iters=364000
OPP14 thread 10/11 iters=364000
OPP14 thread 0/12 iters=333680
OPP14 thread 4/12 iters=333664
OPP14 thread 3/12 iters=333664
OPP14 thread 2/12 iters=333665
OPP14 thread 1/12 iters=333680
OPP14 thread 7/12 iters=333664
OPP14 thread 6/12 iters=333664
OPP14 thread 5/12 iters=333664
OPP14 thread 8/12 iters=333664
OPP14 thread 9/12 iters=333664
OPP14 thread 10/12 iters=333664
OPP14 thread 11/12 iters=333664
OPP14 thread 0/13 iters=308001
OPP14 thread 8/13 iters=308000
OPP14 thread 4/13 iters=308000
OPP14 thread 3/13 iters=308000
OPP14 thread 2/13 iters=308000
OPP14 thread 1/13 iters=308000
OPP14 thread 10/13 iters=308000
OPP14 thread 9/13 iters=308000
OPP14 thread 7/13 iters=308000
OPP14 thread 6/13 iters=308000
OPP14 thread 5/13 iters=308000
OPP14 thread 11/13 iters=308000
OPP14 thread 12/13 iters=308000
OPP14 thread 0/14 iters=286001
OPP14 thread 8/14 iters=286000
OPP14 thread 4/14 iters=286000
OPP14 thread 3/14 iters=286000
OPP14 thread 2/14 iters=286000
OPP14 thread 1/14 iters=286000
OPP14 thread 11/14 iters=286000
OPP14 thread 10/14 iters=286000
OPP14 thread 9/14 iters=286000
OPP14 thread 7/14 iters=286000
OPP14 thread 6/14 iters=286000
OPP14 thread 5/14 iters=286000
OPP14 thread 12/14 iters=286000
OPP14 thread 13/14 iters=286000
OPP14 thread 0/15 iters=266944
OPP14 thread 8/15 iters=266928
OPP14 thread 4/15 iters=266944
OPP14 thread 3/15 iters=266944
OPP14 thread 2/15 iters=266944
OPP14 thread 1/15 iters=266944
OPP14 thread 11/15 iters=266928
OPP14 thread 10/15 iters=266928
OPP14 thread 9/15 iters=266928
OPP14 thread 7/15 iters=266928
OPP14 thread 6/15 iters=266928
OPP14 thread 5/15 iters=266929
OPP14 thread 12/15 iters=266928
OPP14 thread 13/15 iters=266928
OPP14 thread 0/16 iters=250256
OPP14 thread 14/15 iters=266928
OPP14 thread 1/16 iters=250256
OPP14 thread 2/16 iters=250256
OPP14 thread 3/16 iters=250256
OPP14 thread 4/16 iters=250256
OPP14 thread 5/16 iters=250256
OPP14 thread 6/16 iters=250256
OPP14 thread 7/16 iters=250256
OPP14 thread 8/16 iters=250256
OPP14 thread 9/16 iters=250256
OPP14 thread 10/16 iters=250241
OPP14 thread 11/16 iters=250240
OPP14 thread 12/16 iters=250240
OPP14 thread 13/16 iters=250240
OPP14 thread 14/16 iters=250240
OPP14 thread 15/16 iters=250240
```

#### Conclusion

We can see that the work is being evenly divided between threads, so some other effect must be causing our constant runtime.

### OPP15

I'm seeing `OMP: Warning #124: Ignoring invalid OS proc ID 20` when I run sweep manually. It appears that this is a consequence of `-lomp`, so let's remove that.

#### Design

Remove the `-lomp` flag from our makefile

#### Results

For the first time, we see positive speedup with respect to core count, sublinear but very positive. The deviation between optimal speedup and actual speedup might be representative of some overhead that grows with core counts; that could be either scheduling overhead (unlikely) or interference between threads.

#### Conclusions

By linking `-lomp`, we were barring all cores from 17 to 31 from being used in our program (considered invalid targets), leaving us with one core to serve all of our threads.

### OPP16

#### Introduction

It looks like we're suffering from sublinear speedup scaling. Copy OPP15 to a new OPP16 directory, and change the scheduling from static to round robin with a chunk size of sizeof(int) / 64.

By using round-robin allocation, we may be able to reduce what appears to be overhead per-thread from some threads getting more work than others. The fact that larger work sets have less fallof supports this idea

#### Hypothesis

I believe that using round-robin scheduling will reduce the imbalance between threads, resulting in linear speedup. If we instead allocate round-robin on chunk sizes aligned to cache boundaries, we may see that imbalance disappear.

#### Design

Used `schedule(static, 64/sizeof(int))`

#### Results

┌─────────────┬───────────────┬────────────────┬───────────────┐
│   Threads   │   1000×4000   │   8000×2000    │  16000×1000   │
├─────────────┼───────────────┼────────────────┼───────────────┤
│ 1           │ 12.73 (1.00)  │ 13.01 (1.00)   │ 12.59 (1.00)  │
├─────────────┼───────────────┼────────────────┼───────────────┤
│ 2           │ 24.79 (1.95)  │ 25.80 (1.98)   │ 24.59 (1.95)  │
├─────────────┼───────────────┼────────────────┼───────────────┤
│ 4           │ 47.08 (3.70)  │ 50.00 (3.84)   │ 47.22 (3.75)  │
├─────────────┼───────────────┼────────────────┼───────────────┤
│ 8           │ 80.79 (6.35)  │ 91.09 (7.00)   │ 84.86 (6.74)  │
├─────────────┼───────────────┼────────────────┼───────────────┤
│ 12          │ 95.61 (7.51)  │ 124.80 (9.59)  │ 108.58 (8.62) │
├─────────────┼───────────────┼────────────────┼───────────────┤
│ 16          │ 103.71 (8.15) │ 144.05 (11.07) │ 119.59 (9.50) │
├─────────────┼───────────────┼────────────────┼───────────────┤
│ % TPP at 16 │ 18.4%         │ 25.6%          │ 21.2%         │
└─────────────┴───────────────┴────────────────┴───────────────┘

Comparison at 16 threads, GFLOPs/s:

┌───────────┬────────────────┬────────────────┬─────────────────┐
│   Size    │ OPP15 (static) │ OPP16, chunk 0 │ OPP16, chunk 16 │
├───────────┼────────────────┼────────────────┼─────────────────┤
│ 8000×2000 │ 143.53         │ 145.41         │ 144.05          │
├───────────┼────────────────┼────────────────┼─────────────────┤
│ 1000×4000 │ 98.22          │ 105.05         │ 103.71          │
└───────────┴────────────────┴────────────────┴─────────────────┘

Observations:
- Chunk 16 gives results very close to the zero-chunk runs and to OPP15, all within a few percent.
- Speedup is still sublinear at all three sizes (8.2×, 11.1× and 9.5× at 16 threads).
- The new 16000×1000 size scales between the other two.

#### Conclusions

Performance is comparable to OPP15, but slightly lower

### OPP17

#### Introduction

Dynamic scheduling may more efficiently allocate threads, but I doubt it.

#### Hypothesis

Using dynamic scheduling is likely to exacerbate the overhead issues, resulting is a less-linear curve than for OPP15,16.

#### Design

Used `schedule(dynamic, 64/sizeof(int))`

#### Results

┌─────────────┬──────────────┬────────────────┬───────────────┐
│   Threads   │  1000×4000   │   8000×2000    │  16000×1000   │
├─────────────┼──────────────┼────────────────┼───────────────┤
│ 1           │ 12.63 (1.00) │ 12.97 (1.00)   │ 12.52 (1.00)  │
├─────────────┼──────────────┼────────────────┼───────────────┤
│ 2           │ 24.65 (1.95) │ 25.37 (1.96)   │ 24.07 (1.92)  │
├─────────────┼──────────────┼────────────────┼───────────────┤
│ 4           │ 46.56 (3.69) │ 49.03 (3.78)   │ 45.52 (3.64)  │
├─────────────┼──────────────┼────────────────┼───────────────┤
│ 8           │ 77.73 (6.15) │ 89.89 (6.93)   │ 81.84 (6.54)  │
├─────────────┼──────────────┼────────────────┼───────────────┤
│ 12          │ 90.61 (7.17) │ 121.43 (9.36)  │ 106.33 (8.49) │
├─────────────┼──────────────┼────────────────┼───────────────┤
│ 16          │ 97.64 (7.73) │ 140.71 (10.85) │ 117.30 (9.37) │
├─────────────┼──────────────┼────────────────┼───────────────┤
│ % TPP at 16 │ 17.3%        │ 25.0%          │ 20.8%         │
└─────────────┴──────────────┴────────────────┴───────────────┘

Against OPP16 (static, chunk 16) at 16 threads, GFLOPs/s:

┌────────────┬──────────────┬───────────────┬────────────┐
│    Size    │ OPP16 static │ OPP17 dynamic │ Difference │
├────────────┼──────────────┼───────────────┼────────────┤
│ 1000×4000  │ 103.71       │ 97.64         │ −5.9%      │
├────────────┼──────────────┼───────────────┼────────────┤
│ 8000×2000  │ 144.05       │ 140.71        │ −2.3%      │
├────────────┼──────────────┼───────────────┼────────────┤
│ 16000×1000 │ 119.59       │ 117.30        │ −1.9%      │
└────────────┴──────────────┴───────────────┴────────────┘

Observations:
- OPP17 is slightly slower than the static version at 16 threads at every size, by 2 to 6%. At 4 and 8 threads it's also lower at each size, by about 1 to 4%.
- Speedup is still sublinear, at 7.7×, 10.9× and 9.4× at 16 threads.
- I haven't measured run-to-run spread for these builds, so I can't say which of these differences are outside noise.

#### Conclusions

Performance is comparable to OPP15 and OPP16, but slightly lower.

### OPP19

#### Introduction

Perhaps we can reduce contention overhead by only parallelizing the inner loop, because different threads will no longer be able to write to nearby locations.

#### Hypothesis

I expect that we will see a pure linear speedup curve by only linearizing the inner loop

### OPP110

#### Introduction

Removing the reduction on the outer loop may improve performance

#### Design

Copy OPP15 with no reduction. Sweep with 5 reps, 8000x2000 and 1000x4000

#### Results

#### Conclusions

#### Design

### OPP2

#### Introduction

We will attempt to get TPP on a single core.

Claude inspected the build, finding that the outer loop couldn't be vectorized, that the inner j loop was vectorized using 32-byte vectors, and that the BPM_ACC was not vectorized because of a possible dependence between data-refs *_8 and *_8.

#### Hypothesis

Moderate parallelism

#### Design

Building the same OPQ setup to get an initial TPP baseline.

Used:
- dA = 1000, dB = 4000, reps = 5 for the first set
- dA = 8000, dB = 2000, reps = 5 for the second set

### OPP16.2

Getting perf data from OPP16

#### Results

Level 1, % of pipeline slots:

┌──────┬──────────┬─────────────────┬───────────────┬────────────────┐
│      │ Retiring │ Bad speculation │ Backend bound │ Frontend bound │
├──────┼──────────┼─────────────────┼───────────────┼────────────────┤
│ t=1  │ 66.3     │ 4.4             │ 21.3          │ 7.9            │
├──────┼──────────┼─────────────────┼───────────────┼────────────────┤
│ t=16 │ 43.3     │ 2.8             │ 37.4          │ 16.5           │
└──────┴──────────┴─────────────────┴───────────────┴────────────────┘

Level 2:

┌──────┬────────────┬────────────────┬────────────────────┬────────────────┬──────────────────┬────────────────┐
│      │ Core bound │ Resource bound │ Branch mispredicts │ Ifetch latency │ Ifetch bandwidth │ Machine clears │
├──────┼────────────┼────────────────┼────────────────────┼────────────────┼──────────────────┼────────────────┤
│ t=1  │ 0.1        │ 21.8           │ 4.5                │ 0.5            │ 7.4              │ 0.0            │
├──────┼────────────┼────────────────┼────────────────────┼────────────────┼──────────────────┼────────────────┤
│ t=16 │ 0.9        │ 37.0           │ 2.3                │ 0.5            │ 16.0             │ 0.1            │
└──────┴────────────┴────────────────┴────────────────────┴────────────────┴──────────────────┴────────────────┘

Observations:
- The t=1 numbers match the earlier 01-OPP21 run at 1 thread (retiring about 66%, resource bound about 22%, core bound about 0.1%), even though this is a different variant.
- Going from 1 to 16 threads, the retiring share falls by about 23 points. Resource bound rises by about 15 points and ifetch bandwidth roughly doubles. Core bound stays under 1%.
- Bad speculation and machine clears don't move much.

#### Conclusion

The fact that we see both backend-bound and resource-bound proportions rising substantially for higher thread counts indicates that contention for writing to addresses on the same cache line is causing our overhead.

### OPP2

#### Introduction

Testing the baseline proportion of TPP for OPQ.

#### Results

┌───────────┬──────────────┬──────────┬──────────┬───────┐
│    Run    │ Work (flops) │  Median  │ GFLOPs/s │ % TPP │
├───────────┼──────────────┼──────────┼──────────┼───────┤
│ 1000×4000 │ 8.0M         │ 0.629 ms │ 12.73    │ 36.2% │
├───────────┼──────────────┼──────────┼──────────┼───────┤
│ 8000×2000 │ 32.0M        │ 2.455 ms │ 13.04    │ 37.0% │
└───────────┴──────────────┴──────────┴──────────┴───────┘

Claude disassembled the resulting assembly to see what actually got vectorized.

The hot loop (offsets 0x98–0xaf):
```
98: vmovups    ymm0, [rbx+rdx]       
9d: vfmadd213ps ymm0, ymm2, [rax+rdx] ; ymm0 = b*a[i] + c[i+j..], c loaded from memory as part of the FMA
a3: vmovups    [rax+rdx], ymm0        ; store 8 floats to c[i+j..]
a8: add rdx,0x20 / cmp / jne
```

- Vectorization: The inner j loop is vectorized 8 wide with 256-bit ymm registers and a real vfmadd213ps. It isn't a scalar loop wearing a vector label, which is the failure VectorizationPitfalls.md warns about.
- Broadcast: a[i] is broadcast once per outer iteration (vbroadcastss ymm2 at 0x83), then reused across the whole j loop.
- Per iteration: One 8-lane FMA is accompanied by two loads (b and c) and one store (c). The loop isn't unrolled, so each trip does exactly one FMA.
- Alignment: The accesses are vmovups, the unaligned form. rax advances by 4 bytes per outer iteration (0x166), so the base of the c access shifts by one float every i. I haven't measured whether that causes cache-line-split accesses. It's something you could look into.

#### Conclusion

Both sets achieved approximately 37% of TPP, which is far better than the 2.1% of TPP for default GSQ.

### OPP21

#### Introduction

Seeing if aligned accesses will improve the efficiency of `vmovups`.

#### Design

Compiling with `BPM_ALIGN=64`

#### Results

┌───────────┬─────────────────────────┬─────────────────────────┐
│   Size    │          OPP2           │          OPP21          │
├───────────┼─────────────────────────┼─────────────────────────┤
│ 1000×4000 │ 0.629 ms, 12.73 (36.2%) │ 0.634 ms, 12.64 (35.9%) │
├───────────┼─────────────────────────┼─────────────────────────┤
│ 8000×2000 │ 2.455 ms, 13.04 (37.0%) │ 2.454 ms, 13.05 (37.1%) │
└───────────┴─────────────────────────┴─────────────────────────┘

#### Conclusions

Results are virtually indistinguishable from OPP2 without explicit alignment.

Our assembly is indicating that the hot loop has one FMA, two loads and one store per 8 lanes. This works out to 2 loads per FMA, which is 

### OPP21.1

#### Introduction

Use perf on OPP21 to check if we are getting any cache misses.

#### Hypothesis

I'm expecting that the j-index accesses will be very regular and predictable to the CPU, so the cache miss rate will be very low (should be well under 1%)

If I'm wrong we may be able to reconstruct the accesses to lower that miss rate.

#### Design

Tested using 8000x2000 with 5 reps, using L1-dcache-load-misses and --topdown.

#### Results

Run 1: L1-dcache-load-misses
- The event returned <not supported> on cpu_atom, so there's no miss rate from it.
- L1-dcache-loads did count: 40,409,296 loads over the whole process, 5 reps included.
- Data I can't explain: I expected roughly 20 million vector loads from the hot loop over 5 reps (about 2M loop trips per rep, two loads each). The counter reads about twice that. I don't know whether this event counts stores, counts each load differently, or includes the harness setup. It's a surprise, so treat the raw number cautiously.

Run 2: --topdown

┌─────────────────┬────────────┐
│    Category     │ % of slots │
├─────────────────┼────────────┤
│ Retiring        │ 66.6       │
├─────────────────┼────────────┤
│ Backend bound   │ 21.4       │
├─────────────────┼────────────┤
│ Frontend bound  │ 7.9        │
├─────────────────┼────────────┤
│ Bad speculation │ 4.1        │
└─────────────────┴────────────┘

Retiring is the largest category. This is the whole process, so malloc, fill_random and the harness output are in there too.

Available alternatives. The perf list output shows other events, including mem_load_uops_retired.l1_hit and mem_load_uops_retired.l1_miss. They count load uops that hit or miss in the L1 data cache, so a miss rate could be computed from that pair. I haven't run them. Whether to run them is your decision, and it would need its own go-ahead.

Subsequent experiment: deriving cache misses:

┌───────────────────────────────┬────────────┐
│             Event             │   Count    │
├───────────────────────────────┼────────────┤
│ mem_load_uops_retired.l1_hit  │ 40,388,614 │
├───────────────────────────────┼────────────┤
│ mem_load_uops_retired.l1_miss │ 22,017     │
└───────────────────────────────┴────────────┘

Miss rate = misses ÷ (hits + misses) = 22,017 ÷ 40,410,631 ≈ 0.054%, well under the 1% you expected.

- Consistency with the earlier count: Hits plus misses come to 40,410,631, against the 40,409,296 L1-dcache-loads from the first run. The two events agree.
- Scope: These are whole-process counts. The harness setup (malloc and fill_random) and the 5 reps' output are included, so I can't separate the kernel's misses from the rest. At about 22 thousand misses in total, it's hard to say how many belong to the kernel.
- Still unexplained: The total is again about twice my estimate of about 20 million vector loads from the hot loop. My estimate could be off, or the event may count more than the vector loads. This run doesn't resolve it.

Subsequent experiment: backend breakdown


Level 2 breakdown, % of pipeline slots:

┌────────────────────────┬──────┐
│         Metric         │  %   │
├────────────────────────┼──────┤
│ tma_core_bound         │ 0.1  │
├────────────────────────┼──────┤
│ tma_resource_bound     │ 22.0 │
├────────────────────────┼──────┤
│ tma_branch_mispredicts │ 4.1  │
├────────────────────────┼──────┤
│ tma_ifetch_bandwidth   │ 7.7  │
├────────────────────────┼──────┤
│ tma_ifetch_latency     │ 0.2  │
├────────────────────────┼──────┤
│ tma_machine_clears     │ 0.0  │
└────────────────────────┴──────┘


The level-1 run gave backend bound = 21.4%. The two backend-bound components here, core bound and resource bound, add up to about 22.1%, which fits with it. The two runs are separate measurements, so I wouldn't read anything into the 0.7-point difference. Retiring isn't broken down at this level.

Reading it per Procinfo3.md §1.D:
- Core bound is 0.1%, which per §1.D means the execution ports weren't the constraint. That makes it hard to attribute the gap to a lack of independent work or busy ports.
- Resource bound is 22.0%. §1.D describes this as some other limited resource being full, usually in the memory pipeline, while the ports had room to spare.
- §2.B and §2.C describe one such case: a high volume of loads and stores cycling through the fixed-size load and store queues can constrain throughput even when nearly everything hits in L1. That fits the 0.054% miss rate we measured, but I haven't measured queue occupancy, so I'm not saying it's the cause here.

#### Conclusion

The access is regular enough that cache misses are virtually a non-factor. Other effects must be causing us to see limited performance.

### OPP2*

#### Introduction

We will use PAPI to get more focused hardware information from just the kernel

#### Conclusion

PAPI cannot read hardware counters because the perf_event component is disabled. This line of inquiry cannot be carried out.

### OPP22

#### Introduction

The current hot loop is using 2 loads, 1 FMA, and 1 store per iteration. We will remove that store to see if throughput increases. If throughput does improve substantially, that indicates that we are being held back from TPP by the writes in the loop.

#### Hypothesis

We know that two loads can be executed concurrently for a single FMA, but nothing about stores. I believe that replacing the store with a NOP will bring performance up to ~100% of TPP because a full loop iteration's work can be scheduled within a single cycle.

#### Design

Replaced

```asm
 vmovups YMMWORD PTR [rax+rdx], ymm0, 
```

with

```asm
.byte	0x0f, 0x1f, 0x44, 0x00, 0x00
```

a same-sized 5 byte NOP.

To test the timing, we ran a sweep with --allow-gate-failure.

```
· What should the two root-level variant directories be called (original store, and NOP-for-store)? → 01-OPP22A / 01-OPP22B
· Which problem sizes (dA x dB) should the sweep use? → 1000x4000 and 8000x2000
· Which thread range? The assembly has no OpenMP directives, so more threads wouldn't parallelize anything. → 1 only
· How many repetitions per configuration? → 5
```

#### Results

Timing (median of 5, single thread, GFLOPs/s):

┌───────────┬─────────────────┬───────────────────────┬──────────────────────┐
│   Size    │ OPP2 (C source) │ OPP22A (original asm) │ OPP22B (store → NOP) │
├───────────┼─────────────────┼───────────────────────┼──────────────────────┤
│ 1000×4000 │ 12.73           │ 12.69 (0.631 ms)      │ 14.23 (0.563 ms)     │
├───────────┼─────────────────┼───────────────────────┼──────────────────────┤
│ 8000×2000 │ 13.04           │ 12.98 (2.466 ms)      │ 14.25 (2.246 ms)     │
└───────────┴─────────────────┴───────────────────────┴──────────────────────┘

- Removing the store gives about 12% more throughput at 1000×4000 and about 10% at 8000×2000.
- The 5 repetitions in each run are tight, within about 1-2% of the median.
- OPP22A matches OPP2's numbers, so the assembly copy behaves like the original compiled kernel.

Perf analysis:

I ran perf on both variants: 8000×2000, 5 reps, 1 thread, pinned to core 16. That is the same setup as your OPP21.1 topdown runs. I used top-down level 1 and level 2 only (perf stat --topdown, then -M tma_…). Each configuration ran once, one at a time, and there is no run-to-run spread.

Level 1, % of pipeline slots (whole-process counts, so harness setup is included):

┌─────────────────────────┬─────────────────────────────────┬─────────────────┬───────────────┬────────────────┐
│                         │            Retiring             │ Bad speculation │ Backend bound │ Frontend bound │
├─────────────────────────┼─────────────────────────────────┼─────────────────┼───────────────┼────────────────┤
│ OPP22A (original store) │ 72.3 (first run), 71.2 (second) │ −3.2, −2.9      │ 22.2, 23.1    │ 8.6, 8.6       │
├─────────────────────────┼─────────────────────────────────┼─────────────────┼───────────────┼────────────────┤
│ OPP22B (store → NOP)    │ 61.0                            │ 6.1             │ 25.8          │ 7.0            │
└─────────────────────────┴─────────────────────────────────┴─────────────────┴───────────────┴────────────────┘

I ran A twice, and its two runs agree to about one point. B ran once in this comparison.

Level 2:

┌────────┬────────────┬────────────────┬────────────────────┬────────────────┬──────────────────┬────────────────┐
│        │ Core bound │ Resource bound │ Branch mispredicts │ Ifetch latency │ Ifetch bandwidth │ Machine clears │
├────────┼────────────┼────────────────┼────────────────────┼────────────────┼──────────────────┼────────────────┤
│ OPP22A │ 0.0        │ 20.3           │ 3.7                │ 0.1            │ 7.7              │ 0.0            │
├────────┼────────────┼────────────────┼────────────────────┼────────────────┼──────────────────┼────────────────┤
│ OPP22B │ 0.0        │ 23.6           │ 4.0                │ 0.1            │ 6.0              │ 0.1            │
└────────┴────────────┴────────────────┴────────────────────┴────────────────┴──────────────────┴────────────────┘

What the numbers show
- A dominates: retiring is about 71-72% and backend bound is about 22-23%. Within the backend share, resource bound is 20.3 points and core bound is 0.0. This is the same picture as OPP21.1.
- What changes in B:
  - Retiring drops about 10 points, to 61%.
  - Backend bound rises about 3 points and resource bound about 3 points.
  - Bad speculation goes from −3 to +6, and ifetch bandwidth falls by about 1.7 points.
- Resource bound doesn't fall: removing the store didn't lower it, which fits a load-side limit. That is only a reading of these numbers.

Surprises
- Negative bad speculation in A: the −3.2 and −2.9 values are physically impossible as a share of slots. Both A runs show it, and B doesn't. I don't know the cause. Possibly the hybrid-CPU counter multiplexing shows through, since the level-2 event groups were sampled for only 13-29% of the run.
- Retiring is not speed: B retires fewer slots yet runs about 10-12% faster in the sweeps. Retiring is a share of slots, not a count of work done. The NOP is a retired instruction that does nothing useful, and I haven't compared instruction counts.


#### Conclusions

The store is not being scheduled within the same cycle as an FMA operation, resulting in an additional 10-12% overhead per cycle.

Because this is a sequential implementation, this is not a side-effect of reducing cache interference effects - the store itself is adding that time.

This format, while not doing any useful work, does bring us up to ~40.5% of TPP, a 3% to 4% gain.

However, this still leaves a little under 60% of TPP on the table, which must be coming from another source.

## 02 EXQ

Claude wrote an implementation of EXQ and it passed the gate check.

### EXP1

Baseline parallel implementation of EXQ using the same pragmas as OPP15.

#### Hypothesis

I expect that we will see similar behavior to OPP.

#### Design

Using an outer parallel for with reduction and static scheduling.

#### Results

We see a slightly worse sublinear speedup than with OPP15, our best OPP implementation.

#### Conclusion

Access patterns may be slightly different in this case.

### EXP12

#### Introduction

The correctness gate rejects a lot of scheduling algorithms for outer parallelization, so we will return to inner parallelization and see where we can work from there

#### Hypothesis

From experience with OPP, I expect that inner parallelization will result in speedup remaining constant at 1.

#### Design

Moved parallelization to inner loop, used static scheduling with chunk size of 16

#### Results

Roughly constant speedup at 1 regardless of thread count.

#### Conclusion

Hypothesis confirmed. The fact that we see a decreasing speedup with increasing core count indicates that it is not the `-lomp` that caused our slowdown for OPP1; it was using inner loop parallelization at all.

### 02 EXP2

We are using our EXQ unaltered for these tests, which are already generating the same vectorized instructions as OPP2.

Our purpose here is not to find a more optimal implementation of EXQ, but to diagnose what is holding it back from TPP.

```
> taskset -c 16 perf stat ./PolyMult.time -dA 80000 -dB 80000 -t 1 -r 3
variant,dA,dB,threads,build_params,rep,seconds,gflops
EXQ,80000,80000,1,"",0,1.511166614,8.470
EXQ,80000,80000,1,"",1,1.411182049,9.071
EXQ,80000,80000,1,"",2,1.366360140,9.368

 Performance counter stats for './PolyMult.time -dA 80000 -dB 80000 -t 1 -r 3':

          4,293.56 msec task-clock:HGu                   #    1.000 CPUs utilized             
                 0      context-switches:HGu             #    0.000 /sec                      
                 0      cpu-migrations:HGu               #    0.000 /sec                      
               384      page-faults:HGu                  #   89.436 /sec                      
     9,358,501,368      cpu_atom/cycles/:HGu             #    2.180 GHz                         (49.97%)
     <not counted>      cpu_core/cycles/:HGu                                                    (0.00%)
    14,429,567,879      cpu_atom/instructions/:HGu       #    1.54  insn per cycle              (58.31%)
     <not counted>      cpu_core/instructions/:HGu                                              (0.00%)
     2,404,601,141      cpu_atom/branches/:HGu           #  560.049 M/sec                       (58.31%)
     <not counted>      cpu_core/branches/:HGu                                                  (0.00%)
           251,150      cpu_atom/branch-misses/:HGu      #    0.01% of all branches             (58.31%)
     <not counted>      cpu_core/branch-misses/:HGu                                             (0.00%)
             TopdownL1 (cpu_atom)                 #      0.2 %  tma_bad_speculation    
                                                  #     46.1 %  tma_retiring             (58.33%)
                                                  #     48.3 %  tma_backend_bound      
                                                  #      5.4 %  tma_frontend_bound       (50.03%)

       4.294734138 seconds time elapsed

       4.266804000 seconds user
       0.000997000 seconds sys
```

We see significant effects due to warmup time, around 10% by the last run.

```
> taskset -c 16 perf stat -e L1-dcache-loads,L1-dcache-load-misses,LLC-loads,LLC-load-misses ./PolyMult.time -dA 80000 -dB 80000 -t 1 -r 3
variant,dA,dB,threads,build_params,rep,seconds,gflops
EXQ,80000,80000,1,"",0,1.362218638,9.397
EXQ,80000,80000,1,"",1,1.359648710,9.414
EXQ,80000,80000,1,"",2,1.360184219,9.411

 Performance counter stats for './PolyMult.time -dA 80000 -dB 80000 -t 1 -r 3':

     9,604,033,014      cpu_atom/L1-dcache-loads:u/                                           
             2,185      cpu_atom/LLC-loads:u/                                                 
                 3      cpu_atom/LLC-load-misses:u/      #    0.14% of all LL-cache accesses  

       4.087646220 seconds time elapsed

       4.078249000 seconds user
       0.000000000 seconds sys
```

```
> taskset -c 16 perf stat ./PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3
variant,dA,dB,threads,build_params,rep,seconds,gflops
EXQ,160000,160000,1,"",0,5.460311693,9.377
EXQ,160000,160000,1,"",1,5.458780422,9.380
EXQ,160000,160000,1,"",2,5.464089783,9.370

 Performance counter stats for './PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3':

         16,391.67 msec task-clock:HGu                   #    1.000 CPUs utilized             
                 0      context-switches:HGu             #    0.000 /sec                      
                 0      cpu-migrations:HGu               #    0.000 /sec                      
               697      page-faults:HGu                  #   42.522 /sec                      
    35,733,012,448      cpu_atom/cycles/:HGu             #    2.180 GHz                         (50.00%)
    57,621,808,730      cpu_atom/instructions/:HGu       #    1.61  insn per cycle              (58.33%)
     9,605,452,356      cpu_atom/branches/:HGu           #  585.996 M/sec                       (58.33%)
           491,900      cpu_atom/branch-misses/:HGu      #    0.01% of all branches             (58.33%)
             TopdownL1 (cpu_atom)                 #      0.0 %  tma_bad_speculation    
                                                  #     48.4 %  tma_retiring             (58.33%)
                                                  #     46.2 %  tma_backend_bound      
                                                  #      5.4 %  tma_frontend_bound       (50.00%)

      16.392686134 seconds time elapsed

      16.289083000 seconds user
       0.002981000 seconds sys
```

```
> taskset -c 16 perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses ./PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3
variant,dA,dB,threads,build_params,rep,seconds,gflops
EXQ,160000,160000,1,"",0,5.433249315,9.424
EXQ,160000,160000,1,"",1,5.433114240,9.424
EXQ,160000,160000,1,"",2,5.433836867,9.423

 Performance counter stats for './PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3':

    35,707,876,594      cpu_atom/cycles:u/                                                    
    57,636,927,145      cpu_atom/instructions:u/         #    1.61  insn per cycle            
           103,631      cpu_atom/cache-references:u/                                          
            80,660      cpu_atom/cache-misses:u/         #   77.83% of all cache refs         
     9,608,118,555      cpu_atom/branches:u/                                                  
           493,811      cpu_atom/branch-misses:u/        #    0.01% of all branches           

      16.313276153 seconds time elapsed

      16.275957000 seconds user
       0.004969000 seconds sys
```

```
> taskset -c 16 perf stat -e L1-dcache-loads,L1-dcache-load-misses,LLC-loads,LLC-load-misses ./PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3
variant,dA,dB,threads,build_params,rep,seconds,gflops
EXQ,160000,160000,1,"",0,5.442010865,9.408
EXQ,160000,160000,1,"",1,5.433290145,9.424
EXQ,160000,160000,1,"",2,5.438569778,9.414

 Performance counter stats for './PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3':

    38,408,030,866      cpu_atom/L1-dcache-loads:u/                                           
             7,548      cpu_atom/LLC-loads:u/                                                 
                 0      cpu_atom/LLC-load-misses:u/                                           

      16.323895991 seconds time elapsed

      16.288823000 seconds user
       0.001995000 seconds sys
```

```
> taskset -ctaskset -c 16 perf record -g ./PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3
#
# Total Lost Samples: 0
#
# Samples: 66K of event 'cpu_atom/cycles/Pu'
# Event count (approx.): 35827850813
#
# Children      Self  Command        Shared Object         Symbol                           
# ........  ........  .............  ....................  .................................
#
    99.95%     0.00%  PolyMult.time  PolyMult.time         [.] main
            |          
             --99.95%--main
                       |          
                        --99.95%--kernel_multiply

    99.95%    99.94%  PolyMult.time  PolyMult.time         [.] kernel_multiply
            |          
             --99.94%--main
                       kernel_multiply

     0.04%     0.04%  PolyMult.time  libc.so.6             [.] __random
     0.02%     0.00%  PolyMult.time  [unknown]             [.] 0x4239897f423df5ce
     0.02%     0.00%  PolyMult.time  [unknown]             [.] 0000000000000000
     0.02%     0.00%  PolyMult.time  [unknown]             [.] 0xffffffffaca00e30
     0.01%     0.01%  PolyMult.time  libc.so.6             [.] __random_r
     0.00%     0.00%  PolyMult.time  [unknown]             [k] 0xffffffffaca0115e
     0.00%     0.00%  PolyMult.time  libc.so.6             [.] __memset_avx2_unaligned_erms
     0.00%     0.00%  PolyMult.time  [unknown]             [.] 0xffffffffaca00b80
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] _dl_fixup
     0.00%     0.00%  PolyMult.time  [unknown]             [.] 0x00007fee717ceac8
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] _dl_check_map_versions
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] check_match
     0.00%     0.00%  PolyMult.time  [unknown]             [.] 0x42494c4700352e32
     0.00%     0.00%  PolyMult.time  [unknown]             [.] 0x0000000009691a75
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] _dl_process_pt_gnu_property
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] _dl_start_user
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] _dl_sysdep_start
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] dl_main
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] init_cpu_features.constprop.0
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] __GI___tunables_init
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] _dl_start
     0.00%     0.00%  PolyMult.time  ld-linux-x86-64.so.2  [.] _start
```

LLC load misses and branch predictor misses are extremely low, but generic "cache" misses are extremely common (78%). One of these two must be lying, and both ChatGPT and Claude believe that it's the cache misses.
The vast majority of work comes from kernel_multiply (99.94%) so this sample is representative of kernel_multiply overall.

At these sizes, we begin achieving ~26.7% TPP. This is lower than our 37% achieved for smaller samples in both OPP2 and EXQ.

```
> perf annotate kernel_multiply
  15.17 │ 98:┌─→vmovups      (%rbx,%rdx,1),%ymm0                                                                                                      ▒
  37.95 │    │  vfmadd213ps  (%rax,%rdx,1),%ymm2,%ymm0                                                                                                ◆
  26.67 │    │  vmovups      %ymm0,(%rax,%rdx,1)                                                                                                      ▒
   6.72 │    │  add          $0x20,%rdx                                                                                                               ▒
   6.68 │    ├──cmp          %rdi,%rdx                                                                                                                ▒
   6.74 │    └──jne          98            
```

```
vmovups load	15.17%	loading 32 B
vfmadd213ps	37.95%	main FP computation
vmovups store	26.67%	storing 32 B
add	6.72%	loop index
cmp	6.68%	loop termination
jne	6.74%	loop branch
```

```
> taskset -c 16 perf stat -e cycles,instructions -e cpu_atom/topdown-retiring/ -e cpu_atom/topdown-be-bound/ -e cpu_atom/topdown-fe-bound/ -e cpu_atom/topdown-bad-spec/ ./PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3
variant,dA,dB,threads,build_params,rep,seconds,gflops
EXQ,160000,160000,1,"",0,5.435415612,9.420
EXQ,160000,160000,1,"",1,5.447791224,9.398
EXQ,160000,160000,1,"",2,5.439092693,9.413

 Performance counter stats for './PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3':

    35,752,804,147      cpu_atom/cycles:u/                                                    
    57,636,927,080      cpu_atom/instructions:u/         #    1.61  insn per cycle            
    86,446,860,871      cpu_atom/topdown-retiring/u                                           
    82,628,665,600      cpu_atom/topdown-be-bound/u                                           
     9,619,066,073      cpu_atom/topdown-fe-bound/u                                           
        68,807,296      cpu_atom/topdown-bad-spec/u                                           

      16.334365597 seconds time elapsed

      16.298324000 seconds user
       0.001989000 seconds sys
```

```
> taskset -c 16 perf stat -M tma_backend_bound -M tma_memory_bound -M tma_core_bound ./PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3
variant,dA,dB,threads,build_params,rep,seconds,gflops
EXQ,160000,160000,1,"",0,5.485285583,9.334
EXQ,160000,160000,1,"",1,5.545911345,9.232
EXQ,160000,160000,1,"",2,5.514574173,9.285
 Performance counter stats for './PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3':

    86,436,171,898      cpu_atom/topdown-retiring:u/                                            (50.00%)
     9,619,377,795      cpu_atom/topdown-fe-bound:u/                                            (50.00%)
    84,642,481,674      cpu_atom/topdown-be-bound:u/                                            (50.00%)
        69,038,431      cpu_atom/topdown-bad-spec:u/                                            (50.00%)
    36,156,852,095      cpu_atom/CPU_CLK_UNHALTED.CORE/u #     46.8 %  tma_backend_bound      
                                                  #      0.0 %  tma_core_bound           (50.00%)
         3,561,963      cpu_atom/TOPDOWN_BE_BOUND.ALLOC_RESTRICTIONS/u                                        (50.00%)
    84,637,192,387      cpu_atom/TOPDOWN_BE_BOUND.ALL/u                                         (50.00%)

      16.555425561 seconds time elapsed

      16.478802000 seconds user
       0.002955000 seconds sys
```

The TMA model is saying that the backend stalls are not being attributed to the core-bound category.

```
> taskset -c 16 perf stat -e cpu_atom/mem_scheduler_block.all/ -e cpu_atom/mem_scheduler_block.ld_buf/ -e cpu_atom/mem_scheduler_block.rsv/ -e cpu_atom/mem_scheduler_block.st_buf/ ./PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3
variant,dA,dB,threads,build_params,rep,seconds,gflops
EXQ,160000,160000,1,"",0,5.440349816,9.411
EXQ,160000,160000,1,"",1,5.443099428,9.407
EXQ,160000,160000,1,"",2,5.439040839,9.414

 Performance counter stats for './PolyMult.time -dA 160000 -dB 160000 -t 1 -r 3':

    12,446,018,848      cpu_atom/mem_scheduler_block.all/u                                      
    12,020,234,569      cpu_atom/mem_scheduler_block.ld_buf/u                                      
             3,630      cpu_atom/mem_scheduler_block.rsv/u                                      
       425,780,659      cpu_atom/mem_scheduler_block.st_buf/u                                      

      16.332053064 seconds time elapsed

      16.296975000 seconds user
       0.002981000 seconds sys
```

```
> perf list | grep -A3 -B1 'mem_scheduler_block'
  mem_scheduler_block.all
       [Counts the number of cycles that uops are blocked for any of the
        following reasons: load buffer,store buffer or RSV full. Unit:
        cpu_atom]
  mem_scheduler_block.ld_buf
       [Counts the number of cycles that uops are blocked due to a load buffer
        full condition. Unit: cpu_atom]
  mem_scheduler_block.rsv
       [Counts the number of cycles that uops are blocked due to an RSV full
        condition. Unit: cpu_atom]
  mem_scheduler_block.st_buf
       [Counts the number of cycles that uops are blocked due to a store
        buffer full condition. Unit: cpu_atom]
```

96.6% of memory-scheduler blocking is load-buffer related
3.4% is store-buffer related
effectively 0% is RSV-related

The load-buffer blocking event takes 12.02B of 35.6B CPU cycles, about 33.8%.

### 01 OPP2

Following the same experimentation with Claude on OPP2 found that the same load-buffer-dominated pattern shows up in OPP2, at very similar magnitude.

Same conditions as the EXQ measurement: dA=dB=160000, -t 1, 3 reps, pinned to core 16, existing 01-OPP2/bin/PolyMult.time (no rebuild needed — the binary takes -dA/-dB at runtime).

mem_scheduler_block counters:

┌────────────────────────────┬────────────────┬─────────────────────┐
│                            │      OPP2      │ EXQ (from notes.md) │
├────────────────────────────┼────────────────┼─────────────────────┤
│ mem_scheduler_block.all    │ 12,722,315,777 │ 12,446,018,848      │
├────────────────────────────┼────────────────┼─────────────────────┤
│ mem_scheduler_block.ld_buf │ 12,048,013,501 │ 12,020,234,569      │
├────────────────────────────┼────────────────┼─────────────────────┤
│ mem_scheduler_block.rsv    │ 3,431          │ 3,630               │
├────────────────────────────┼────────────────┼─────────────────────┤
│ mem_scheduler_block.st_buf │ 674,298,859    │ 425,780,659         │
└────────────────────────────┴────────────────┴─────────────────────┘

As shares:

┌───────────────────────────────────────────────┬───────┬───────┐
│                                               │ OPP2  │  EXQ  │
├───────────────────────────────────────────────┼───────┼───────┤
│ ld_buf share of all blocking                  │ 94.7% │ 96.6% │
├───────────────────────────────────────────────┼───────┼───────┤
│ st_buf share of all blocking                  │ 5.3%  │ 3.4%  │
├───────────────────────────────────────────────┼───────┼───────┤
│ ld_buf as % of total cycles (36.17B / 35.60B) │ 33.3% │ 33.8% │
└───────────────────────────────────────────────┴───────┴───────┘

So: load-buffer blocking dominates in both, and at almost the same absolute cycle count and the same ~1/3 of total cycles. OPP2 does show a somewhat larger store-buffer share than EXQ (5.3% vs 3.4%), which runs the other direction from what OPP22's store-removal result might suggest mattering most.

A real surprise this raises: at this same 160000×160000 size, OPP2's %TPP comes out to 26.4-26.6% (9.378/9.330/9.291 GFLOPs/s ÷ 35.2), essentially identical to EXQ's ~26.7% here — not the ~37% TPP your notes record for OPP2 at 1000×4000/8000×2000. And this near-identical load-buffer-blocking share between OPP2 and EXQ at 160000×160000 sits oddly next to the topdown numbers recorded earlier for OPP2 at the smaller sizes, which showed backend-bound around 21-23% — much lower than EXQ's 46-48% backend-bound. I haven't reconciled that — it could be a real loop-order convergence at large sizes, a problem-size effect independent of loop order, or the topdown "backend_bound" percentage and this raw load-buffer-cycle count just not being the same kind of measurement. Worth deciding whether that's worth chasing before drawing a conclusion from either number alone.

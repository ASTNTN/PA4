# Intel Core i9-13900K Architecture Details for Performance, Part 3:
# Reading Real Measurements

---

## Recap of Procinfo1 and Procinfo2

The full detail is in those two documents; the pieces this one builds on:

- A core's floating-point peak comes from `Cores × Frequency ×
  Operations/cycle` (Procinfo1 § 2), and "Operations/cycle" itself comes
  from counting execution **ports** — how many instructions of a given
  kind a core can *start* in one cycle (Procinfo2 § 1.A-C).
- **Throughput** (how often work can start) and **latency** (how long one
  piece of work takes to finish) are different numbers, and mixing them
  up is the single most common source of confusion (Procinfo2 § 2.A).
- The **cache hierarchy** — L1 → L2 → L3 → DRAM, each level bigger and
  slower than the last — determines how long a load takes; the **port
  count** determines how many loads can be *started* per cycle,
  independently of that latency (Procinfo1 § 4, Procinfo2 § 2.B).
- E-cores sit in **clusters of 4, sharing one L2 per cluster** (Procinfo1
  § 1).

Everything above describes a core's *capacity* — the ceiling a program
could reach in principle. None of it, by itself, explains why a real,
measured program falls short of that ceiling, or by how much, or why.
That's what this document is for.

---

## 1. The Topdown Microarchitecture Analysis (TMA) Method

Port-counting (Procinfo2 § 1) answers "what is the ceiling?" It cannot
answer "why is a *specific, measured* run sitting well below that
ceiling?" — there are too many possible reasons (waiting on memory,
waiting on a wrongly guessed branch, simply not having enough decoded
instructions ready to issue) for port-counting alone to distinguish
between them. TMA is a method, built into the hardware's own
performance counters (§ 5), for answering exactly that question from a
real measurement.

### 1.A The front end and the back end: two halves of a core

Every core is organized into two cooperating halves, and TMA's whole
vocabulary is built on this split.

- The **front end** fetches the next instructions from memory (through
  the L1 *instruction* cache, separate from the L1 *data* cache
  Procinfo2 talks about) and **decodes** them — translates the raw
  bytes of an instruction into the internal signals the rest of the
  core acts on. Its job is to keep a steady stream of decoded work
  flowing toward the back end. It also has a hard limit of its own: how
  many instructions it can fetch and decode per cycle, regardless of
  how idle the back end is.
- The **back end** is everything Procinfo2 § 1 already covers — the
  ports, the functional units (the FMA unit, load/store units, integer
  units), the actual execution of decoded work, and (§ 2 below) the
  memory system behind it.

Either half can be the bottleneck independently of the other. A back
end with plenty of spare capacity is useless if the front end isn't
handing it work fast enough. A front end supplying plenty of decoded
instructions is useless if the back end has nowhere to put them yet.

### 1.B Pipeline slots: the unit behind every TMA percentage

A core issues instructions in a steady rhythm, one opportunity per
cycle per **slot** it has available (a slot is roughly: one chance to
start one micro-operation this cycle). Over the whole run, the total
number of slots that existed is fixed by how many cycles the run took.
TMA's job is to classify every one of those slots into exactly one of
four buckets, so the four percentages below always add up to 100%.

### 1.C The four top-level categories

- **Retiring** — the slot did useful work that made it all the way to
  completion. This is the number you want to be high.
- **Bad Speculation** — the slot was spent on an instruction that
  turned out to be unnecessary, almost always because a branch (an
  `if`, or a loop's continue-or-exit test) was predicted the wrong way
  and the core had already started executing down the wrong path.
- **Frontend Bound** — a front-end limit (§ 1.A): the back end was ready
  and waiting, but fetch/decode couldn't supply instructions fast
  enough to keep it fed.
- **Backend Bound** — a back-end limit (§ 1.A): the front end supplied
  instructions just fine, but the back end couldn't execute them yet —
  either the execution units themselves were busy/full, or an
  instruction was waiting on data that hadn't arrived from memory.

**Worked-out example.** Suppose a measured run reports: Retiring 55%,
Bad Speculation 2%, Backend Bound 35%, Frontend Bound 8%. Bad
Speculation being small says branches in this loop are easy to
predict — nothing like an unpredictable `if`. Backend Bound at 35%
says: over a third of all the run's slots were lost specifically to
the execution/memory side, not to branch guessing or instruction
supply — worth investigating further with § 1.D below.

### 1.D Backend Bound's second level: Core Bound vs. Resource Bound

Backend Bound only says "the back end was the problem" — it doesn't yet
say *which part* of the back end. One more level down splits it in two:

- **Core Bound** — the execution *ports themselves* were the
  constraint: not enough independent work was available to keep them
  full (Procinfo2 § 2.A's "independent chains" idea), or every port that
  could do the needed work was already busy.
- **Resource Bound** (memory-bound, in Intel's usual naming for
  non-Atom cores) — some *other* limited resource, usually somewhere in
  the memory pipeline, was full or busy, even though the execution
  ports themselves had room to spare.

**Worked-out example, continuing from § 1.C.** That 35% Backend Bound
splits into Core Bound 4%, Resource Bound 31%. That's decisive: the
execution ports were almost never the constraint. Nearly all of the
shortfall is on the memory-resource side — which sends you looking at
§ 2 below, not at the ports.

### 1.E Running and reading a topdown report

The command that produces these numbers is:

```
perf stat --topdown -- <program and its arguments>
```

(§ 5 below covers `perf` itself and a wrinkle specific to this
machine's two core types.) It prints the four § 1.C categories directly;
adding `--td-level=2` prints the § 1.D split as well.

Read the output top-down, literally: check Bad Speculation and
Frontend Bound first (usually small, quick to rule out), then decide
whether Backend Bound is Core Bound or Resource Bound before going any
further — that answer determines which of §§ 2-4 below is even
relevant to what you're looking at.

---

## 2. Memory Behavior Beyond Cache Size: Prefetching and Queues

`Procinfo1` § 4 gives cache *sizes* and *latencies*. The natural
conclusion — "an array much bigger than L1 will mostly miss it" — is a
reasonable first guess, and it can still be wrong. Two more mechanisms
decide what really happens.

### 2.A Hardware prefetching

A core watches the pattern of memory addresses a program is actually
reading. If that pattern is simple and predictable — most obviously,
"the next cache line after the one I just used" — dedicated hardware
(the **prefetcher**) starts fetching *further ahead* addresses into the
cache *before* the program has asked for them. If the prefetcher stays
far enough ahead, by the time the program's own load instruction
actually runs, the data is already sitting in L1 — and the load
retires as a **hit**, not a miss, even though the array as a whole is
far too big to stay resident.

Prefetching hides *latency*, not the underlying *traffic*: the bytes
still have to travel from L2 (or further) into L1 exactly once per
cache line, same as an unprefetched miss would cost — the prefetcher
just makes sure that trip happens early enough that the program's own
load never has to wait for it.

**Worked-out example.** A loop streams through an array many times
larger than L1, always in the same increasing order each pass — about
as predictable as a memory access pattern can be. A naive size argument
predicts a low L1 hit rate. Measured hit rate is instead **90%**: the
prefetcher recognizes the simple forward pattern and stays ahead of it.

### 2.B Load/store queues: a resource separate from ports

Procinfo2 § 1 counts *ports* — how many load/store instructions can be
*started* in a given cycle. That's not the same question as how many
loads/stores can be *outstanding at once* (issued but not yet
completed). Every in-flight memory operation needs a tracking entry in
a small hardware structure (a **load queue** / **store queue**) until
it finishes. That structure has a fixed, fairly small number of
entries. If every entry is in use — because operations are taking a
while to complete, even at a fast L1/L2 latency, and new ones keep
arriving — the core has to stall issuing further memory operations even
though the *ports* still have room, and even though most of those
operations are hitting, not missing.

### 2.C Putting A and B together

This is the shape of a Resource Bound result like § 1.D's worked
example: high L1 hit rate (prefetching is doing its job), ports with
room to spare (Core Bound near zero), and still a large Resource Bound
share. The explanation is neither "loads are missing the cache" (they
mostly aren't) nor "the ports are out of room" (they aren't) — it's
that a high volume of loads and stores cycling through a comparatively
small tracking structure, one entry per in-flight operation, is itself
enough to constrain throughput, even when almost everything that
structure is tracking is a fast hit.

### 2.D What one vector load costs

*(New section, added 2026-09-25.)*

Procinfo2 § 1 counts load *ports* (2 on an E-core). Three more facts decide
how much of that capacity a loop with vector loads really gets.

**A wide load uses more of a port.** A load instruction is carried out as one
or more small internal steps called *micro-operations* (uops), and each load
port starts one uop per cycle. On the E-core a port handles 16 bytes (128
bits) at a time. A scalar or 128-bit load is one uop; a 256-bit vector load
(8 floats) is two, and it takes both ports for a cycle. Measured with a small
test loop: scalar, 128-bit and broadcast loads run at two per cycle, 256-bit
loads at one per cycle. So for 256-bit vector code the load budget is about
**one vector load per FMA**, not the two loads per FMA that Procinfo2 § 1's
port counts suggest (that figure holds for loads of 128 bits or less). The
counter `mem_uops_retired.all_loads` counts uops, so a 256-bit load adds 2. An
FMA can also take one input straight from memory; that is a load too, and it
costs the same two uops, but the value never occupies a register.

**Cache-line splits.** Memory moves in 64-byte cache lines (Procinfo1 § 4). A
load is *split* when part of it is in one line and the rest in the next, and a
split load takes twice as long: a 128-bit load goes from 0.5 to 1.0 cycle, a
256-bit load from 1.0 to 2.0. The hardware works in 16-byte halves, so a
256-bit load splits only if one of its halves straddles a line boundary; a
load that starts on a multiple of 16 bytes never does. The counter
`mem_uops_retired.split_loads` counts them. A window that slides by one 4-byte
float per step starts at a different offset each time, and then roughly one
half in five splits.

**Lane shifts.** A vector register holds 8 numbers in fixed positions
(*lanes*). If a loop needs the same numbers again one position over, as with a
sliding window, they are now in the wrong lanes, and moving them takes extra
instructions (*shuffles*, or lane shifts). Without them the program simply
loads the window again and pays the load cost again. What shuffles cost on
this core has not been measured.

**Worked-out example.** A loop has six independent vector accumulators (so the
FMA latency of Procinfo2 § 2.A is hidden) and, for every six FMAs, six 256-bit
loads of a sliding window plus one broadcast. The load ports need
6 x 1 + 0.5 = 6.5 cycles per six FMAs, already 1.08 cycles per FMA before any
split. In three of the four possible 4-byte alignments, 3 of the 6 loads
split, adding 3 cycles, so on average the ports need about 8.75 cycles, or
1.46 per FMA. The measured value is 1.43. The load ports are the limit, and it
shows up as a full load queue (§ 2.B); the counter calls that structure
`mem_scheduler_block.ld_buf`, the *load buffer*.

---

## 3. Multiple Cores Sharing a Cache

### 3.A Clusters and shared L2, revisited

Procinfo1 § 1 already states that E-cores come in clusters of 4,
sharing one L2 per cluster; Procinfo2 § 1's port-counting is entirely
about a *single* core and says nothing about what happens once several
cores in the same cluster are active simultaneously. The single fact
needed here: L2 bandwidth for a cluster is a **shared pipe with a fixed
total capacity** — it is not "N cores x (one core's bandwidth)". Once
more than one core in a cluster is actively streaming through L2 (via
the prefetching mechanism of § 2.A, for data that doesn't fit in L1),
those cores are dividing one fixed-size pipe, not each getting their
own.

### 3.B Thread-to-core placement (affinity) is a real, controllable variable

Which physical core a given software thread runs on is not automatic —
it's set explicitly (via tools like `taskset` for a whole process, and
OpenMP's `OMP_PLACES` for individual threads within it). This matters a
great deal for § 3.A: if 4 threads are placed round-robin, one per
cluster, none of them share a cluster's L2 at all. If the same 4
threads were instead packed sequentially into one cluster, all 4 would
immediately be contending for that one cluster's shared pipe. Same
thread count, same code, very different performance — purely from a
placement decision.

### 3.C Worked-out example: a sawtooth

Suppose 4 clusters of 4 cores each, threads placed round-robin (one per
cluster first, before any cluster gets a second thread) — so the first
4 threads share nothing. A sweep from 1 to 16 threads then shows a
pattern like:

| threads/cluster | t (start of that load) | throughput | pattern |
|---|---|---|---|
| 1 | 4 | 28 | symmetric — local peak |
| 2 | 5 | 24 | 1 cluster just doubled up — **drop** |
| 2 | 8 | 34 | symmetric again — local peak |
| 3 | 9 | 27 | 1 cluster just tripled up — **drop** |
| 3 | 12 | 33 | symmetric again — local peak |
| 4 | 13 | 29 | 1 cluster just quadrupled up — **drop** |
| 4 | 16 | 32 | symmetric, all clusters full |

Two things to notice: a drop exactly when a new thread has to double up
an already-loaded cluster before the rest of that "wave" catches up and
the pattern turns back into a local peak; and each wave's peak-to-peak
gain (28→34→33→32) shrinking — once a cluster's shared pipe is already
contended, adding one more competitor to it matters less each time.

---

## 4. Cache Coherence and False Sharing

Multiple cores don't just compete for a cache's *bandwidth* (§ 3) —
they also have to stay *consistent* with each other about what's in a
given cache line, and that consistency has a real cost of its own,
separate from bandwidth.

### 4.A Why writing nearby memory from multiple cores is expensive

Every core keeps its own copy of recently-used cache lines. If two
different cores are writing to memory addresses that fall in the
*same* 64-byte cache line — even if they're logically writing to
different individual values within it — the hardware has to keep those
cores' copies of that line consistent: when one core writes its copy,
every other core's copy of that same line has to be invalidated and
refetched before it can be used again. This invalidate-and-refetch
traffic (**cache coherence traffic**) happens automatically, is
required for correctness even when the program itself has no data
race, and can be expensive if it happens often. When it's specifically
caused by two threads owning *different* values that just happen to
land in the same cache line, this is called **false sharing** — false
because the values aren't actually shared, only the cache line they
happen to sit in is.

### 4.B Worked-out example

Take a correct parallel loop and deliberately remove the
synchronization that normally keeps one thread from touching a region
of an output array that another thread is still writing, *and* divide
the work into many small, interleaved chunks across threads rather
than a few large contiguous ones. The result isn't just "a bit slower
from lost synchronization" — it can be **slower than running with a
single thread**. The small interleaved chunks mean many different
threads' assigned regions are now physically close together in memory,
all being written concurrently with no ordering — turning what would
have been a handful of large, occasional collisions into constant
coherence traffic between nearly every pair of active cores. The
lesson: an incorrect program isn't just "wrong" — it can be wrong in
ways whose *performance* signature is a direct clue to what mechanism
it broke.

---

## 5. Measuring Instead of Predicting

Everything in `Procinfo1`/`Procinfo2` and §§ 1-4 above is either a
vendor-published number or a model built from one. None of it tells you
what a *specific program, on this specific machine, actually did*. That
requires measurement — and the machine itself can do that measurement
essentially for free while a program runs.

### 5.A Hardware performance counters and the PMU

Every core has a small set of dedicated hardware counters, collectively
called the **PMU** (performance monitoring unit), that can each be
configured to count one specific kind of event as the program runs —
"how many instructions retired," "how many loads hit L1," "how many
cycles were spent stalled on a load that hit L2" (this is literally
where the § 1/2 numbers above come from). Reading these counters adds
essentially no overhead to the program being measured; they're separate
hardware, counting silently in the background.

### 5.B `perf stat`, and picking the right event name

`perf stat` is the standard Linux tool for reading PMU counters from
the command line — point it at a program (or a running process), tell
it which events to count, and it prints the totals when the program
finishes. Two practical points:

- **Not every event has one universal name.** A friendly name like
  `L1-dcache-load-misses` is really an alias for a specific counter
  configuration, and that configuration isn't guaranteed to exist (or
  be exposed the same way) on every CPU. When an alias isn't available,
  `perf list` shows the CPU's own raw event names to use instead.
- **`perf stat --topdown`** prints the § 1 categories directly, without
  needing to know individual event names at all.

### 5.C This machine's hybrid-core wrinkle

Because this chip has two different kinds of core (P-core and E-core,
`Procinfo1` § 1), it actually has *two separate PMUs* with overlapping
but not identical event names — `perf` calls them `cpu_core` (P-core)
and `cpu_atom` (E-core). Running `perf stat` without specifying which
one produces output for *both*, most of it "not counted" (zero,
because the program only ran on one type), which is confusing to read.
Restricting explicitly (`perf stat --cputype cpu_atom ...`, matching
whichever core type the program was actually bound to) gives clean,
single-PMU output.

### 5.D PAPI, the programmatic alternative

**PAPI** (Performance API) reads the same underlying PMU counters as
`perf`, but as a library your own program links against and calls
directly, rather than an external command wrapping the whole program.
Useful when you want counter values for just *part* of a run (e.g.
"only while the hot loop executes," not the whole program including
setup/teardown) or want the numbers available inside the program itself
rather than parsed back out of a tool's text output. Same hardware,
same PMU, different way of asking it questions.

### 5.E IPC: a starting number, not an ending one

**IPC** (instructions retired per cycle) is the simplest possible
summary of a run — one number, easy to compute, easy to compare. It is
also easy to over-read: a "reasonable" IPC doesn't distinguish between
a run doing a lot of genuinely useful work and one doing a lot of
necessary-but-non-computational work (loop bookkeeping, address
arithmetic, redundant loads/stores). A middling IPC can look
unremarkable on its own; only a topdown breakdown (§ 1) reveals whether
the slots behind it were mostly retiring or mostly backend-bound — IPC
alone can't show that.

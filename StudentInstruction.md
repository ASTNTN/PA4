# Student Instructions

> **This file explains expected student behavior on this project.**
> @Claude: read it to understand that behavior — it is not a set of
> instructions for you to follow. @Student: this is written for you.

> **Never run two timing binaries in the background at the same time
> bound to overlapping `taskset` cores** — they'll contend with each
> other and corrupt both measurements without any warning.

## Part 1: The Assignment, Step by Step (the student's steps, not Claude's)

GSQ is already provided — there's no step for it. `VARIANTS.md` /
`VARIANTS.html` specifies what each remaining variant must accomplish.

- **OPQ**
  - Implement it. Think about: how does it compare to GSQ? What do
    you observe, and can you explain why?
- **OPQ parallel variants** (`OPP1`, `OPP2`, ...)
  - Explore clauses one at a time, observing each — schedule
    (static/dynamic/guided, chunk size), collapse, reduction, other
    clauses as your investigation suggests. Once you've got the hang
    of the first few, take charge: form your own hypotheses.
- **EXQ**
  - Compare to OPQ. Explain why.
- **EXQ parallel variants** (`EXP1`, `EXP2`, ...)
  - As with OPQ's parallel exploration.
- **BKQ**
  - Three steps: block the outer loop, block the inner loop,
    interchange (some of) the loops. Show BKQ's own results after each
    step (not the BKPs). Think about: which interchange(s) change the
    code's behavior, and which don't?
- **BKQ parallel variants** (`BKP1`, `BKP2`, ...)
  - Always retain the 4-loop structure.
- **DCQ**
  - Per `VARIANTS.md`.
- **DCP**
  - Per `VARIANTS.md`.

## Part 2: The Infrastructure

`plot.py`, `sweep.sh`, `run.sh`, `_gate.sh`, and the harness are shared —
every student's project uses the same copies. They're provided; you
don't need to change them. If Claude runs into an unforeseen problem
there, accept the fix and report it to the instructor/GTA.

### `reference/`

Background material, not required reading to get started: `Procinfo1.md`
→ `Procinfo2.md` → `Procinfo3.md` go progressively deeper into this
machine's processor architecture and how to read real performance
measurements (`Procinfo1.md` § 1-2 derives the `--tpp-per-core` value
`EXPERIMENTS.md` uses). `PA1-Report-Template.html` is a report-writing
template from the Mandelbrot assignment — adapt it for this one.
`VectorizationPitfalls.md` is worth reading before you parallelize your
first loop: a real case where a perfect-speedup kernel was silently
running scalar instead of vectorized.

### Running a Single Call Yourself

`sweep.sh` builds, gates, and then calls the timing binary with this
exact invocation. You can run the same command directly in your
terminal for a one-off timed call, skipping the build/gate/csv steps:

```
# sequential (t=1), pinned to one core:
taskset -c 16 ./bin/PolyMult.time -dA <int> -dB <int> -t 1 -r <int>

# parallel (t>1), bound and placed:
OMP_PROC_BIND=close \
OMP_PLACES='{16},{20},{24},{28},{17},{21},{25},{29},{18},{22},{26},{30},{19},{23},{27},{31}' \
taskset -c 16-31 ./bin/PolyMult.time-par -dA <int> -dB <int> -t <range> -r <int>
```

The core list, pinned sequential core, and `OMP_PLACES` string are
`_gate.sh`'s current defaults (`BPM_CORESET`, `BPM_SEQ_CORE`,
`BPM_OMP_PLACES`) — check there if they've been overridden for a
different machine. `taskset` plus `OMP_PROC_BIND`/`OMP_PLACES` together
give you a precise, repeatable mapping of threads to cores; without
them, the OS scheduler and OpenMP runtime are free to place threads
differently from one run to the next, including onto fewer cores than
intended, which corrupts the measurement.

### Where Results and Plots Land

- `sweep.sh` writes each call's csv under its own `<variant-dir>/results/`.
- `plot.py`'s output path auto-derives: csvs from a single variant
  produce a workbook inside that variant's own `./plots/<topic>/`; csvs
  spanning more than one variant produce a cross-variant comparison
  workbook one level up, in `../plots/<topic>/` at the common parent.

### T(seq): What the Baseline Actually Is

Each variant's Speedup is computed against the minimum of up to three
things: its own no-`-fopenmp` binary's time, its `*Q` ancestor's own
no-`-fopenmp` binary's time (a `*P<n>` variant may restructure the loop
nest, not just annotate it — so these can genuinely differ), and this
sweep's own 1-thread time. Whichever is smallest wins. **Every variant,
including every `*P<n>` parallel one, needs its own `--record-seq`** —
recording never happens automatically across directories, only the
lookup does.

This makes Speedup an approximation, not a number you should compare
precisely across variants — **Performance is the metric for that.**

# EXPERIMENTS

**Never run two timing binaries in the background at the same time bound
to overlapping `taskset` cores** — they'll contend with each other and
corrupt both measurements without any warning.

The user-facing interface to running an experiment and turning it into a
workbook: `sweep.sh`, `collect.py`, `plot.py`. Read this before running a
sweep or building a workbook.

## The three tools

**`sweep.sh`** — one sweep for one variant, one results csv (one row per
thread count, or per swept configuration — see "Multi-Axis Sweeps" below).

```
sweep.sh --variant-dir DIR --dA N --dB N --threads RANGE --reps N
         (--out FILE.csv | --name NAME)
         [--make-var KEY=VALUE ...] [--tune KEY=RANGE ...]
         [--extra KEY=VALUE ...]
         [--seq-time SECONDS [--seq-source TEXT] | --record-seq | --renew-seq]
```

Builds the variant, runs its correctness gate, runs the timed sweep(s),
writes the csv — every parallel invocation bound (see `_gate.sh`), no
unbound `.check-par`/`.time-par` possible.

- `--name` writes to `<variant-dir>/results/<name>.csv`; a sweep's raw data
  belongs to its own variant directory. `--out` overrides this. Recommended
  stem: a dotted date plus a same-day sequence number, e.g.
  `2026.09.14.001_5thr` or `2026.09.14.002_block_size_sweep` — this is a
  naming convention, not something `sweep.sh` generates for you.
- `--make-var KEY=VALUE` forwards a compile-time knob to `make` (e.g.
  `SCHED=dynamic,8`, `UNROLL=8`) — one rebuild per call. Comparing values
  means calling `sweep.sh` once per value, each to its own output.
- `--tune KEY=RANGE` forwards a runtime tuning knob (e.g. `block_size=64`)
  to the timing binary's own `--tune KEY=VALUE`, no rebuild needed. A bare
  single value is forwarded unchanged, exactly as today; a real range
  (`--tune block_size=32:512:2`, same syntax as `--threads`) loops
  `sweep.sh` itself, one invocation per value, and becomes a **swept
  axis** — see "Multi-Axis Sweeps" below. Repeatable — up to 4 total
  swept axes across `--threads`/`--tune` combined.
- `--extra KEY=VALUE` records a constant metadata field in the csv's
  preamble that isn't one of the built-in flags (e.g. `unroll=4` for a knob
  held fixed this call).
- `--allow-gate-failure` times the build even if its correctness gate
  fails, for a deliberately-incorrect diagnostic run (e.g. a `nowait` that
  should race). The gate still runs; its outcome is recorded in the csv's
  preamble as `gate_status=PASSED|FAILED`, and the csv lands under
  `<variant-dir>/results/diagnostic/` instead of `results/`, so it can
  never be mistaken for a trusted measurement. Cannot be combined with
  `--record-seq`/`--renew-seq` — a diagnostic build must never become the
  trusted sequential baseline.
- `--seq-time`/`--record-seq`/`--renew-seq`: see below.

**`collect.py`** — called internally by `sweep.sh`; not normally invoked
directly. Turns the timing binary's raw per-rep output (possibly several
`--tune`-axis invocations, concatenated by `sweep.sh`) into the results csv:
preamble of constant parameters, then one row per unique swept
configuration, with `median`, `mean_wo_outliers`, `gflops_median`,
`gflops_mean_wo_outliers` computed from `dA`/`dB` alone —
`GFLOPs = 2*(dA+1)*(dB+1)`, independent of any sequential baseline. Any rep
more than 2x slower than the fastest rep is treated as an outlier and
excluded. Which raw-csv columns are swept (become a grouping key + output
column) versus constant (become a preamble field) is auto-detected from the
data itself — a column with only one distinct value is constant, more than
one is swept — not from a fixed set of named flags, so a new `--tune` key
needs no change here.

**`plot.py`** — turn one or more results csvs into an `.xlsx` workbook.
Chart style is chosen automatically from the csv's own `axis_order`
preamble field (see "Multi-Axis Sweeps" below) — CLASSIC (thread-count
Speedup+Performance) when absent or `threads`, MULTI-AXIS (%TPP bar
chart(s) vs. a tuning parameter) otherwise.

```
plot.py --csv FILE [--csv FILE ...] --tpp-per-core VALUE
        [--out WORKBOOK.xlsx | --topic TOPIC] [--label NAME ...]
        [--tmp VALUE] [--stat median|mean_wo_outliers] [--title TITLE]
```

- Output path auto-derives when `--out` is omitted: every csv under the
  same `NN-VARIANT` directory (e.g. `00-GSQ`) is a single-variant plot,
  placed inside that variant's own `plots/`; csvs spanning more than one
  variant directory are cross-variant, placed one level up at the common
  parent's `plots/`. Flat filename, no per-topic subdirectory:
  `YYYY.MM.DD.NNN.<Topic>.xlsx` — `NNN` is the next unused sequence number
  for today's date in that directory (starts at `001` each day). `--topic`
  is **required** whenever `--out` is omitted — auto-deriving it from
  `--title` has been retired; `--title` is now purely the chart's own
  display title, independent of the output filename.
- `--tpp-per-core` for this machine's E-cores is 35.2 GFLOPs/s (16 Cores
  × 2.20 GHz × 16 Operations/Cycle = 563.2 GFLOPs total ÷ 16 cores; see
  `reference/Procinfo1.md` § 1-2 for the derivation).

CLASSIC path (unchanged): multiple `--csv` superpose on Speedup (one line
per run) and group on Performance (one bar per run per thread count).
Speedup and Performance render as **one combined chart**: Speedup per run,
plus an "Ideal speedup" (Speedup(t) = t) line, on the left axis; %TPP bars
per run, grouped per thread count, on the right ("Thread-normalized
Performance") axis. %TPP is thread-normalized
(`%TPP(t) = GFLOPs/s(t) / (TPP_per_core * t) * 100`). A "100% TPP"
reference bar is grouped alongside the %TPP bars whenever the tallest bar
exceeds 67% of TPP; at or below that, the axis is capped just above the
tallest bar and the reference is dropped, noted in the chart's own x-axis
title. The thread axis lists every integer from 1 to the largest swept
thread count, not just the counts actually measured, so the axis reads as
linear even when the sweep itself is sparse/exponential; unmeasured counts
are `=NA()` and draw nothing. **A csv with no `seq_time` in its preamble is
refused (`SystemExit`, not a warning)** — every classic-path workbook needs
a real sequential baseline behind it (see T(seq) carry-through below).

MULTI-AXIS path: one %TPP bar chart per facet-panel combination (axis 3 ×
axis 4, if present), each with axis 1 on the x-axis and axis 2 as the
bar-cluster color (sorted by its own numeric value, colored from a fixed,
colorblind-validated palette order — color is tied to the palette's own
validated adjacency, not re-optimized per dataset). Same 67%-cap/100%
-reference-line and GFLOPs-value-data-label conventions as the classic
Performance chart. Only a single `--csv` is supported in this style for
now. Always Performance-only, never Speedup (see "Multi-Axis Sweeps").

## T(seq) carry-through

The sequential baseline T(seq) starts from each variant's own true
sequential binary (`PolyMult.time`, no `-DPAR`/`-fopenmp`) run at a given
problem size — **every variant records its own**, including a `*P<n>`
parallel variant: it may restructure its `*Q` ancestor's loop nest, not
just annotate it, so its own no-`-fopenmp` binary is not assumed
identical to its ancestor's. A compile-time knob like `SCHED` has no
effect on this binary at all (an unrecognized `#pragma omp` is simply
ignored without `-fopenmp`), so one measurement covers every later sweep
of that variant *at the same size* regardless of schedule/tuning value —
but **`dA`/`dB` change the amount of work done, so T(seq) is specific to
the exact `(dA, dB)` pair it was measured at.** The sidecar is keyed on
that pair, not just the variant: `<variant-dir>/results/seq_time.json`
holds one entry per recorded `(dA, dB)` size, e.g.:

```json
{"entries": {"2000x2000": {"dA": 2000, "dB": 2000,
                             "seq_time": 0.0006037915, "seq_time_source": "..."}}}
```

**Establishing or extending it:** run `sweep.sh` once per size, with
`--threads 1`, no `--make-var`, and `--record-seq`:

```
sweep.sh --variant-dir 00-GSQ --dA 2000 --dB 2000 \
    --threads 1 --reps 11 --name seq --record-seq
```

This adds/updates just this size's entry in
`<variant-dir>/results/seq_time.json` (the measured value plus provenance)
in addition to the normal results csv — **every other recorded size is
left alone**, so recording a new `(dA, dB)` never disturbs one already in
use. `--record-seq` (like `--renew-seq` below) requires `--threads 1` and
refuses `--make-var`/`--seq-time` together with it — it must be the true,
schedule-independent sequential build.

**When the sequential kernel source itself changes, use `--renew-seq`
instead — same requirements, but it wipes every other recorded size
first, keeping only the one just measured:**

```
sweep.sh --variant-dir 00-GSQ --dA 2000 --dB 2000 \
    --threads 1 --reps 11 --name seq --renew-seq
```

The sequential kernel changes rarely, but when it does, every existing
entry is simultaneously stale, not just the one being re-recorded — a
later sweep at another size must not silently reuse a baseline from the
old kernel. Recording a *new* problem size, by contrast, is common and
shouldn't cost every other size its baseline. `sweep.sh` prints a warning
naming what got wiped whenever `--renew-seq` actually removes another
size's entry. Using plain `--record-seq` when the kernel changed would
leave other sizes' entries silently stale; using `--renew-seq` for a
merely-new size would cost unnecessary re-recording of sizes still in
use — pick the one that matches what actually happened.

**Every later sweep at a recorded size picks it up automatically, as the
minimum of up to three candidates**, none trustworthy alone:

1. **own** — this variant's own recorded `seq_time.json` entry.
2. **base** — for a `*P<n>` variant only, its `*Q` ancestor's own
   recorded `seq_time.json` entry (e.g. `03-BKP2`'s ancestor is
   `03-BKQ`, derived from the directory name). Not applicable to a `*Q`
   variant itself, where base and own are the same thing.
3. **par@1** — this sweep's own `t=1` row, when the thread range
   includes 1.

Whichever of the three are actually available get compared, and the
smallest wins; `seq_time_source` in the csv's preamble names which one
and its value. An explicit `--seq-time` on a call always overrides all
three.

This makes Speedup an *approximation*, not a precisely cross-variant
-fair number: a `*P<n>` that happens to have a slower or faster own
sequential binary than its `*Q` ancestor will show a correspondingly
skewed Speedup curve relative to a sibling `*P<n>` — Speedup is only
meant to judge one variant's own scaling against itself. **Performance
(%TPP) is the metric for comparing across variants** — it's computed
from `dA`/`dB` alone, independent of any T(seq), so it isn't subject to
this at all.

**Every `*P<n>` variant needs its own `--record-seq` call too** —
recording only lives in its own directory, at its own risk of the same
"never assume it matches" caveat above; there is no cross-directory
recording, only cross-directory *reading* (candidate 2).

**A sweep at a size with none of the three candidates available gets no
baseline at all** — never a value borrowed from a different size.
`sweep.sh` prints a note saying to `--record-seq` at that size (in this
variant or its `*Q` ancestor); the resulting csv has no `seq_time`, so
`plot.py` will later refuse it until that's done.

## Multi-Axis Sweeps

`--threads` and `--tune` are both range-capable (`sweep.sh`'s `--threads
RANGE` syntax: enumeration `1,2,4`, stride `2:16:2`, powers of 2 `1...16`,
or a bare single value, which is just a length-1 range). Whichever of them
is given **first on the command line**, among those whose value actually
expands to more than one value, is **axis 1** (the eventual chart's
x-axis); the next such flag is **axis 2** (series/cluster color); a 3rd
and 4th are facet-panel columns/rows. At most 4 axes total — `sweep.sh`
errors clearly if more are given. A flag whose value is a single value
(however given) never counts as an axis at all — it's just forwarded to
every invocation unchanged, exactly as before this feature existed.

**Where the looping happens:** a `--threads` range is always handled by
the timing binary's own internal loop — one invocation covers every
thread count in the range, regardless of whether `--threads` is axis 1 or
a later axis. A `--tune` range loops in `sweep.sh` itself, one binary
invocation per value (no rebuild between them), and every combination's
raw output is concatenated into one csv before `collect.py` sees it.
`collect.py` auto-detects which raw-csv columns actually varied and groups
rows accordingly — see its own description above.

**T(seq)/Speedup is only attempted for a plain single-configuration call
or a classic `--threads`-only sweep** — i.e. at most one axis, and if
present it's `threads`. A second+ swept axis (even if `--threads` is one
of them, e.g. `--threads 1,2,4 --tune block_size=64,128`) skips T(seq)
entirely and is always Performance-only. This is deliberate, not a
oversight: with a second axis present, T(seq) would need a baseline *per
combination* of the other axis/axes (different tuning configurations
generally have different sequential-binary timings too), which neither
`sweep.sh` nor `_seq_time.py` compute yet — rather than silently blend
different configurations' `t=1` rows into one misleading number, such a
sweep just doesn't get a Speedup baseline at all. Performance (%TPP) is
unaffected either way, since it's computed from `dA`/`dB` alone.

**Naming convention** (both csv and xlsx; `sweep.sh` doesn't generate csv
names for you, but `plot.py` does generate xlsx names): a dotted date,
then a zero-padded sequence number, then a descriptive name —
`2026.09.14.001_5thr.csv`, `2026.09.14.002.BlockSizeSweep.xlsx`. The
sequence number resets each new date and is scoped to one directory.

## Directory layout this produces

```
<NN-VARIANT>/results/<name>.csv                    one file per sweep.sh call
<NN-VARIANT>/results/seq_time.json                 one sidecar per variant
<NN-VARIANT>/plots/YYYY.MM.DD.NNN.<Topic>.xlsx      single-variant plot
plots/YYYY.MM.DD.NNN.<Topic>.xlsx                   cross-variant plot (project root)
```

# READ_ME_FIRST

## What this project is

A polynomial-multiply kernel, `c = a * b`, timed and correctness-checked under
a shared harness. `00-GSQ` is a working sequential reference
implementation. Students write sequential and parallel variants using the same
interface (`DESIGN.md`), run them with the provided scripts, and produce
speedup/performance charts.

## Layout

- `shared/harness/`, `shared/include/` — the harness every variant
  builds against: argument parsing, timing, the correctness gates,
  the kernel interface (`kernel.h`, `accumulate.h`). See `DESIGN.md`.
- `00-GSQ/` — the sequential reference kernel and its `Makefile`/
  `run.sh`. Use its layout as the template for a new variant directory.
- `_gate.sh` — shared build/gate/binding logic, sourced by `run.sh` and
  `sweep.sh`. Not meant to be run directly.
- `sweep.sh` — builds a variant, runs its correctness gate, runs a
  timed thread-count sweep, writes one results csv. Full interface in
  `EXPERIMENTS.md`.
- `collect.py` — called by `sweep.sh`. Turns the timing binary's raw
  per-rep output into the results csv format. Not normally called
  directly.
- `plot.py` — turns one or more results csvs into an `.xlsx` workbook
  with Speedup and Performance charts. Full interface in
  `EXPERIMENTS.md`.
- `_seq_time.py` — sidecar helper for the T(seq) carry-through
  mechanism, invoked by `sweep.sh` only. See `EXPERIMENTS.md`.
- `VARIANTS.md`, `TUNING.md` — per-variant loop-structure specifications
  and tuning spaces. Discussion inputs, not authorization — see each
  file's own operating-status note.
- `reference/` — background material: `Procinfo1.md`/`Procinfo2.md`/
  `Procinfo3.md` go progressively deeper into this machine's processor
  architecture and how to read real performance measurements
  (`Procinfo1.md` § 1-2 derives the `--tpp-per-core` value
  `EXPERIMENTS.md` uses); `PA1-Report-Template.html` is a report-writing
  template from the Mandelbrot assignment, adaptable for this one;
  `VectorizationPitfalls.md` is a real, verified case where a
  perfect-speedup parallel loop silently stopped vectorizing.

## Shared Test Harness

Every variant links the same harness code and implements
`kernel_multiply` (see `DESIGN.md`). Two binaries per variant matter for
correctness:

- `PolyMult.check` / `PolyMult.check-par` — build with `-DCHECKING`, run
  the oracle suite (independently-computable cases) and, for every
  variant except `GSQ`, a gold-comparison suite against `GSQ`. `GSQ`
  carries the oracle gate alone.
- `PolyMult.time` / `PolyMult.time-par` — build with `-ffast-math`, no
  correctness checking, used only for timing.

A variant's `run.sh` builds it and runs its correctness gate, both
binaries bound (see `_gate.sh`). Exit 0 means the gate passed.

## Workflow

1. `cd <variant-dir> && ./run.sh` — build and gate-check a variant on
   its own, any time, without timing anything.
2. `./sweep.sh --variant-dir <dir> --dA <int> --dB <int> \
   --threads <range> --reps <int> --name <name>` — build, gate, run a
   timed sweep, write `<variant-dir>/results/<name>.csv`.
3. Establish a sequential baseline once per `(variant, dA, dB)`:
   `./sweep.sh --variant-dir <dir> --dA <int> --dB <int> --threads 1 \
   --reps <int> --name seq --record-seq`. Every later sweep at that
   same variant and size picks it up automatically.
4. `./plot.py --csv results.csv --tpp-per-core <value> --topic <slug>`
   — one or more `--csv` (each an independent run, optionally
   `--label`led), superposed on the Speedup chart, grouped side by
   side on the Performance chart.

Run any script with `-h`/`--help` for its full flag list. Full detail on
every flag, the results csv format, and the T(seq) carry-through
mechanism is in `EXPERIMENTS.md`.

## The Seven-Step Protocol

Work proceeds one step at a time, one issue and one variant at a time:

1. **Design.** Describe what to build or change and why.
2. **Discuss.** Talk it through before writing code.
3. **Implement.** Either Claude implements it, requiring the user's explicit
   go-ahead for each edit-compile-test-run cycle (not once for a whole
   series) unless the user directly modifies code it (e.g.
   "I modified the code, test and continue"). In that case, Claude runs
   the build and correctness gate on the code as given, without
   rewriting, reviewing, or requiring a separate go-ahead for code it
   didn't write. Either way: on gate failure, back to step 1.
4. **(The user) proposes an experiment.** The user decides what to test and
   why (hypothesis), what varies and over what range, what stays fixed, how
   many reps, what result would confirm vs. invalidate the hypothesis.
5. **Run it.** Requires a separate explicit green light from step 3's —
   every performance measurement is its own approval, not implied by an
   approved implementation. `sweep.sh` (directly, or with Claude).
6. **Gather and plot.** `plot.py`.
7. **(The user) Chooses the next direction**, from what step 6 showed.

Shared harness, collection, and plotting infrastructure remain common
unless a demonstrated problem requires a change. Claude is not required
for any of this — `run.sh`, `sweep.sh`, `collect.py`, `plot.py`, and the
binaries all work standalone from the student's own terminal.

## Mistakes

An incorrect or surprising result is not a bug to be quietly fixed —
it's an input to the next hypothesis.

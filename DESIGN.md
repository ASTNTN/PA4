# DESIGN

Read `READ_ME_FIRST.md` first. This document explains the code
structure and desgn of the common `C` code harness and the kernel
interface. Neither Claude nor the user will normally need to modify it.
If a bug fix is required, ask the user to report it to the insructors.

## Layout

- `shared/include/kernel.h` — the interface every variant implements.
- `shared/include/accumulate.h` — the accumulation macro that EVERY
  VARIANT MUST USE (reasons are given below).
- `shared/harness/args.{c,h}` — CLI argument parsing (`bpm_args_t`,
  `bpm_parse_args`).
- `shared/harness/range.{c,h}` — thread-range parsing (`-t`).
- `shared/harness/oracle.{c,h}` — the oracle suite.
- `shared/harness/gold.h`, `shared/harness/gold.o` — the gold-comparison
  suite (linked by every variant except `GSQ`). Provided as a
  precompiled object only — `gold.c` itself is never distributed to
  students, and is never rebuilt by a variant's own `Makefile`.
- `shared/harness/time_main.c` — builds `PolyMult.time[-par]`: fills
  random inputs, times `kernel_multiply`, prints one raw csv row per
  repetition to stdout.
- `shared/harness/check_main.c` — builds `PolyMult.check[-par]`: runs
  the oracle suite, and the gold suite if `BPM_HAVE_GOLD` is defined.

## The kernel contract

Every variant defines `kernel_multiply` in its own `src/`, matching
the signature in `shared/include/kernel.h`. What isn't obvious just
from reading the header:

- `dA` and `dB` are independent — never assume `dA == dB`.
- Every pointer parameter must be `restrict`-qualified, on the
  definition as well as the declaration. This isn't compiler-enforced
  — it's a promise that `a`, `b`, `c` never alias each other or
  internally, which licenses optimizations the compiler couldn't
  otherwise make.
- A variant with a compile-time parameter (a `-D`, not a runtime flag)
  must define `kernel_build_params(void)`, returning a
  `key=value;key=value` string. A variant with none defines nothing —
  `time_main.c` supplies a weak default returning `""`.

## Accumulation

Every loop body must use `BPM_ACC`, from
`shared/include/accumulate.h`, in place of a direct accumulation
statement:

```c
BPM_COMP_DECL(comp, n);   /* once, before the accumulation loop */
...
BPM_ACC(c, comp, k, term);  /* c[k] += term, for every accumulation */
...
BPM_COMP_FREE(comp);
```

Skipping the macro will fail the correctness check: our
transformations often change the order of accumulations, which
introduces significant numerical error, so during checking we use
Kahan's algorithm to get a precise answer to compare against.

## Build system

One `Makefile` per variant directory, following `00-GSQ/Makefile`:

```
CHECK_SRCS = $(SRC) $(HARNESS)/oracle.c $(HARNESS)/check_main.c
TIME_SRCS  = $(SRC) $(HARNESS)/range.c $(HARNESS)/args.c $(HARNESS)/time_main.c
```

Four targets, into `bin/`:

| Binary                | Sources      | Flags                                    |
|------------------------|--------------|-------------------------------------------|
| `PolyMult.check`       | `CHECK_SRCS` | `-DCHECKING`                              |
| `PolyMult.check-par`   | `CHECK_SRCS` | `-DCHECKING -DPAR -fopenmp`               |
| `PolyMult.time`        | `TIME_SRCS`  | `-ffast-math`                              |
| `PolyMult.time-par`    | `TIME_SRCS`  | `-ffast-math -DPAR -fopenmp`              |

All four also get `-DBPM_VARIANT='"<name>"'`. For a non-`GSQ` variant,
`PolyMult.check`/`.check-par` also get `-DBPM_HAVE_GOLD` and link two
extra objects: `$(HARNESS)/gold.o` (provided, precompiled — see
Layout above) and a fresh per-variant recompile of GSQ's own
`src/PolyMult.c` with `kernel_multiply` renamed to `bpm_gold_multiply`
(so gold.o can call it as the reference alongside this variant's own
`kernel_multiply`). Neither takes this variant's own
`-DBPM_VARIANT`/`-DPAR` defines — `gold.o` is variant-agnostic, and the
GSQ recompile must stay GSQ's true checking build regardless of which
variant links it.

List every header the sources include (`kernel.h`, `accumulate.h`,
`args.h`, `range.h`, `oracle.h`, and any variant-specific header) as a
prerequisite of every binary target. Without this, editing a header
leaves stale binaries in place and a correctness gate silently re-runs
old code.

## CLI reference

`PolyMult.time[-par]`:

```
-dA <int>              degree of polynomial A
-dB <int>              degree of polynomial B
-t <range>             thread count(s): enumeration, stride, or powers of 2
-r <int>               repetitions per configuration (default: 3)
--tune KEY=VALUE       runtime tuning knob (e.g. --tune block_size=64);
                       repeatable; ignored by a kernel that doesn't ask
                       for KEY (see kernel.h's bpm_tune_get)
```

`PolyMult.check[-par]`: `[-h|--help]` only. `-dA`/`-dB`/`--validate`
are accepted for command-line-shape consistency but do not change what
runs — the oracle (and gold, if linked) suites use their own fixed
cases.

## Raw output format

`PolyMult.time[-par]` prints one csv row per repetition to stdout, with
one column per `--tune` key actually given on that call (a generic list,
not a fixed set — a new tunable key needs no change here):

```
variant,dA,dB,threads[,<tune key>...],build_params,rep,seconds,gflops
```

`collect.py` (see `READ_ME_FIRST.md`) turns this into the results csv
format.

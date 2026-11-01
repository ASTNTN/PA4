# Vectorization Pitfalls Under OpenMP

A real finding from parallelizing `GSQ` the simplest possible way: `#pragma
omp parallel for` on the outer loop, nothing else changed. It builds,
passes the gate, and shows **perfect speedup** — and is still running at
roughly **2% of theoretical peak**, not because of scheduling or
contention, but because the inner loop silently stopped vectorizing.

## 1. The symptom: perfect speedup, terrible performance

Speedup (relative to the variant's own `t=1`) scales linearly across
threads. Performance (%TPP) is flat at every thread count — consistent
with perfect speedup, but the flat value itself is far below what the
hardware can do. Perfect speedup only tells you every thread is doing the
same amount of work per unit time; it says nothing about whether that
work is efficient. Don't stop at speedup — check %TPP too.

## 2. Diagnosis: the inner loop de-vectorized

`GSQ`'s own sequential kernel vectorizes cleanly with `-ffast-math`
(confirmed via `-fopt-info-vec-all`: `loop vectorized using 32 byte
vectors`, and via disassembly: a single `vfmadd231ps` per 8-wide chunk).
The naive parallel version's disassembly shows something different. Its
real work has been split into a separate, compiler-generated function:

```
0000000000401840 T kernel_multiply
00000000004016f0 t kernel_multiply._omp_fn.0
```

Disassembling `kernel_multiply._omp_fn.0` finds **only scalar
instructions** — `vfmadd231ss` (single-lane), no `vpermd`/vector
`vfmadd231ps` anywhere. The inner loop is running one element at a time.

## 3. Why: it's not the outlining itself

`#pragma omp parallel for` makes GCC "outline" the loop body into a
separate function, called once per thread through `libgomp` — a real,
non-inlinable function-pointer boundary. `a`, `b`, `c`, and the loop
bounds get captured into a compiler-generated struct and passed in by
pointer, rather than arriving as ordinary `restrict`-qualified function
parameters.

It's tempting to conclude the outlining itself defeats vectorization —
but that's too strong a claim, and checking it directly disproves it: an
otherwise-identical kernel, parallelized the same way, through the exact
same outlining mechanism, **does** vectorize. The difference turned out
to be much narrower.

## 4. The actual cause: accumulating into the array, not into a register

Isolated with two minimal, otherwise-identical functions — same
signature, same `#pragma omp parallel for schedule(static, 8)`, same
`-ffast-math`, only the accumulation differs:

```c
/* (A) local scalar */
float sum = 0.0f;
for (int j = jmin; j <= jmax; j++) sum += a[k-j] * b[j];
c[k] = sum;
```

```c
/* (B) directly into the array */
for (int j = jmin; j <= jmax; j++) c[k] += a[k-j] * b[j];
```

`-fopt-info-vec-all` on each:

| | inner loop |
|---|---|
| (A) local scalar | `optimized: loop vectorized using 32 byte vectors` |
| (B) direct array write | `missed: not vectorized: complicated access pattern` |

Same outlining, same captured pointers, same everything else. (A)
vectorizes; (B) doesn't. Writing to `c[k]` every iteration, through a
pointer that arrived via the capture struct, is what defeats the
vectorizer's dependence analysis — not the struct capture by itself.

## 5. Why the project's own shared code walked into this

`shared/include/accumulate.h` documents one rule with no exception:
*"Use `BPM_ACC` for every accumulation into the output array."* That
rule exists for a correctness reason unrelated to vectorization — it
keeps the `CHECKING` (Kahan-compensated) and production loop structures
identical, so a passing correctness gate is real evidence about the
timed build. Expanded for production, `BPM_ACC(c, comp, k, term)` is
exactly form (B) above: `c[k] += term;`.

`GSQ`'s own shared kernel already follows this rule, like every variant
is meant to. So the natural, idiom-preserving way to parallelize it —
add a pragma to the existing, unmodified function — inherits form (B)
unchanged, and with it, the vectorization loss. Nothing in the
documented convention warns that this specific, well-justified rule
becomes a performance trap inside a parallel region. Getting form (A)
instead requires already knowing to deviate from the documented
convention — it's not something a correct-by-the-rules first attempt
would produce.

## 6. When you actually need `BPM_ACC`'s array form

- **One thread owns the whole output element** (e.g. parallelizing
  `GSQ`'s outer `k` loop, where each `k`'s full anti-diagonal sum is
  computed by a single thread): no other thread ever touches `c[k]`, so
  nothing needs the array's memory semantics. Accumulate into a local
  scalar; write `c[k]` once. This is safe, correct, and — per above —
  vectorizes.
- **Multiple threads can write the same output element** (e.g. `OPQ`'s
  outer-product form parallelized over `i`: for a fixed `i`, sweeping
  `j` writes to `c[i+j]`, a *different* anti-diagonal on every step, and
  two different threads' `i` values can land on the same `c[k]`): this
  needs `BPM_ACC`'s array form, further wrapped in `#pragma omp
  atomic`/`critical` at the call site to make the read-modify-write
  race-safe. There's no local-scalar shortcut here — the whole point is
  that the output location isn't privately owned.

## 7. How to check this yourself

```
gcc ... -fopt-info-vec-all -c src/PolyMult.c -o /dev/null 2>&1 | grep -i vector
```

Look for `optimized: loop vectorized` at your inner loop's line, not
just "vectorized N loops in function" (that count can come from an
unrelated setup loop). If it's missing, or says `missed: ... complicated
access pattern`, disassemble the actual binary and look for the outlined
`._omp_fn.0` symbol — if its body is pure scalar (`vfmadd231ss`, no
`vpermd`/`vfmadd231ps`), that's the same failure. A flat %TPP alongside
perfect speedup is the measurement-side symptom that should prompt this
check in the first place.

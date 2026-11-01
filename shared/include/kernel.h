#ifndef BPM_KERNEL_H
#define BPM_KERNEL_H

#include <string.h>

/* Tuning values are supplied at run time as a generic key-value list, so
 * sweeping any numeric knob (block size, tile size, ...) is a shell loop
 * (sweep.sh --tune KEY=VALUE) rather than a rebuild. This is only for
 * values you want to scan a range of without recompiling per point -- a
 * discrete, developer-chosen code-shape choice (e.g. a schedule clause)
 * is a different kind of knob and stays a compile-time -D, reported via
 * kernel_build_params below.
 *
 * A key a variant never asks for via bpm_tune_get is simply never looked
 * up -- unrecognized keys are harmless. Thread count is deliberately
 * absent: it is an OpenMP runtime setting the harness applies, not
 * something a kernel reads. */
#define BPM_TUNE_MAX 8
#define BPM_TUNE_KEY_MAX 32

typedef struct {
    int n;
    struct {
        char key[BPM_TUNE_KEY_MAX];
        long value;
    } entries[BPM_TUNE_MAX];
} bpm_tune_t;

/* Look up KEY in TUNE, returning DFLT if absent. Call once per knob before
 * a hot loop and keep the result in a local -- this is a linear strcmp
 * scan, not something to call per iteration. */
static inline long bpm_tune_get(const bpm_tune_t *tune, const char *key, long dflt) {
    for (int i = 0; i < tune->n; i++)
        if (strcmp(tune->entries[i].key, key) == 0) return tune->entries[i].value;
    return dflt;
}

/* Non-degenerate tuning values used by the correctness gate (oracle.c,
 * gold.c) instead of an empty tune list. An empty list makes every tuned
 * variant's block/tile-size logic fall back to its own "untuned" default,
 * so the gate never actually exercises the code path it's meant to check
 * -- add an entry here whenever a new tunable key is introduced. A variant
 * that never asks for a given key via bpm_tune_get is unaffected. */
#define BPM_GATE_TUNE ((bpm_tune_t){ .n = 3, .entries = { \
    {"block_size", 64}, {"leaf_size", 64}, {"depth", 5} } })

/* Every variant implements this function. `c` has dA+dB+1 elements
 * (indices 0..dA+dB); kernel_multiply must write all of them.
 * dA and dB are independent -- never assume dA == dB.
 *
 * UPDATES.md U-001-26/08/15: every pointer parameter is restrict-qualified.
 * Without it the compiler must assume c[k] may alias a[i] or b[j], which
 * blocks hoisting the accumulator out of the inner loop and therefore blocks
 * vectorisation -- a measurement then reports an aliasing artefact rather
 * than the algorithm. `restrict` is a promise the caller must keep: the
 * harness allocates a, b, and c as separate arrays, and a variant that
 * aliases them internally violates the contract. Note the qualifier must
 * appear on each variant's *definition* to affect its codegen; repeating it
 * here keeps the declaration honest about the contract. */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune);

/* UPDATES.md U-002-26/08/15: a parameter fixed at compile time by a -D is
 * reported per observation, like a runtime one. It cannot travel through
 * bpm_tune_t -- by the time the binary runs, the value is already baked in --
 * so the binary self-reports it instead, and only the binary can: the shell
 * that invoked it never saw the -D.
 *
 * Returns a `key=value;key=value` string, e.g. "sched=dynamic,8" or
 * "unroll=2". The collector splits it into one trials.csv column per key, so
 * the harness never learns which knobs exist; a variant naming a new one needs
 * no change here or in the collector. Values may contain commas (a schedule
 * clause does), so pairs are `;`-separated and the field is quoted on output.
 *
 * A variant with no compile-time parameters defines nothing: time_main.c
 * carries a weak definition returning "". */
const char *kernel_build_params(void);

#endif

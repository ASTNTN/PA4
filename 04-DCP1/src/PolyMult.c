#include <stdlib.h>
#include <string.h>

#include "kernel.h"
#include "accumulate.h"

/* DCP1: DCQ2 (04-DCQ2) parallelized with OpenMP tasks, races on c handled
 * by a task reduction.
 *
 * Sequential part (unchanged from DCQ2): dcq(a, na, b, nb, c) adds
 * a[0..na) * b[0..nb) into c[0..na+nb-1); OPQ leaf when both ranges <=
 * leaf; otherwise always quadrants, a split at na/2, b split at nb/2
 * rounded down to 16 floats (fallback nb/2 when nb < 32); b read from a
 * 64-byte-aligned copy.
 *
 * Parallel part:
 * - One thread (single) opens a taskgroup with task_reduction(+: c[:n])
 *   (and comp[:n] in the checking build) and calls dcp on the whole
 *   problem.
 * - dcp at recursion depth d < max_depth spawns each of the 4 non-empty
 *   sub-multiplies as a task.
 *     - A child that will do arithmetic (it is a leaf, or it sits at
 *       max_depth) is spawned with in_reduction(+: c[:n]): it runs the
 *       sequential dcq on its thread's private copy of c, at the child's
 *       offset.
 *     - Any other child only spawns further tasks and never writes c, so
 *       it is a plain task and passes the original c pointer on.
 * - No taskwait: the end of the taskgroup waits for every descendant task
 *   and then combines the private copies into c.
 * - Without -fopenmp the pragmas are ignored and this is DCQ2.
 *
 * Tuning: --tune leaf_size=N (fallback 4096), --tune depth=N (task-spawn
 * cutoff, fallback 5 = the shared gate's value). */

#ifdef CHECKING
#define COMP_PARAM , double *restrict comp
#define COMP_ARG(off) , comp + (off)
#define COMP_BASE_PARAM , double *comp
#define COMP_BASE_ARG , comp
#else
#define COMP_PARAM
#define COMP_ARG(off)
#define COMP_BASE_PARAM
#define COMP_BASE_ARG
#endif

static inline int split_b(int nb) {
    return (nb >= 32) ? ((nb / 2) & ~15) : (nb / 2);
}

/* Sequential DCQ2 recursion (see header comment). */
static void dcq(const float *restrict a, int na,
                const float *restrict b, int nb,
                float *restrict c COMP_PARAM, int leaf) {
    if (na <= 0 || nb <= 0) return;

    if (na <= leaf && nb <= leaf) {
        for (int i = 0; i < na; i++) {
            for (int j = 0; j < nb; j++) {
                BPM_ACC(c, comp, i + j, a[i] * b[j]);
            }
        }
        return;
    }

    int ha = na / 2;
    int hb = split_b(nb);
    dcq(a,      ha,      b,      hb,      c           COMP_ARG(0),       leaf);
    dcq(a,      ha,      b + hb, nb - hb, c + hb      COMP_ARG(hb),      leaf);
    dcq(a + ha, na - ha, b,      hb,      c + ha      COMP_ARG(ha),      leaf);
    dcq(a + ha, na - ha, b + hb, nb - hb, c + ha + hb COMP_ARG(ha + hb), leaf);
}

static void dcp(const float *a, int na, const float *b, int nb,
                float *c COMP_BASE_PARAM, int n, int off,
                int leaf, int depth, int max_depth);

/* Spawn one child sub-multiply (a, na) x (b, nb) at offset off into c as a
 * task. c (and comp) are the base pointers named in the task_reduction. */
static void spawn(const float *a, int na, const float *b, int nb,
                  float *c COMP_BASE_PARAM, int n, int off,
                  int leaf, int depth, int max_depth) {
    if (na <= 0 || nb <= 0) return;

    int works = (depth >= max_depth) || (na <= leaf && nb <= leaf);
    if (works) {
#ifdef CHECKING
        #pragma omp task in_reduction(+: c[:n], comp[:n])
#else
        #pragma omp task in_reduction(+: c[:n])
#endif
        dcq(a, na, b, nb, c + off COMP_ARG(off), leaf);
    } else {
        #pragma omp task
        dcp(a, na, b, nb, c COMP_BASE_ARG, n, off, leaf, depth, max_depth);
    }
}

/* Spawn the 4 quadrant sub-multiplies of (a, na) x (b, nb) as tasks.
 * Called only for a non-leaf node at depth < max_depth. */
static void dcp(const float *a, int na, const float *b, int nb,
                float *c COMP_BASE_PARAM, int n, int off,
                int leaf, int depth, int max_depth) {
    int ha = na / 2;
    int hb = split_b(nb);
    int d = depth + 1;
    spawn(a,      ha,      b,      hb,      c COMP_BASE_ARG, n, off,           leaf, d, max_depth);
    spawn(a,      ha,      b + hb, nb - hb, c COMP_BASE_ARG, n, off + hb,      leaf, d, max_depth);
    spawn(a + ha, na - ha, b,      hb,      c COMP_BASE_ARG, n, off + ha,      leaf, d, max_depth);
    spawn(a + ha, na - ha, b + hb, nb - hb, c COMP_BASE_ARG, n, off + ha + hb, leaf, d, max_depth);
}

void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    long leaf_val = bpm_tune_get(tune, "leaf_size", 0);
    int leaf = (leaf_val > 0) ? (int)leaf_val : 4096;
    long depth_val = bpm_tune_get(tune, "depth", -1);
    int max_depth = (depth_val >= 0) ? (int)depth_val : 5;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    /* 64-byte-aligned copy of b; size rounded up to whole 64-byte lines
     * (aligned_alloc requires a multiple of the alignment). */
    int nA = dA + 1, nB = dB + 1;
    size_t bbytes = (((size_t)nB * sizeof(float) + 63) / 64) * 64;
    float *bb = (float *)aligned_alloc(64, bbytes);
    memcpy(bb, b, (size_t)nB * sizeof(float));

    BPM_COMP_DECL(comp, n);

    if (max_depth == 0 || (nA <= leaf && nB <= leaf)) {
        /* Nothing to spawn: run the whole problem sequentially. */
        dcq(a, nA, bb, nB, c COMP_ARG(0), leaf);
    } else {
        float *cr = c;
#ifdef CHECKING
        double *compr = comp;
        #pragma omp parallel
        #pragma omp single
        #pragma omp taskgroup task_reduction(+: cr[:n], compr[:n])
        dcp(a, nA, bb, nB, cr, compr, n, 0, leaf, 0, max_depth);
#else
        #pragma omp parallel
        #pragma omp single
        #pragma omp taskgroup task_reduction(+: cr[:n])
        dcp(a, nA, bb, nB, cr, n, 0, leaf, 0, max_depth);
#endif
    }

    BPM_COMP_FREE(comp);
    free(bb);
}

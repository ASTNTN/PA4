#include <stdlib.h>
#include <string.h>

#include "kernel.h"
#include "accumulate.h"

/* DCP2: DCQ2 (04-DCQ2) parallelized with OpenMP tasks, no reduction:
 * races on c are avoided by ordering, with a taskwait.
 *
 * Sequential part (unchanged from DCQ2): dcq(a, na, b, nb, c) adds
 * a[0..na) * b[0..nb) into c[0..na+nb-1); OPQ leaf when both ranges <=
 * leaf; otherwise always quadrants, a split at ha = na/2, b split at hb =
 * nb/2 rounded down to 16 floats (fallback nb/2 when nb < 32); b read from
 * a 64-byte-aligned copy.
 *
 * Parallel part, dcp at recursion depth d:
 * - If d >= max_depth or the node is a leaf: sequential dcq.
 * - Otherwise:
 *     task LL = a_lo x b_lo  -> c[0 .. ha+hb-2]        (recursive dcp)
 *     task HH = a_hi x b_hi  -> c[ha+hb .. na+nb-2]    (recursive dcp)
 *     taskwait
 *     LH = a_lo x b_hi -> c[hb ..]   sequential dcq, calling thread
 *     HL = a_hi x b_lo -> c[ha ..]   sequential dcq, calling thread
 *   LL and HH write disjoint ranges of c, so they run concurrently. LH
 *   and HL overlap LL, HH and each other, so they run after the taskwait,
 *   one after the other.
 * - The taskwait waits for LL and HH only (direct children); each child
 *   returns only after its own taskwait and its own LH/HL, so every
 *   descendant has finished when the taskwait returns.
 * - All tasks write straight into the shared c (and comp, in the checking
 *   build, at the same offsets).
 * - Without -fopenmp the pragmas are ignored: LL, HH, LH, HL in that order
 *   on one thread (a different quadrant order from DCQ2's LL, LH, HL, HH).
 *
 * Tuning: --tune leaf_size=N (fallback 4096), --tune depth=N (task-spawn
 * cutoff, fallback 5 = the shared gate's value). */

#ifdef CHECKING
#define COMP_PARAM , double *restrict comp
#define COMP_ARG(off) , comp + (off)
#else
#define COMP_PARAM
#define COMP_ARG(off)
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

/* Parallel recursion (see header comment). */
static void dcp(const float *restrict a, int na,
                const float *restrict b, int nb,
                float *restrict c COMP_PARAM,
                int leaf, int depth, int max_depth) {
    if (na <= 0 || nb <= 0) return;

    if (depth >= max_depth || (na <= leaf && nb <= leaf)) {
        dcq(a, na, b, nb, c COMP_ARG(0), leaf);
        return;
    }

    int ha = na / 2;
    int hb = split_b(nb);
    int d = depth + 1;

    #pragma omp task
    dcp(a,      ha,      b,      hb,      c           COMP_ARG(0),       leaf, d, max_depth);
    #pragma omp task
    dcp(a + ha, na - ha, b + hb, nb - hb, c + ha + hb COMP_ARG(ha + hb), leaf, d, max_depth);
    #pragma omp taskwait

    dcq(a,      ha,      b + hb, nb - hb, c + hb      COMP_ARG(hb),      leaf);
    dcq(a + ha, na - ha, b,      hb,      c + ha      COMP_ARG(ha),      leaf);
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

    #pragma omp parallel
    #pragma omp single
    dcp(a, nA, bb, nB, c COMP_ARG(0), leaf, 0, max_depth);

    BPM_COMP_FREE(comp);
    free(bb);
}

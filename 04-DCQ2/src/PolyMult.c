#include <stdlib.h>
#include <string.h>

#include "kernel.h"
#include "accumulate.h"

/* DCQ2: DCQ (04-DCQ) with every leaf's b sub-range starting on a 64-byte
 * boundary.
 *
 * dcq(a, na, b, nb, c) adds a[0..na) * b[0..nb) into c[0..na+nb-1).
 * - Leaf: when both na <= leaf and nb <= leaf, OPQ's loop nest (i outer,
 *   j inner) over the sub-ranges.
 * - Otherwise always split into quadrants: a at ha = na/2, b at hb, giving
 *   4 sub-multiplies, each adding into c at offset (a offset + b offset).
 *   Empty halves return immediately.
 *
 * Alignment of b:
 * - Once per call, b is copied into a 64-byte-aligned buffer (inside the
 *   timed kernel); the recursion reads only the copy.
 * - b's split point hb is nb/2 rounded down to a multiple of 16 floats
 *   (64 bytes), so if a b sub-range starts aligned, both halves do. By
 *   induction every b sub-range, and so every leaf's b window, starts on a
 *   64-byte boundary.
 * - Fallback: when nb < 32, nb/2 rounded down to 16 would be 0 (an empty
 *   half and no progress), so hb = nb/2 unrounded. Only reachable with
 *   leaf_size < 32; those sub-ranges are then not aligned.
 * - a's split and c are unchanged (not aligned).
 *
 * Tuning: --tune leaf_size=N (fallback 4096, the DCQ.2 best).
 * In the checking build the Kahan compensation array travels with c, at
 * the same offset. */

#ifdef CHECKING
#define COMP_PARAM , double *restrict comp
#define COMP_ARG(off) , comp + (off)
#else
#define COMP_PARAM
#define COMP_ARG(off)
#endif

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
    int hb = (nb >= 32) ? ((nb / 2) & ~15) : (nb / 2);
    dcq(a,      ha,      b,      hb,      c           COMP_ARG(0),       leaf);
    dcq(a,      ha,      b + hb, nb - hb, c + hb      COMP_ARG(hb),      leaf);
    dcq(a + ha, na - ha, b,      hb,      c + ha      COMP_ARG(ha),      leaf);
    dcq(a + ha, na - ha, b + hb, nb - hb, c + ha + hb COMP_ARG(ha + hb), leaf);
}

void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    long leaf_val = bpm_tune_get(tune, "leaf_size", 0);
    int leaf = (leaf_val > 0) ? (int)leaf_val : 4096;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    /* 64-byte-aligned copy of b; size rounded up to whole 64-byte lines
     * (aligned_alloc requires a multiple of the alignment). */
    int nB = dB + 1;
    size_t bbytes = (((size_t)nB * sizeof(float) + 63) / 64) * 64;
    float *bb = (float *)aligned_alloc(64, bbytes);
    memcpy(bb, b, (size_t)nB * sizeof(float));

    BPM_COMP_DECL(comp, n);

    dcq(a, dA + 1, bb, nB, c COMP_ARG(0), leaf);

    BPM_COMP_FREE(comp);
    free(bb);
}

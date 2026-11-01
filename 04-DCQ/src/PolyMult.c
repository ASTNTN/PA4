#include "kernel.h"
#include "accumulate.h"

/* Divide-and-conquer (VARIANTS.md 04-DCQ), naive baseline.
 *
 * dcq(a, na, b, nb, c) adds a[0..na) * b[0..nb) into c[0..na+nb-1).
 * - Leaf: when both na <= leaf and nb <= leaf, OPQ's loop nest (i outer,
 *   j inner) over the sub-ranges.
 * - Otherwise always split into quadrants: a = a_lo | a_hi at ha = na/2,
 *   b = b_lo | b_hi at hb = nb/2, giving 4 sub-multiplies, each adding into
 *   c at offset (a offset + b offset). A half of length 0 (e.g. halving a
 *   length-1 range) is an empty sub-problem and returns immediately.
 *
 * Tuning: --tune leaf_size=N (fallback 64).
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

    int ha = na / 2, hb = nb / 2;
    dcq(a,      ha,      b,      hb,      c           COMP_ARG(0),       leaf);
    dcq(a,      ha,      b + hb, nb - hb, c + hb      COMP_ARG(hb),      leaf);
    dcq(a + ha, na - ha, b,      hb,      c + ha      COMP_ARG(ha),      leaf);
    dcq(a + ha, na - ha, b + hb, nb - hb, c + ha + hb COMP_ARG(ha + hb), leaf);
}

void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    long leaf_val = bpm_tune_get(tune, "leaf_size", 0);
    int leaf = (leaf_val > 0) ? (int)leaf_val : 64;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    dcq(a, dA + 1, b, dB + 1, c COMP_ARG(0), leaf);

    BPM_COMP_FREE(comp);
}

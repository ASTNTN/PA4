#include "kernel.h"
#include "accumulate.h"

/* Blocked outer-product (VARIANTS.md 03-BKQ): OPQ's i/j loops tiled into
 * square bs x bs blocks, 4-loop structure (ii, jj, i, j). Edge blocks are
 * left incomplete -- the inner bounds clip at dA/dB. Block size is the
 * runtime knob block_size (--tune block_size=N), default 64. */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    long bs_val = bpm_tune_get(tune, "block_size", 0);
    int bs = (bs_val > 0) ? (int)bs_val : 64;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    for (int ii = 0; ii <= dA; ii += bs) {
        int iend = (ii + bs <= dA + 1) ? ii + bs : dA + 1;
        for (int jj = 0; jj <= dB; jj += bs) {
            int jend = (jj + bs <= dB + 1) ? jj + bs : dB + 1;
            for (int i = ii; i < iend; i++) {
                for (int j = jj; j < jend; j++) {
                    BPM_ACC(c, comp, i + j, a[i] * b[j]);
                }
            }
        }
    }

    BPM_COMP_FREE(comp);
}

#include "kernel.h"
#include "accumulate.h"

/* Blocked outer-product with unroll-and-jam (03-BKQ2, 03-BKQ3): BKQ's 4-loop tiling
 * (ii, jj, i, j), square bs x bs blocks, edge blocks left incomplete. Inside
 * a block, rows are taken R = 8 at a time and their j loops are fused into
 * one loop over t, so all 8 rows add into the same c[i0 + t] while it is
 * held in a register:
 *
 *   row r of the group uses j = t - r, so c[i0 + t] += a[i0 + r] * b[t - r]
 *
 * The fused loop covers t = jj+R-1 .. jend-1, where every row's j lies in
 * [jj, jend). The ragged ends (row r's j < jj+R-1-r and j >= jend-r), blocks
 * narrower than R, and the leftover rows when the block height isn't a
 * multiple of R run as plain OPQ rows. Block size is the runtime knob
 * block_size (--tune block_size=N), default 64; R is fixed at 8.
 *
 * 03-BKQ3: the timed build's -ffast-math lets GCC regroup the 8 products
 * into pairs (4 mul + 4 FMA + 4 add per 8 FMAs of work). no-associative-math
 * on this function only keeps them as one chain of 8 FMAs; the rest of the
 * build keeps -ffast-math. */
#define R 8

__attribute__((optimize("no-associative-math")))
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

            int i0 = ii;
            if (jend - jj >= R) {
                for (; i0 + R <= iend; i0 += R) {
                    const float a0 = a[i0],     a1 = a[i0 + 1];
                    const float a2 = a[i0 + 2], a3 = a[i0 + 3];
                    const float a4 = a[i0 + 4], a5 = a[i0 + 5];
                    const float a6 = a[i0 + 6], a7 = a[i0 + 7];

                    /* fused interior: all 8 rows into c[i0 + t] */
                    for (int t = jj + R - 1; t < jend; t++) {
                        BPM_ACC(c, comp, i0 + t, a0 * b[t]);
                        BPM_ACC(c, comp, i0 + t, a1 * b[t - 1]);
                        BPM_ACC(c, comp, i0 + t, a2 * b[t - 2]);
                        BPM_ACC(c, comp, i0 + t, a3 * b[t - 3]);
                        BPM_ACC(c, comp, i0 + t, a4 * b[t - 4]);
                        BPM_ACC(c, comp, i0 + t, a5 * b[t - 5]);
                        BPM_ACC(c, comp, i0 + t, a6 * b[t - 6]);
                        BPM_ACC(c, comp, i0 + t, a7 * b[t - 7]);
                    }

                    /* ragged ends of each row */
                    for (int r = 0; r < R; r++) {
                        int i = i0 + r;
                        for (int j = jj; j < jj + R - 1 - r; j++)
                            BPM_ACC(c, comp, i + j, a[i] * b[j]);
                        for (int j = jend - r; j < jend; j++)
                            BPM_ACC(c, comp, i + j, a[i] * b[j]);
                    }
                }
            }

            /* leftover rows, or every row of a block narrower than R */
            for (int i = i0; i < iend; i++) {
                for (int j = jj; j < jend; j++) {
                    BPM_ACC(c, comp, i + j, a[i] * b[j]);
                }
            }
        }
    }

    BPM_COMP_FREE(comp);
}

#include "kernel.h"
#include "accumulate.h"

/* Diagonal traversal (VARIANTS.md 00-GSQ): c[k] is the sum over the
 * anti-diagonal i+j=k. GSQ has no tuning parameters. */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    (void)tune;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    for (int k = 0; k < n; k++) {
        int jmin = (k - dA > 0) ? (k - dA) : 0;
        int jmax = (dB < k) ? dB : k;
        for (int j = jmin; j <= jmax; j++) {
            int i = k - j;
            BPM_ACC(c, comp, k, a[i] * b[j]);
        }
    }

    BPM_COMP_FREE(comp);
}

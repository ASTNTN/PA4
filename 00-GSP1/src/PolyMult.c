#include "kernel.h"
#include "accumulate.h"

/* GSP1: the outer loop runs over the output index k, so each iteration owns
 * c[k] (and comp[k]); the inner loop derives the i, j pairs with i + j = k.
 * Outer loop is distributed round-robin: schedule(static, 1). No tuning
 * parameters. */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    (void)tune;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    #pragma omp parallel for schedule(static, 1)
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

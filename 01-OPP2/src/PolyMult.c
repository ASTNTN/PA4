#include "kernel.h"
#include "accumulate.h"

/* Outer-product loop order (VARIANTS.md 01-OPQ): each (i, j) pair
 * contributes a[i]*b[j] to c[i+j]. OPQ has no tuning parameters. */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    (void)tune;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    for (int i = 0; i <= dA; i++) {
        for (int j = 0; j <= dB; j++) {
            BPM_ACC(c, comp, i + j, a[i] * b[j]);
        }
    }

    BPM_COMP_FREE(comp);
}

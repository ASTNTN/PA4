#include "kernel.h"
#include "accumulate.h"

/* OPP1: outer-product loop order (for i, for j), with the inner j loop
 * distributed round-robin: schedule(static, 1). For a fixed i, distinct j
 * write distinct c[i+j] (and comp[i+j]). No tuning parameters. */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    (void)tune;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    for (int i = 0; i <= dA; i++) {
        #pragma omp parallel for schedule(static, 1)
        for (int j = 0; j <= dB; j++) {
            BPM_ACC(c, comp, i + j, a[i] * b[j]);
        }
    }

    BPM_COMP_FREE(comp);
}

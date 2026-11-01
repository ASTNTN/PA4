#include "kernel.h"
#include "accumulate.h"

/* OPP13: outer-product loop order (for i, for j). One parallel region
 * encloses the serial i loop, so every thread runs all i iterations; the
 * inner j loop is a worksharing loop distributed round-robin:
 * schedule(static). For a fixed i, distinct j write distinct c[i+j]
 * (and comp[i+j]). No tuning parameters. */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    (void)tune;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    #pragma omp parallel
    for (int i = 0; i <= dA; i++) {
        #pragma omp for schedule(static)
        for (int j = 0; j <= dB; j++) {
            BPM_ACC(c, comp, i + j, a[i] * b[j]);
        }
    }

    BPM_COMP_FREE(comp);
}

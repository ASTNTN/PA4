#include <stdio.h>
#include <omp.h>
#include <string.h>

#include "kernel.h"
#include "accumulate.h"

/* OPP18: outer-product loop order (for i, for j). */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    (void)tune;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    #pragma omp parallel
    {
        #pragma omp for reduction(+:c[:n]) schedule(static)
        for (int i = 0; i <= dA; i++) {
            for (int j = 0; j <= dB; j++) {
                BPM_ACC(c, comp, i + j, a[i] * b[j]);
            }
        }
    }

    BPM_COMP_FREE(comp);
}

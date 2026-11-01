#include <omp.h>

#include "kernel.h"
#include "accumulate.h"

/* EXP12: EXQ's loop order (j outer, i inner), with the outer j loop
 * parallelized: schedule(static, 16). No tuning parameters. */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    (void)tune;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    {
        for (int j = 0; j <= dB; j++) {
            #pragma omp parallel for schedule(static, 16)
            for (int i = 0; i <= dA; i++) {
                BPM_ACC(c, comp, i + j, a[i] * b[j]);
            }
        }
    }

    BPM_COMP_FREE(comp);
}

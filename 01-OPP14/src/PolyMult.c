#include <stdio.h>
#include <omp.h>

#include "kernel.h"
#include "accumulate.h"

/* OPP14: outer-product loop order (for i, for j). Each thread reports how many iterations it is performing. */
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    (void)tune;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    BPM_COMP_DECL(comp, n);

    #pragma omp parallel
    {
        long iters = 0;  /* this thread's count of (i,j) iterations executed */
        #pragma omp for collapse(2) reduction(+:c[:n]) schedule(static)
        for (int i = 0; i <= dA; i++) {
            for (int j = 0; j <= dB; j++) {
                BPM_ACC(c, comp, i + j, a[i] * b[j]);
                iters++;
            }
        }
        #pragma omp critical
        fprintf(stderr, "OPP14 thread %d/%d iters=%ld\n",
                omp_get_thread_num(), omp_get_num_threads(), iters);
    }

    BPM_COMP_FREE(comp);
}

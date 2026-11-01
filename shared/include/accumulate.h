#ifndef BPM_ACCUMULATE_H
#define BPM_ACCUMULATE_H

#include <stdlib.h>

/* Use BPM_ACC for every accumulation into the output array.
 *
 *   production build (-ffast-math):  c[k] += term
 *   checking build   (-DCHECKING):   Kahan-compensated accumulation
 *
 * The loop structure is identical in both builds; only the accumulation
 * changes. That is what makes a passing checking build evidence about the
 * production build -- control flow (bounds, tiling, ownership, edge
 * handling) is the same code in both.
 *
 * The compensation array is named explicitly rather than hidden in a
 * file-scope static, so a strategy that gives each thread a private c[]
 * (e.g. a DCP private-copies strategy) can give it a private comp[] too.
 * In a production build the array is compiled out entirely, so it costs
 * no memory on timed runs. */

#ifdef CHECKING

#ifdef __FAST_MATH__
#error "CHECKING build must not use -ffast-math (would delete Kahan compensation)"
#endif

#define BPM_COMP_DECL(name, n)  double *name = (double *)calloc((size_t)(n), sizeof(double))
#define BPM_COMP_FREE(name)     free(name)

/* Note the compensation is computed from the *stored float*, not from the
 * double intermediate. The accumulator lives in float while the running
 * sum is formed in double, so two errors occur per step: the double
 * addition, and the truncation back to float. Deriving comp from the
 * double intermediate captures only the first -- which is near zero --
 * and silently drops the float truncation, the error that actually
 * accumulates. ((double)stored - prev) is what genuinely landed in c[k];
 * subtracting the y we intended to add leaves everything that was lost. */
#define BPM_ACC(c, comp, k, term)                                  \
    do {                                                           \
        int    bpm_k_ = (k);                                       \
        double bpm_prev_ = (double)(c)[bpm_k_];                    \
        double bpm_y_ = (double)(term) - (comp)[bpm_k_];           \
        double bpm_t_ = bpm_prev_ + bpm_y_;                        \
        float  bpm_f_ = (float)bpm_t_;                             \
        (comp)[bpm_k_] = ((double)bpm_f_ - bpm_prev_) - bpm_y_;    \
        (c)[bpm_k_] = bpm_f_;                                      \
    } while (0)

#else

#define BPM_COMP_DECL(name, n)  ((void)0)
#define BPM_COMP_FREE(name)     ((void)0)

#define BPM_ACC(c, comp, k, term)  (c)[(k)] += (term);

#endif

#endif

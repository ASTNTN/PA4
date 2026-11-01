#ifndef BPM_ORACLE_H
#define BPM_ORACLE_H

/* Runs the fixed suite of independently-computable oracle cases (see
 * DESIGN.md's "The Oracle and the Tester") against this build's
 * kernel_multiply and prints one PASS/FAIL line per case plus a summary.
 * Returns the number of failed cases (0 = all passed). */
int bpm_run_oracle_suite(void);

/* The size configurations every gate runs. Shared with the gold suite so the
 * two gates cannot drift onto different coverage. */
typedef struct { long dA, dB; } bpm_size_cfg_t;
extern const bpm_size_cfg_t bpm_check_sizes[];
extern const int bpm_n_check_sizes;

/* Sum of |a[i]*b[j]| over anti-diagonal k -- the quantity C7 normalises the
 * error bound by. Shared so the oracle gate and the gold gate normalise by
 * exactly the same thing. */
double bpm_term_magnitude_sum(const float *a, long dA,
                              const float *b, long dB, long k);

#endif

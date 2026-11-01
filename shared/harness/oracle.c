#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <float.h>
#include "oracle.h"
#include "../include/kernel.h"

double bpm_term_magnitude_sum(const float *a, long dA, const float *b, long dB, long k) {
    long jmin = (k - dA > 0) ? (k - dA) : 0;
    long jmax = (dB < k) ? dB : k;
    double mag = 0.0;
    for (long j = jmin; j <= jmax; j++) {
        long i = k - j;
        mag += fabs((double)a[i]) * fabs((double)b[j]);
    }
    return mag;
}

static int validate_case(const char *name, long dA, long dB,
                          const float *a, const float *b, const float *expected) {
    long n = dA + dB + 1;
    float *actual = malloc(sizeof(float) * (size_t)n);
    bpm_tune_t tune = BPM_GATE_TUNE;
    kernel_multiply(a, (int)dA, b, (int)dB, actual, &tune);

    long bad = 0;
    double worst_ratio = 0.0;
    for (long k = 0; k < n; k++) {
        double mag = bpm_term_magnitude_sum(a, dA, b, dB, k);
        double bound = 3.0 * FLT_EPSILON * mag;
        if (bound < 3.0 * FLT_EPSILON) bound = 3.0 * FLT_EPSILON; /* mag==0 -> expect exact 0 */
        double err = fabs((double)actual[k] - (double)expected[k]);
        double ratio = err / bound;
        if (ratio > worst_ratio) worst_ratio = ratio;
        if (err > bound) {
            if (bad < 5)
                printf("    mismatch k=%ld actual=%.9g expected=%.9g err=%.3e bound=%.3e\n",
                       k, (double)actual[k], (double)expected[k], err, bound);
            bad++;
        }
    }
    printf("  [%-21s] dA=%-6ld dB=%-6ld %s  (%ld/%ld mismatched, worst err/bound=%.3f)\n",
           name, dA, dB, bad == 0 ? "PASS" : "FAIL", bad, n, worst_ratio);
    free(actual);
    return bad == 0 ? 0 : 1;
}

static int constants_case(long dA, long dB) {
    long nA = dA + 1, nB = dB + 1, n = dA + dB + 1;
    float *a = malloc(sizeof(float) * (size_t)nA);
    float *b = malloc(sizeof(float) * (size_t)nB);
    float *expected = malloc(sizeof(float) * (size_t)n);
    float alpha = 3.5f, beta = -2.25f; /* exact in binary (7/2, -9/4): keeps the oracle itself exact */
    for (long i = 0; i < nA; i++) a[i] = alpha;
    for (long j = 0; j < nB; j++) b[j] = beta;
    for (long k = 0; k < n; k++) {
        long jmin = (k - dA > 0) ? (k - dA) : 0;
        long jmax = (dB < k) ? dB : k;
        expected[k] = (float)((double)alpha * (double)beta * (double)(jmax - jmin + 1));
    }
    int rc = validate_case("constants", dA, dB, a, b, expected);
    free(a); free(b); free(expected);
    return rc;
}

static int impulse_case(long dA, long dB) {
    long nA = dA + 1, nB = dB + 1, n = dA + dB + 1;
    float *a = calloc((size_t)nA, sizeof(float));
    float *b = malloc(sizeof(float) * (size_t)nB);
    float *expected = calloc((size_t)n, sizeof(float));
    long i0 = dA / 3; /* off-edge index: catches offset/bounds bugs an edge impulse would miss */
    a[i0] = 1.0f;
    for (long j = 0; j < nB; j++) b[j] = (float)(j + 1); /* small-integer ramp, exact in float */
    for (long j = 0; j < nB; j++) expected[i0 + j] = b[j];
    int rc = validate_case("impulse", dA, dB, a, b, expected);
    free(a); free(b); free(expected);
    return rc;
}

/* Substitutes DESIGN.md's illustrative "ramp up to midpoint then down"
 * example with a linear ramp times a constant: still a non-constant,
 * non-impulse pattern, but its convolution reduces to one arithmetic
 * series per k, keeping the oracle itself simple and obviously correct. */
static int pattern_case(long dA, long dB) {
    long nA = dA + 1, nB = dB + 1, n = dA + dB + 1;
    float *a = malloc(sizeof(float) * (size_t)nA);
    float *b = malloc(sizeof(float) * (size_t)nB);
    float *expected = calloc((size_t)n, sizeof(float));
    for (long i = 0; i < nA; i++) a[i] = (float)(i + 1);
    float beta = 1.5f;
    for (long j = 0; j < nB; j++) b[j] = beta;
    for (long k = 0; k < n; k++) {
        long imin = (k - dB > 0) ? (k - dB) : 0;
        long imax = (dA < k) ? dA : k;
        if (imin > imax) continue;
        double lo = imin + 1, hi = imax + 1;
        double count = hi - lo + 1.0;
        double sum = count * (lo + hi) / 2.0; /* arithmetic series closed form */
        expected[k] = (float)((double)beta * sum);
    }
    int rc = validate_case("deterministic-pattern", dA, dB, a, b, expected);
    free(a); free(b); free(expected);
    return rc;
}

static int single_random_case(long dA, long dB, unsigned seed) {
    long nA = dA + 1, nB = dB + 1, n = dA + dB + 1;
    float *a = calloc((size_t)nA, sizeof(float));
    float *b = malloc(sizeof(float) * (size_t)nB);
    float *expected = calloc((size_t)n, sizeof(float));
    long i0 = dA / 3;
    a[i0] = 1.0f;
    srand(seed);
    for (long j = 0; j < nB; j++) b[j] = ((float)rand() / (float)RAND_MAX) * 100.0f;
    for (long j = 0; j < nB; j++) expected[i0 + j] = b[j];
    int rc = validate_case("single-random-operand", dA, dB, a, b, expected);
    free(a); free(b); free(expected);
    return rc;
}

/* Mixed-sign cases. Both satisfy DESIGN.md validation rule 2, which the
 * four cases above do not: they all produce single-signed terms along
 * every anti-diagonal, so mag[k] == |c[k]| and the condition number is 1
 * everywhere -- cancellation is never exercised.
 *
 * Closed form for both: with t_j = a[k-j]*(-1)^j, adjacent terms pair up as
 *   t_j + t_{j+1} = (-1)^j * ( a[k-j] - a[k-j-1] )
 * which for a[i] = i+1 telescopes to (-1)^j, and for a[i] = 1 to 0. */

/* a[i] = 1, b[j] = (-1)^j. Result stays in {-1, 0, 1}: exactly
 * representable, so the expected error is exactly zero. mag[k] = count
 * while |c[k]| <= 1, so the condition number grows without bound -- a
 * result-normalised gate is provably unsatisfiable here, while the
 * mag-normalised gate is tight. Any nonzero error is a structural bug. */
static int alternating_unit_case(long dA, long dB) {
    long nA = dA + 1, nB = dB + 1, n = dA + dB + 1;
    float *a = malloc(sizeof(float) * (size_t)nA);
    float *b = malloc(sizeof(float) * (size_t)nB);
    float *expected = calloc((size_t)n, sizeof(float));
    for (long i = 0; i < nA; i++) a[i] = 1.0f;
    for (long j = 0; j < nB; j++) b[j] = (j % 2 == 0) ? 1.0f : -1.0f;
    for (long k = 0; k < n; k++) {
        long jmin = (k - dA > 0) ? (k - dA) : 0;
        long jmax = (dB < k) ? dB : k;
        if (jmin > jmax) continue;
        long count = jmax - jmin + 1;
        /* complete pairs cancel to 0; an odd count leaves the last term */
        expected[k] = (count % 2 == 0) ? 0.0f
                                       : ((jmax % 2 == 0) ? 1.0f : -1.0f);
    }
    int rc = validate_case("alternating-unit", dA, dB, a, b, expected);
    free(a); free(b); free(expected);
    return rc;
}

/* a[i] = i+1, b[j] = (-1)^j. mag[k] is O(n^2) while |c[k]| is O(n), and at
 * large degree the term magnitudes exceed 2^24, so genuine float roundoff
 * occurs -- this is the case where the checking build's compensation has
 * real work to do. Partial sums are integers well inside 2^53, so the
 * double-precision closed form below is exact. */
static int alternating_ramp_case(long dA, long dB) {
    long nA = dA + 1, nB = dB + 1, n = dA + dB + 1;
    float *a = malloc(sizeof(float) * (size_t)nA);
    float *b = malloc(sizeof(float) * (size_t)nB);
    float *expected = calloc((size_t)n, sizeof(float));
    for (long i = 0; i < nA; i++) a[i] = (float)(i + 1);
    for (long j = 0; j < nB; j++) b[j] = (j % 2 == 0) ? 1.0f : -1.0f;
    for (long k = 0; k < n; k++) {
        long jmin = (k - dA > 0) ? (k - dA) : 0;
        long jmax = (dB < k) ? dB : k;
        if (jmin > jmax) continue;
        long count = jmax - jmin + 1;
        double sign_lo = (jmin % 2 == 0) ? 1.0 : -1.0;
        double value = (double)(count / 2) * sign_lo;   /* each complete pair -> (-1)^jmin */
        if (count % 2 == 1) {
            double sign_hi = (jmax % 2 == 0) ? 1.0 : -1.0;
            value += sign_hi * (double)(k - jmax + 1);  /* leftover unpaired term */
        }
        expected[k] = (float)value;
    }
    int rc = validate_case("alternating-ramp", dA, dB, a, b, expected);
    free(a); free(b); free(expected);
    return rc;
}

#define BPM_ORACLE_CASES_PER_SIZE 6

/* Declared in oracle.h and shared with the gold suite, so the two gates
 * cannot drift onto different size coverage. */
const bpm_size_cfg_t bpm_check_sizes[] = {
    {500, 500},
    {0, 500},
    {500, 0},
    {0, 0},
    {100000, 3},
    {3, 100000},
    /* Long anti-diagonals: partial sums here exceed 2^24, so the
     * mixed-sign cases exercise genuine float roundoff rather than
     * passing exactly. Without a large *symmetric* size, every
     * diagonal is short and the error bound is never challenged. */
    {20000, 20000},
};
const int bpm_n_check_sizes =
    (int)(sizeof(bpm_check_sizes) / sizeof(bpm_check_sizes[0]));

int bpm_run_oracle_suite(void) {
    int failures = 0;
    for (int s = 0; s < bpm_n_check_sizes; s++) {
        long dA = bpm_check_sizes[s].dA, dB = bpm_check_sizes[s].dB;
        printf("-- dA=%ld dB=%ld --\n", dA, dB);
        failures += constants_case(dA, dB);
        failures += impulse_case(dA, dB);
        failures += pattern_case(dA, dB);
        failures += single_random_case(dA, dB, (unsigned)(1000 + s));
        failures += alternating_unit_case(dA, dB);
        failures += alternating_ramp_case(dA, dB);
    }
    printf("\nOracle suite: %d case(s) failed out of %d\n",
           failures, BPM_ORACLE_CASES_PER_SIZE * bpm_n_check_sizes);
    return failures;
}

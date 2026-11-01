/* 200112L rather than clock_gettime's 199309L: posix_memalign needs it. */
#define _POSIX_C_SOURCE 200112L
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "../include/kernel.h"
#include "args.h"

#ifdef PAR
#include <omp.h>
#endif

#ifndef BPM_VARIANT
#define BPM_VARIANT "unknown"
#endif

/* Harness-level allocation alignment, a compile-time -D like a variant's own
 * tuning knobs (U-002), but living here because it is a property of the
 * harness's a/b/c allocation, not of any kernel. BPM_ALIGN=0 (the default)
 * reproduces the historical malloc behaviour exactly -- this project measured
 * that to land at 16-byte alignment, never 32, so every existing session was
 * taken under that regime. BPM_ALIGN=64 aligns to a full cache line, the
 * value at which no 256-bit vector load can straddle a line boundary. */
#ifndef BPM_ALIGN
#define BPM_ALIGN 0
#endif

static void *bpm_alloc(size_t n_elems) {
    size_t bytes = sizeof(float) * n_elems;
#if BPM_ALIGN > 0
    /* sizeof(float)*n is a multiple of BPM_ALIGN only for particular n, so an
     * unrounded request would still land at a size-dependent offset within an
     * aligned page for most (dA, dB) -- rounding the request up is what makes
     * "aligned" mean the same thing across problem sizes. */
    size_t rounded = ((bytes + BPM_ALIGN - 1) / BPM_ALIGN) * BPM_ALIGN;
    if (rounded == 0) rounded = BPM_ALIGN;
    void *p = NULL;
    if (posix_memalign(&p, BPM_ALIGN, rounded) != 0) return NULL;
    return p;
#else
    return malloc(bytes);
#endif
}

/* Weak default for U-002's compile-time-parameter reporting: a variant that
 * has no -D knobs defines nothing and gets "". A variant that has one defines
 * kernel_build_params() itself, and its strong definition wins at link time.
 * The default lives here rather than in a shared .c file so that adding the
 * mechanism could not break the variants of the concurrent session, whose
 * sources this session must not touch. */
__attribute__((weak))
const char *kernel_build_params(void) { return ""; }

/* CLOCK_MONOTONIC, not gettimeofday: an interval measurement wants a
 * stopwatch, not wall-clock-since-epoch, which NTP can step mid-run. */
static double now_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static void fill_random(float *arr, long n) {
    for (long i = 0; i < n; i++)
        arr[i] = ((float)rand() / (float)RAND_MAX) * 100.0f;
}

int main(int argc, char **argv) {
    bpm_args_t args;
    if (bpm_parse_args(argc, argv, argv[0], NULL, &args) != 0) return 1;
    if (args.help) return 0;

    long dA = args.dA, dB = args.dB;
    long nA = dA + 1, nB = dB + 1, n = dA + dB + 1;
    float *a = bpm_alloc((size_t)nA);
    float *b = bpm_alloc((size_t)nB);
    float *c = bpm_alloc((size_t)n);
    if (!a || !b || !c) {
        fprintf(stderr, "Allocation failed for dA=%ld dB=%ld\n", dA, dB);
        return 1;
    }

    srand((unsigned)time(NULL));
    fill_random(a, nA);
    fill_random(b, nB);

    /* 2 flops per (i,j) pair: one multiply, one add. */
    double flops = 2.0 * (double)nA * (double)nB;

    /* One raw observation per row; no warmups, no discarded reps. Any
     * exclusion is a documented derivation in the collector, never a
     * measurement the binary declines to report. */
    printf("variant,dA,dB,threads");
    for (int i = 0; i < args.tune.n; i++) printf(",%s", args.tune.entries[i].key);
    printf(",build_params,rep,seconds,gflops\n");

    for (int ti = 0; ti < args.nthreads; ti++) {
        long threads = args.threads[ti];
#ifdef PAR
        omp_set_num_threads((int)threads);
#endif
        for (int r = 0; r < args.reps; r++) {
            double t0 = now_seconds();
            kernel_multiply(a, (int)dA, b, (int)dB, c, &args.tune);
            double t1 = now_seconds();
            double seconds = t1 - t0;

            /* align=N is prepended to the kernel's own build_params string,
             * reusing the ';'-separated convention U-002 already established
             * -- the collector splits on ';' with no changes needed, and a
             * variant that never sets BPM_ALIGN keeps reporting exactly what
             * it always has. */
            char build_params[256];
#if BPM_ALIGN > 0
            const char *kparams = kernel_build_params();
            if (kparams[0])
                snprintf(build_params, sizeof build_params, "align=%d;%s", BPM_ALIGN, kparams);
            else
                snprintf(build_params, sizeof build_params, "align=%d", BPM_ALIGN);
#else
            snprintf(build_params, sizeof build_params, "%s", kernel_build_params());
#endif

            /* build_params is quoted: a schedule clause contains a comma. */
            printf("%s,%ld,%ld,%ld", BPM_VARIANT, dA, dB, threads);
            for (int ki = 0; ki < args.tune.n; ki++)
                printf(",%ld", args.tune.entries[ki].value);
            printf(",\"%s\",%d,%.9f,%.3f\n",
                   build_params, r, seconds, flops / seconds / 1e9);
            fflush(stdout);
        }
    }

    free(a);
    free(b);
    free(c);
    bpm_free_args(&args);
    return 0;
}

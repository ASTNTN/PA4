#ifndef BPM_ARGS_H
#define BPM_ARGS_H

#include "../include/kernel.h"

typedef struct {
    long dA, dB;
    long *threads;
    int nthreads;
    int reps;
    bpm_tune_t tune;
    int help;
} bpm_args_t;

/* Parses argv[1..argc-1]. Prints usage and sets args->help=1 on -h/--help
 * (returns 0; caller should exit 0). Returns 0 on success, -1 on a
 * malformed argument (usage is also printed in that case).
 * extra_usage, appended to the printed usage text, may be NULL. */
int bpm_parse_args(int argc, char **argv, const char *progname, const char *extra_usage, bpm_args_t *args);
void bpm_free_args(bpm_args_t *args);

#endif

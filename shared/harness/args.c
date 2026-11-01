#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "args.h"
#include "range.h"

static void usage(const char *progname, const char *extra_usage) {
    printf("Usage: %s [-h|--help] [-dA <int>] [-dB <int>] [-t <range>] [-r <int>]\n", progname);
    printf("               [--block-size <int>] [--leaf-size <int>] [--task-threshold <int>]\n");
    printf("  -dA <int>            degree of polynomial A (default: -dB if given, else 99999)\n");
    printf("  -dB <int>            degree of polynomial B (default: -dA if given, else 99999)\n");
    printf("  -t <range>           thread count(s): enumeration (1,2,4), stride (2:16:2),\n");
    printf("                       or powers of 2 (1...16). Sequential builds accept only 1.\n");
    printf("  -r <int>             repetitions per configuration (default: 3)\n");
    printf("  --tune KEY=VALUE     runtime tuning knob (e.g. --tune block_size=64);\n");
    printf("                       repeatable; ignored by a kernel that doesn't ask for KEY\n");
    if (extra_usage) printf("%s", extra_usage);
}

int bpm_parse_args(int argc, char **argv, const char *progname, const char *extra_usage, bpm_args_t *args) {
    args->dA = -1;
    args->dB = -1;
    args->threads = NULL;
    args->nthreads = 0;
    args->reps = 3;
    args->tune.n = 0;
    args->help = 0;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
            usage(progname, extra_usage);
            args->help = 1;
            return 0;
        } else if (!strcmp(argv[i], "-dA") && i + 1 < argc) {
            args->dA = strtol(argv[++i], NULL, 10);
        } else if (!strcmp(argv[i], "-dB") && i + 1 < argc) {
            args->dB = strtol(argv[++i], NULL, 10);
        } else if ((!strcmp(argv[i], "-r") || !strcmp(argv[i], "--reps")) && i + 1 < argc) {
            args->reps = (int)strtol(argv[++i], NULL, 10);
        } else if (!strcmp(argv[i], "--tune") && i + 1 < argc) {
            char *kv = argv[++i];
            char *eq = strchr(kv, '=');
            if (!eq) {
                fprintf(stderr, "--tune expects KEY=VALUE (got %s)\n", kv);
                usage(progname, extra_usage);
                return -1;
            }
            size_t klen = (size_t)(eq - kv);
            if (klen == 0 || klen >= sizeof(args->tune.entries[0].key)) {
                fprintf(stderr, "--tune: key empty or too long (max %zu): %s\n",
                        sizeof(args->tune.entries[0].key) - 1, kv);
                return -1;
            }
            for (int j = 0; j < args->tune.n; j++) {
                if (strncmp(args->tune.entries[j].key, kv, klen) == 0 &&
                    args->tune.entries[j].key[klen] == '\0') {
                    fprintf(stderr, "--tune: key given twice: %.*s\n", (int)klen, kv);
                    return -1;
                }
            }
            if (args->tune.n >= BPM_TUNE_MAX) {
                fprintf(stderr, "--tune: too many entries (max %d)\n", BPM_TUNE_MAX);
                return -1;
            }
            memcpy(args->tune.entries[args->tune.n].key, kv, klen);
            args->tune.entries[args->tune.n].key[klen] = '\0';
            args->tune.entries[args->tune.n].value = strtol(eq + 1, NULL, 10);
            args->tune.n++;
        } else if ((!strcmp(argv[i], "-t") || !strcmp(argv[i], "--threads")) && i + 1 < argc) {
            if (bpm_parse_range(argv[++i], &args->threads, &args->nthreads) != 0) {
                fprintf(stderr, "Malformed -t range: %s\n", argv[i]);
                usage(progname, extra_usage);
                return -1;
            }
        } else {
            fprintf(stderr, "Unrecognized argument: %s\n", argv[i]);
            usage(progname, extra_usage);
            return -1;
        }
    }

    if (args->dA < 0 && args->dB < 0) { args->dA = 99999; args->dB = 99999; }
    else if (args->dA < 0) args->dA = args->dB;
    else if (args->dB < 0) args->dB = args->dA;

    if (args->dA < 0 || args->dB < 0) {
        fprintf(stderr, "Degrees must be non-negative (got dA=%ld dB=%ld)\n", args->dA, args->dB);
        return -1;
    }
    if (args->reps < 1) {
        fprintf(stderr, "--reps must be at least 1 (got %d)\n", args->reps);
        return -1;
    }

    if (args->threads == NULL) {
        args->threads = malloc(sizeof(long));
        args->threads[0] = 1;
        args->nthreads = 1;
    }

    /* A sequential build cannot honour a thread sweep. Fail loudly rather
     * than silently reporting 1-thread numbers under a multi-thread label. */
#ifndef PAR
    for (int i = 0; i < args->nthreads; i++) {
        if (args->threads[i] != 1) {
            fprintf(stderr,
                    "This is a sequential build: -t accepts only 1 (got %ld).\n"
                    "Use the .time-par binary for a thread sweep.\n",
                    args->threads[i]);
            return -1;
        }
    }
#endif

    return 0;
}

void bpm_free_args(bpm_args_t *args) {
    free(args->threads);
    args->threads = NULL;
}

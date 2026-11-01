#include <stdio.h>
#include <string.h>
#include "oracle.h"
#ifdef BPM_HAVE_GOLD
#include "gold.h"
#endif

int main(int argc, char **argv) {
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
            printf("Usage: %s [-h|--help]\n", argv[0]);
            printf("Runs the fixed independently-computable oracle suite (see DESIGN.md's\n");
            printf("\"The Oracle and the Tester\") against this build's kernel_multiply and\n");
#ifdef BPM_HAVE_GOLD
            printf("then the gold-comparison suite against GSQ on random inputs, and\n");
#endif
            printf("reports PASS/FAIL per case. -dA/-dB/--validate are accepted for\n");
            printf("command-line-shape consistency but do not change what runs.\n");
            return 0;
        }
    }
    int failures = bpm_run_oracle_suite();
#ifdef BPM_HAVE_GOLD
    /* GSQ itself does not define BPM_HAVE_GOLD: checking it against a copy of
     * its own kernel would pass unconditionally and prove nothing. */
    failures += bpm_run_gold_suite();
#endif
    return failures == 0 ? 0 : 1;
}

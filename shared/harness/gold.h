#ifndef BPM_GOLD_H
#define BPM_GOLD_H

/* Runs the gold-comparison suite: this build's kernel_multiply against GSQ's
 * kernel on inputs that have no closed form, and therefore no oracle case.
 *
 * READ_ME_FIRST.md's "Shared Test Harness" gives GSQ two roles. The oracle
 * proves GSQ correct on cases derivable by hand; GSQ then serves as the
 * broader reference every later variant is checked against. The oracle suite
 * discharges the first role, this suite the second.
 *
 * Only variants other than GSQ link this. Checking GSQ against itself is
 * tautological, so 00-GSQ keeps the oracle gate alone and its binaries do not
 * define BPM_HAVE_GOLD.
 *
 * Prints one PASS/FAIL line per case plus a summary. Returns the number of
 * failed cases (0 = all passed). */
int bpm_run_gold_suite(void);

#endif

#ifndef BPM_RANGE_H
#define BPM_RANGE_H

/* Parses a range expression in one of three forms:
 *   "1,3,5,7"   enumeration
 *   "2:16:2"    start:end:stride
 *   "1...16"    powers of 2 within [lower, upper], inclusive
 * On success, *out is a malloc'd array of *count values (caller frees it)
 * and 0 is returned. Returns -1 on a malformed expression. */
int bpm_parse_range(const char *expr, long **out, int *count);

#endif

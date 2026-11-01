#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "range.h"

static int append(long **arr, int *count, int *cap, long v) {
    if (*count == *cap) {
        *cap = (*cap == 0) ? 8 : (*cap * 2);
        long *tmp = realloc(*arr, sizeof(long) * (size_t)(*cap));
        if (!tmp) return -1;
        *arr = tmp;
    }
    (*arr)[(*count)++] = v;
    return 0;
}

static int parse_powers_of_two(long lower, long upper, long **out, int *count) {
    if (lower <= 0 || upper <= 0 || lower > upper) return -1;
    long *arr = NULL;
    int cap = 0;
    *count = 0;
    for (long v = 1; v <= upper; ) {
        if (v >= lower) {
            if (append(&arr, count, &cap, v) != 0) { free(arr); return -1; }
        }
        if (v > upper / 2) break; /* next doubling would exceed upper */
        v *= 2;
    }
    if (*count == 0) { free(arr); return -1; }
    *out = arr;
    return 0;
}

static int parse_stride(const char *expr, long **out, int *count) {
    long start, end, stride;
    if (sscanf(expr, "%ld:%ld:%ld", &start, &end, &stride) != 3 || stride <= 0 || start > end)
        return -1;
    long *arr = NULL;
    int cap = 0;
    *count = 0;
    for (long v = start; v <= end; v += stride)
        if (append(&arr, count, &cap, v) != 0) { free(arr); return -1; }
    *out = arr;
    return 0;
}

static int parse_enumeration(const char *expr, long **out, int *count) {
    long *arr = NULL;
    int cap = 0;
    *count = 0;
    char *copy = strdup(expr);
    if (!copy) return -1;
    char *tok = strtok(copy, ",");
    while (tok) {
        char *end = NULL;
        long v = strtol(tok, &end, 10);
        if (end == tok) { free(copy); free(arr); return -1; }
        if (append(&arr, count, &cap, v) != 0) { free(copy); free(arr); return -1; }
        tok = strtok(NULL, ",");
    }
    free(copy);
    if (*count == 0) { free(arr); return -1; }
    *out = arr;
    return 0;
}

int bpm_parse_range(const char *expr, long **out, int *count) {
    const char *dots = strstr(expr, "...");
    if (dots) {
        long lower = strtol(expr, NULL, 10);
        long upper = strtol(dots + 3, NULL, 10);
        return parse_powers_of_two(lower, upper, out, count);
    }
    if (strchr(expr, ':')) return parse_stride(expr, out, count);
    return parse_enumeration(expr, out, count);
}

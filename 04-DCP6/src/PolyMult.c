#include <stdlib.h>

#include "kernel.h"
#include "accumulate.h"

/* DCP6: DCQ4 (04-DCQ4) parallelized with DCP1's strategy (04-DCP1):
 * OpenMP tasks, races on c handled by a task reduction.
 * - One thread (single) opens a taskgroup with task_reduction(+: c[:n])
 *   (and comp[:n] in the checking build) and calls dcp on the whole
 *   problem.
 * - dcp at recursion depth d < max_depth splits exactly as DCQ4's dcq
 *   (4 quadrants when both sides > leaf, else 2 halves of the longer
 *   side) and spawns each non-empty child as a task:
 *     - a child that does arithmetic (a leaf, or at depth = max_depth)
 *       gets in_reduction(+: c[:n]) and runs DCQ4's sequential dcq on its
 *       thread's private copy of c, at the child's offset, with climit =
 *       n - offset;
 *     - any other child only spawns further tasks, never writes c, and is
 *       a plain task passing the original c pointer on.
 * - No taskwait: the end of the taskgroup waits for every descendant task
 *   and then combines the private copies into c.
 * - The copies of b are built once, sequentially, in kernel_multiply
 *   before the parallel region and only read by the tasks.
 * - The leaf's padded loop adds +0 to up to 7 elements of c past its own
 *   range; with the reduction those writes go to the task's private copy.
 * - Without -fopenmp the pragmas are ignored and this is DCQ4.
 * Tuning: --tune leaf_size=N (fallback 1024, DCQ4's), --tune depth=N
 * (task-spawn cutoff, fallback 5 = DCP1's).
 *
 * DCQ4: DCQ3 (04-DCQ3) with Stage A in the leaf: the fused loop covers
 * M = 4 consecutive c vectors per step and issues the FMAs row by row
 * across the 4 accumulators, so 4 independent chains alternate in the
 * instruction stream instead of 8 dependent FMAs running back to back.
 * - Per step (u stride 8 * M = 32): for r = 0..7, for m = 0..3:
 *     c[k0 + u + 8m + l] += a_r * p_r[u + 8m + l],  l = 0..7 (lane loop).
 *   Each c element still gets rows 0..7 in ascending order, so the
 *   summation order is unchanged from DCQ3 (no-associative-math kept).
 * - Tail (fewer than M vectors left, or ulen clamped by climit): DCQ3's
 *   1-vector loop.
 * - Written with BPM_ACC only (no intrinsics). Whether GCC vectorizes the
 *   lane loop, keeps the statement order and holds each c vector in a
 *   register is not guaranteed: see the assembly.
 * Everything else below is DCQ3 unchanged.
 *
 * DCQ3: divide and conquer (DCQ2) with BKQ7's tile body (03-BKQ7) as the
 * leaf.
 *
 * Recursion, dcq(a, na, b, nb, J, c, climit): adds a[0..na) * b[0..nb)
 * into c[0..na+nb-1).
 * - Each side is split independently, only while it is longer than leaf:
 *     both na, nb > leaf:  4 quadrants, order LL, LH, HL, HH (as DCQ2)
 *     only na > leaf:      2 halves of a
 *     only nb > leaf:      2 halves of b
 *     neither:             leaf (one BKQ7 tile)
 *   So the b leaves are a fixed partition of b, set by halving b alone,
 *   and can be enumerated once in kernel_multiply.
 * - Split points: hb = nb/2 rounded down to 16 floats (DCQ2's rule;
 *   fallback nb/2 when nb < 32); ha = na/2 rounded down to R = 8 rows
 *   (fallback na/2 when na < 16), so every a leaf except the last has a
 *   height that is a multiple of 8.
 * - J is the index of the b range's first b leaf (left to right); the
 *   right half of a b split starts at J + nleaves(hb).
 * - climit is the number of elements of c available from this c pointer
 *   (n minus the offset), used to keep the leaf's padded loop inside c.
 *
 * Copies of b (BKQ7), built once in kernel_multiply: NCOPY = 4 shifted
 * copies, each holding one zero-padded segment per b leaf. Copy s, segment
 * J (b leaf starting at jj, width w):
 *   seg[s + 7 + x] = b[jj + x] for 0 <= x < w, zeros elsewhere.
 * Segments are whole 64-byte lines, sized for the widest b leaf; copies are
 * spaced a multiple of 4096 bytes apart. The copies buffer is passed down
 * the recursion.
 *
 * Leaf (BKQ7's tile body, tile = the leaf's a range x its b leaf): rows in
 * groups of R = 8; row r reads copy s = (r + 1) % 4 through
 * p[r] = seg + s + 7 - r, so p[r][u] = b[u - r] (0 outside the b leaf), and
 * the fused loop runs over the group's whole trapezoid, u = 0 .. w + 6,
 * rounded up to a multiple of 8 (extra products are a * 0). The padded
 * loop can add zeros to up to 7 elements of c past the leaf's own range
 * (clamped to the end of c); sequentially this changes no value. Leftover
 * rows (height not a multiple of 8, the last a leaf only) are scalar OPQ
 * rows reading b directly. The leaf is compiled with no-associative-math
 * (BKQ3), so the 8 products stay one FMA chain. Assumes finite inputs
 * (a * 0 is NaN for infinite a).
 *
 * Tuning: --tune leaf_size=N (fallback 1024: 100000-long ranges halve to
 * leaves of ~781, near BKQ7's best block size of 768). */

#define R 8
#define NCOPY 4
#define M 4

/* One row's updates into the M = 4 interleaved c vectors of the current
 * step, lane l: c vector m covers c[k0 + u + 8m .. + 7]. Uses u, l, k0 and
 * c/comp from the enclosing scope. */
#define ROW_M(ar, pr)                                              \
    BPM_ACC(c, comp, k0 + u + l,      (ar) * (pr)[u + l]);         \
    BPM_ACC(c, comp, k0 + u + 8 + l,  (ar) * (pr)[u + 8 + l]);     \
    BPM_ACC(c, comp, k0 + u + 16 + l, (ar) * (pr)[u + 16 + l]);    \
    BPM_ACC(c, comp, k0 + u + 24 + l, (ar) * (pr)[u + 24 + l])

#ifdef CHECKING
#define COMP_PARAM , double *restrict comp
#define COMP_ARG(off) , comp + (off)
#define COMP_BASE_PARAM , double *comp
#define COMP_BASE_ARG , comp
#else
#define COMP_PARAM
#define COMP_ARG(off)
#define COMP_BASE_PARAM
#define COMP_BASE_ARG
#endif

typedef struct {
    const float *buf;   /* NCOPY copies, clen floats apart */
    size_t clen;        /* floats between copies */
    size_t seg;         /* floats per segment */
} bcopies_t;

static inline int split_b(int nb) {
    return (nb >= 32) ? ((nb / 2) & ~15) : (nb / 2);
}

static inline int split_a(int na) {
    return (na >= 16) ? ((na / 2) & ~(R - 1)) : (na / 2);
}

/* Number of b leaves in a b range of length nb. */
static int nleaves(int nb, int leaf) {
    if (nb <= leaf) return 1;
    int hb = split_b(nb);
    return nleaves(hb, leaf) + nleaves(nb - hb, leaf);
}

/* Fill segment J, J+1, ... of every copy with the b leaves of b[0..nb),
 * left to right; returns the next segment index. */
static int build_segments(float *buf, size_t clen, size_t seg,
                          const float *b, int nb, int leaf, int J) {
    if (nb <= leaf) {
        for (int s = 0; s < NCOPY; s++) {
            float *dst = buf + (size_t)s * clen + (size_t)J * seg + s + 7;
            for (int x = 0; x < nb; x++) dst[x] = b[x];
        }
        return J + 1;
    }
    int hb = split_b(nb);
    J = build_segments(buf, clen, seg, b, hb, leaf, J);
    return build_segments(buf, clen, seg, b + hb, nb - hb, leaf, J);
}

/* Leaf: BKQ7's tile body over a[0..na) x b leaf J (width nb). */
__attribute__((optimize("no-associative-math")))
static void leaf_tile(const float *restrict a, int na,
                      const float *restrict b, int nb,
                      const bcopies_t *bc, int J,
                      float *restrict c, int climit COMP_PARAM) {
    const float *p[R];
    for (int r = 0; r < R; r++) {
        int s = (r + 1) % NCOPY;
        p[r] = bc->buf + (size_t)s * bc->clen + (size_t)J * bc->seg + s + 7 - r;
    }
    const float *restrict p0 = p[0], *restrict p1 = p[1];
    const float *restrict p2 = p[2], *restrict p3 = p[3];
    const float *restrict p4 = p[4], *restrict p5 = p[5];
    const float *restrict p6 = p[6], *restrict p7 = p[7];

    int tlen = (nb + 7 + 7) & ~7;
    int i0 = 0;
    for (; i0 + R <= na; i0 += R) {
        const float a0 = a[i0],     a1 = a[i0 + 1];
        const float a2 = a[i0 + 2], a3 = a[i0 + 3];
        const float a4 = a[i0 + 4], a5 = a[i0 + 5];
        const float a6 = a[i0 + 6], a7 = a[i0 + 7];
        int k0 = i0;
        int ulen = (tlen <= climit - k0) ? tlen : climit - k0;

        /* Stage A: M = 4 consecutive c vectors per step (u stride 32).
         * One pass of the 8-lane loop issues, row by row, one update into
         * each of the 4 c vectors: rows ascending, vectors m = 0..3 inside
         * each row, so each c element still gets rows 0..7 in order. */
        int u = 0;
        for (; u + 8 * M <= ulen; u += 8 * M) {
            for (int l = 0; l < 8; l++) {
                ROW_M(a0, p0);
                ROW_M(a1, p1);
                ROW_M(a2, p2);
                ROW_M(a3, p3);
                ROW_M(a4, p4);
                ROW_M(a5, p5);
                ROW_M(a6, p6);
                ROW_M(a7, p7);
            }
        }

        /* tail: the remaining vectors (fewer than M), DCQ3's loop */
        for (; u < ulen; u++) {
            BPM_ACC(c, comp, k0 + u, a0 * p0[u]);
            BPM_ACC(c, comp, k0 + u, a1 * p1[u]);
            BPM_ACC(c, comp, k0 + u, a2 * p2[u]);
            BPM_ACC(c, comp, k0 + u, a3 * p3[u]);
            BPM_ACC(c, comp, k0 + u, a4 * p4[u]);
            BPM_ACC(c, comp, k0 + u, a5 * p5[u]);
            BPM_ACC(c, comp, k0 + u, a6 * p6[u]);
            BPM_ACC(c, comp, k0 + u, a7 * p7[u]);
        }
    }

    /* leftover rows (last a leaf only) */
    for (int i = i0; i < na; i++) {
        for (int j = 0; j < nb; j++) {
            BPM_ACC(c, comp, i + j, a[i] * b[j]);
        }
    }
}

static void dcq(const float *restrict a, int na,
                const float *restrict b, int nb,
                const bcopies_t *bc, int J,
                float *restrict c, int climit COMP_PARAM, int leaf) {
    if (na <= 0 || nb <= 0) return;

    int sa = na > leaf, sb = nb > leaf;
    if (!sa && !sb) {
        leaf_tile(a, na, b, nb, bc, J, c, climit COMP_ARG(0));
        return;
    }
    if (sa && sb) {
        int ha = split_a(na), hb = split_b(nb);
        int Jr = J + nleaves(hb, leaf);
        dcq(a,      ha,      b,      hb,      bc, J,  c,           climit COMP_ARG(0),                  leaf);
        dcq(a,      ha,      b + hb, nb - hb, bc, Jr, c + hb,      climit - hb COMP_ARG(hb),            leaf);
        dcq(a + ha, na - ha, b,      hb,      bc, J,  c + ha,      climit - ha COMP_ARG(ha),            leaf);
        dcq(a + ha, na - ha, b + hb, nb - hb, bc, Jr, c + ha + hb, climit - ha - hb COMP_ARG(ha + hb),  leaf);
    } else if (sa) {
        int ha = split_a(na);
        dcq(a,      ha,      b, nb, bc, J, c,      climit COMP_ARG(0),        leaf);
        dcq(a + ha, na - ha, b, nb, bc, J, c + ha, climit - ha COMP_ARG(ha),  leaf);
    } else {
        int hb = split_b(nb);
        int Jr = J + nleaves(hb, leaf);
        dcq(a, na, b,      hb,      bc, J,  c,      climit COMP_ARG(0),        leaf);
        dcq(a, na, b + hb, nb - hb, bc, Jr, c + hb, climit - hb COMP_ARG(hb),  leaf);
    }
}

static void dcp(const float *a, int na, const float *b, int nb,
                const bcopies_t *bc, int J,
                float *c COMP_BASE_PARAM, int n, int off,
                int leaf, int depth, int max_depth);

/* Spawn one child sub-multiply (a, na) x (b, nb), first b leaf J, at
 * offset off into c, as a task. c (and comp) are the base pointers named
 * in the task_reduction. */
static void spawn(const float *a, int na, const float *b, int nb,
                  const bcopies_t *bc, int J,
                  float *c COMP_BASE_PARAM, int n, int off,
                  int leaf, int depth, int max_depth) {
    if (na <= 0 || nb <= 0) return;

    int works = (depth >= max_depth) || (na <= leaf && nb <= leaf);
    if (works) {
#ifdef CHECKING
        #pragma omp task in_reduction(+: c[:n], comp[:n])
#else
        #pragma omp task in_reduction(+: c[:n])
#endif
        dcq(a, na, b, nb, bc, J, c + off, n - off COMP_ARG(off), leaf);
    } else {
        #pragma omp task
        dcp(a, na, b, nb, bc, J, c COMP_BASE_ARG, n, off, leaf, depth, max_depth);
    }
}

/* Spawn the children of (a, na) x (b, nb) as tasks, split as DCQ4's dcq.
 * Called only for a non-leaf node at depth < max_depth. */
static void dcp(const float *a, int na, const float *b, int nb,
                const bcopies_t *bc, int J,
                float *c COMP_BASE_PARAM, int n, int off,
                int leaf, int depth, int max_depth) {
    int sa = na > leaf, sb = nb > leaf;
    int d = depth + 1;
    if (sa && sb) {
        int ha = split_a(na), hb = split_b(nb);
        int Jr = J + nleaves(hb, leaf);
        spawn(a,      ha,      b,      hb,      bc, J,  c COMP_BASE_ARG, n, off,           leaf, d, max_depth);
        spawn(a,      ha,      b + hb, nb - hb, bc, Jr, c COMP_BASE_ARG, n, off + hb,      leaf, d, max_depth);
        spawn(a + ha, na - ha, b,      hb,      bc, J,  c COMP_BASE_ARG, n, off + ha,      leaf, d, max_depth);
        spawn(a + ha, na - ha, b + hb, nb - hb, bc, Jr, c COMP_BASE_ARG, n, off + ha + hb, leaf, d, max_depth);
    } else if (sa) {
        int ha = split_a(na);
        spawn(a,      ha,      b, nb, bc, J, c COMP_BASE_ARG, n, off,      leaf, d, max_depth);
        spawn(a + ha, na - ha, b, nb, bc, J, c COMP_BASE_ARG, n, off + ha, leaf, d, max_depth);
    } else {
        int hb = split_b(nb);
        int Jr = J + nleaves(hb, leaf);
        spawn(a, na, b,      hb,      bc, J,  c COMP_BASE_ARG, n, off,      leaf, d, max_depth);
        spawn(a, na, b + hb, nb - hb, bc, Jr, c COMP_BASE_ARG, n, off + hb, leaf, d, max_depth);
    }
}

void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    long leaf_val = bpm_tune_get(tune, "leaf_size", 0);
    int leaf = (leaf_val > 0) ? (int)leaf_val : 1024;
    long depth_val = bpm_tune_get(tune, "depth", -1);
    int max_depth = (depth_val >= 0) ? (int)depth_val : 5;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    int nA = dA + 1, nB = dB + 1;

    /* Copies of b: one zero-padded segment per b leaf, sized for the widest
     * b leaf (at most min(leaf, nB)); 7 leading zeros, room for the padded
     * loop (w + 13) and the copy shift (< NCOPY), rounded up to whole
     * 64-byte lines. Copies spaced a multiple of 1024 floats (4096 B). */
    int wmax = (nB < leaf) ? nB : leaf;
    int TJ = nleaves(nB, leaf);
    size_t seg = ((size_t)wmax + 7 + 8 + 7 + NCOPY + 15) & ~(size_t)15;
    size_t clen = (size_t)TJ * seg;
    clen = (clen + 1023) & ~(size_t)1023;
    float *bcbuf = aligned_alloc(64, NCOPY * clen * sizeof(float));
    for (size_t x = 0; x < NCOPY * clen; x++) bcbuf[x] = 0.0f;
    build_segments(bcbuf, clen, seg, b, nB, leaf, 0);
    bcopies_t bc = { bcbuf, clen, seg };

    BPM_COMP_DECL(comp, n);

    if (max_depth == 0 || (nA <= leaf && nB <= leaf)) {
        /* Nothing to spawn: run the whole problem sequentially. */
        dcq(a, nA, b, nB, &bc, 0, c, n COMP_ARG(0), leaf);
    } else {
        float *cr = c;
        const bcopies_t *bcp = &bc;
#ifdef CHECKING
        double *compr = comp;
        #pragma omp parallel
        #pragma omp single
        #pragma omp taskgroup task_reduction(+: cr[:n], compr[:n])
        dcp(a, nA, b, nB, bcp, 0, cr, compr, n, 0, leaf, 0, max_depth);
#else
        #pragma omp parallel
        #pragma omp single
        #pragma omp taskgroup task_reduction(+: cr[:n])
        dcp(a, nA, b, nB, bcp, 0, cr, n, 0, leaf, 0, max_depth);
#endif
    }

    BPM_COMP_FREE(comp);
    free(bcbuf);
}

#include <stdlib.h>

#include "kernel.h"
#include "accumulate.h"

/* DCQ5: DCQ4 (04-DCQ4) with Stage B: groups of R = 10 rows, so rows 8
 * apart share a b window, with M = 2 interleaved c vectors per step.
 * - Row r + 8 at c vector m + 1 reads the same b window as row r at c
 *   vector m (same copy, p[r + 8] = p[r] - 8), so rows 8, 9 at m = 1 are
 *   written with rows 0, 1's m = 0 expressions (p0[u + l], p1[u + l]),
 *   letting GCC merge the loads; at m = 0 they read the previous step's
 *   window (p0[u - 8 + l], p1[u - 8 + l]), reloaded.
 * - Per step (u stride 8 * M = 16): for r = 0..9, for m = 0, 1:
 *     c[k0 + u + 8m + l] += a_r * b-window,  l = 0..7 (lane loop).
 *   Each c element gets rows 0..9 in ascending order.
 * - Changes needed for R = 10 (DCQ4.1 Design, Stage B side changes):
 *   ha = na/2 rounded down to a multiple of 10 (fallback na/2 when
 *   na < 20); LZ = 11 leading zeros per segment (>= R - 1, LZ % 4 == 3 so
 *   the 16-byte alignment of p[r] = seg + s + LZ - r is kept); trapezoid
 *   u = 0 .. w + R - 2 rounded up to 8 (R - 8 = 2 more products per row);
 *   segment size w + R + LZ + 9 rounded up to 16 floats. The overrun past
 *   a leaf's range of c stays <= 7 elements.
 * - Tail: one remaining vector (or ulen clamped by climit): 1-vector loop
 *   with rows 0..9.
 * - Written with BPM_ACC only; whether GCC vectorizes the lane loop,
 *   merges the shared loads and keeps 2 accumulators + 10 broadcasts in
 *   registers is visible only in the assembly.
 * Everything else is DCQ3's (description below, updated for R = 10,
 * LZ = 11).
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
 *   fallback nb/2 when nb < 32); ha = na/2 rounded down to R = 10 rows
 *   (fallback na/2 when na < 20), so every a leaf except the last has a
 *   height that is a multiple of 10.
 * - J is the index of the b range's first b leaf (left to right); the
 *   right half of a b split starts at J + nleaves(hb).
 * - climit is the number of elements of c available from this c pointer
 *   (n minus the offset), used to keep the leaf's padded loop inside c.
 *
 * Copies of b (BKQ7), built once in kernel_multiply: NCOPY = 4 shifted
 * copies, each holding one zero-padded segment per b leaf. Copy s, segment
 * J (b leaf starting at jj, width w):
 *   seg[s + LZ + x] = b[jj + x] for 0 <= x < w, zeros elsewhere (LZ = 11).
 * Segments are whole 64-byte lines, sized for the widest b leaf; copies are
 * spaced a multiple of 4096 bytes apart. The copies buffer is passed down
 * the recursion.
 *
 * Leaf (BKQ7's tile body, tile = the leaf's a range x its b leaf): rows in
 * groups of R = 10; row r < 8 reads copy s = (r + 1) % 4 through
 * p[r] = seg + s + LZ - r, so p[r][u] = b[u - r] (0 outside the b leaf);
 * rows 8, 9 read p[r - 8][u - 8]. The fused loop runs over the group's
 * whole trapezoid, u = 0 .. w + 8, rounded up to a multiple of 8 (extra
 * products are a * 0). The padded
 * loop can add zeros to up to 7 elements of c past the leaf's own range
 * (clamped to the end of c); sequentially this changes no value. Leftover
 * rows (height not a multiple of 10, the last a leaf only) are scalar OPQ
 * rows reading b directly. The leaf is compiled with no-associative-math
 * (BKQ3), so the 10 products into each c element stay one FMA chain in
 * row order. Assumes finite inputs
 * (a * 0 is NaN for infinite a).
 *
 * Tuning: --tune leaf_size=N (fallback 1024: 100000-long ranges halve to
 * leaves of ~781, near BKQ7's best block size of 768). */

#define R 10          /* rows per group */
#define NCOPY 4
#define M 2           /* interleaved c vectors per step */
#define LZ 11         /* leading zeros per segment: >= R - 1, and LZ % 4 == 3
                         so p[r] = seg + s + LZ - r stays 16-byte aligned */

#ifdef CHECKING
#define COMP_PARAM , double *restrict comp
#define COMP_ARG(off) , comp + (off)
#else
#define COMP_PARAM
#define COMP_ARG(off)
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
    return (na >= 2 * R) ? ((na / 2) / R * R) : (na / 2);
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
            float *dst = buf + (size_t)s * clen + (size_t)J * seg + s + LZ;
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
    /* Rows 0..7 read through p[r] = seg + s + LZ - r (copy s = (r+1) % 4),
     * so p[r][u] = b[u - r]. Row r + 8 (r = 0, 1) uses the same copy and
     * p[r + 8] = p[r] - 8, so it is read as p[r][u - 8]: at c vector m + 1
     * that is p[r][u + 8m], the same expression row r used for vector m in
     * the same step. */
    const float *p[8];
    for (int r = 0; r < 8; r++) {
        int s = (r + 1) % NCOPY;
        p[r] = bc->buf + (size_t)s * bc->clen + (size_t)J * bc->seg + s + LZ - r;
    }
    const float *restrict p0 = p[0], *restrict p1 = p[1];
    const float *restrict p2 = p[2], *restrict p3 = p[3];
    const float *restrict p4 = p[4], *restrict p5 = p[5];
    const float *restrict p6 = p[6], *restrict p7 = p[7];

    /* The group's whole trapezoid, u = 0 .. w + R - 2, rounded up to a
     * multiple of 8 (extra products are a * 0). */
    int tlen = (nb + R - 1 + 7) & ~7;
    int i0 = 0;
    for (; i0 + R <= na; i0 += R) {
        const float a0 = a[i0],     a1 = a[i0 + 1];
        const float a2 = a[i0 + 2], a3 = a[i0 + 3];
        const float a4 = a[i0 + 4], a5 = a[i0 + 5];
        const float a6 = a[i0 + 6], a7 = a[i0 + 7];
        const float a8 = a[i0 + 8], a9 = a[i0 + 9];
        int k0 = i0;
        int ulen = (tlen <= climit - k0) ? tlen : climit - k0;

        /* Stage A + B: M = 2 c vectors per step (u stride 16), rows
         * ascending, vectors m = 0, 1 inside each row. Rows 8, 9 at m = 1
         * reuse rows 0, 1's m = 0 windows (p0[u + l], p1[u + l]); at
         * m = 0 they reload the previous step's window (p0[u - 8 + l]). */
        int u = 0;
        for (; u + 8 * M <= ulen; u += 8 * M) {
            for (int l = 0; l < 8; l++) {
                BPM_ACC(c, comp, k0 + u + l,     a0 * p0[u + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a0 * p0[u + 8 + l]);
                BPM_ACC(c, comp, k0 + u + l,     a1 * p1[u + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a1 * p1[u + 8 + l]);
                BPM_ACC(c, comp, k0 + u + l,     a2 * p2[u + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a2 * p2[u + 8 + l]);
                BPM_ACC(c, comp, k0 + u + l,     a3 * p3[u + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a3 * p3[u + 8 + l]);
                BPM_ACC(c, comp, k0 + u + l,     a4 * p4[u + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a4 * p4[u + 8 + l]);
                BPM_ACC(c, comp, k0 + u + l,     a5 * p5[u + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a5 * p5[u + 8 + l]);
                BPM_ACC(c, comp, k0 + u + l,     a6 * p6[u + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a6 * p6[u + 8 + l]);
                BPM_ACC(c, comp, k0 + u + l,     a7 * p7[u + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a7 * p7[u + 8 + l]);
                BPM_ACC(c, comp, k0 + u + l,     a8 * p0[u - 8 + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a8 * p0[u + l]);
                BPM_ACC(c, comp, k0 + u + l,     a9 * p1[u - 8 + l]);
                BPM_ACC(c, comp, k0 + u + 8 + l, a9 * p1[u + l]);
            }
        }

        /* tail: the remaining vector (fewer than M), rows 0..9 */
        for (; u < ulen; u++) {
            BPM_ACC(c, comp, k0 + u, a0 * p0[u]);
            BPM_ACC(c, comp, k0 + u, a1 * p1[u]);
            BPM_ACC(c, comp, k0 + u, a2 * p2[u]);
            BPM_ACC(c, comp, k0 + u, a3 * p3[u]);
            BPM_ACC(c, comp, k0 + u, a4 * p4[u]);
            BPM_ACC(c, comp, k0 + u, a5 * p5[u]);
            BPM_ACC(c, comp, k0 + u, a6 * p6[u]);
            BPM_ACC(c, comp, k0 + u, a7 * p7[u]);
            BPM_ACC(c, comp, k0 + u, a8 * p0[u - 8]);
            BPM_ACC(c, comp, k0 + u, a9 * p1[u - 8]);
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

void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    long leaf_val = bpm_tune_get(tune, "leaf_size", 0);
    int leaf = (leaf_val > 0) ? (int)leaf_val : 1024;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    int nA = dA + 1, nB = dB + 1;

    /* Copies of b: one zero-padded segment per b leaf, sized for the widest
     * b leaf (at most min(leaf, nB)); LZ leading zeros, the padded loop
     * (u < tlen <= w + R + 6) and the copy shift (< NCOPY): highest index
     * read is s + LZ + tlen - 1 <= w + R + LZ + 8, so w + R + LZ + 9,
     * rounded up to whole 64-byte lines. Copies spaced a multiple of 1024 floats (4096 B). */
    int wmax = (nB < leaf) ? nB : leaf;
    int TJ = nleaves(nB, leaf);
    size_t seg = ((size_t)wmax + R + LZ + 9 + 15) & ~(size_t)15;
    size_t clen = (size_t)TJ * seg;
    clen = (clen + 1023) & ~(size_t)1023;
    float *bcbuf = aligned_alloc(64, NCOPY * clen * sizeof(float));
    for (size_t x = 0; x < NCOPY * clen; x++) bcbuf[x] = 0.0f;
    build_segments(bcbuf, clen, seg, b, nB, leaf, 0);
    bcopies_t bc = { bcbuf, clen, seg };

    BPM_COMP_DECL(comp, n);

    dcq(a, nA, b, nB, &bc, 0, c, n COMP_ARG(0), leaf);

    BPM_COMP_FREE(comp);
    free(bcbuf);
}

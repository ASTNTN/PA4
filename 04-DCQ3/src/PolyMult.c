#include <stdlib.h>

#include "kernel.h"
#include "accumulate.h"

/* DCQ3: divide and conquer (DCQ2) with BKQ7's tile body (03-BKQ7) as the
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

        for (int u = 0; u < ulen; u++) {
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

void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    long leaf_val = bpm_tune_get(tune, "leaf_size", 0);
    int leaf = (leaf_val > 0) ? (int)leaf_val : 1024;

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

    dcq(a, nA, b, nB, &bc, 0, c, n COMP_ARG(0), leaf);

    BPM_COMP_FREE(comp);
    free(bcbuf);
}

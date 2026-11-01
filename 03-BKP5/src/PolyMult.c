#include <stdlib.h>
#include "kernel.h"
#include "accumulate.h"

/* Blocked outer-product with unroll-and-jam (03-BKQ2, 03-BKQ3, 03-BKQ4):
 * BKQ's 4-loop tiling (ii, jj, i, j), square bs x bs blocks, edge blocks
 * left incomplete. Inside a block, rows are taken R = 8 at a time and their
 * j loops are fused into one loop over t, so all 8 rows add into the same
 * c[i0 + t] while it is held in a register:
 *
 *   row r of the group uses j = t - r, so c[i0 + t] += a[i0 + r] * b[t - r]
 *
 * The fused loop covers t = jj+R-1 .. jend-1, where every row's j lies in
 * [jj, jend). The ragged ends (row r's j < jj+R-1-r and j >= jend-r), blocks
 * narrower than R, and the leftover rows when the block height isn't a
 * multiple of R run as plain OPQ rows. Block size is the runtime knob
 * block_size (--tune block_size=N), default 64; R is fixed at 8.
 *
 * 03-BKQ3: the timed build's -ffast-math lets GCC regroup the 8 products
 * into pairs (4 mul + 4 FMA + 4 add per 8 FMAs of work). no-associative-math
 * on this function only keeps them as one chain of 8 FMAs; the rest of the
 * build keeps -ffast-math.
 *
 * 03-BKQ4: the 8 rows read b starting one float apart, so most of their
 * 256-bit loads can't all start on a 16-byte boundary and some straddle a
 * cache line (split loads). Four copies of b are built once per call, copy s
 * shifted right by s floats on a 64-byte-aligned base (bc[s][x + s] = b[x]).
 * For each block, row r reads from the copy that puts its fused-loop loads
 * on a 16-byte boundary. Only the fused loop uses the copies; the plain-row
 * loops read b directly.
 *
 * copy_pad (--tune copy_pad=N, default 0) adds N floats of padding between
 * consecutive copies, rounded up to a multiple of 16 so every copy stays
 * 64-byte aligned. It moves the copies relative to each other in memory
 * (and so in L1's sets) without changing what is read or the loop
 * structure.
 *
 * 03-BKP1: the copy spacing is rounded up to a multiple of 4096 bytes
 * before copy_pad is added, the best placement measured in BKQ4.3/4.4 at
 * every size. The outer tile loop (ii) is split across threads with
 * schedule(static) and an array reduction into c: each thread accumulates
 * into its own zeroed copy of c, and the copies are summed into c at the
 * end. In the checking build the Kahan compensation array is reduced the
 * same way. The copies of b are built before the parallel region and
 * shared read-only.
 *
 * 03-BKP2: collapse(2) over the ii and jj tile loops, so threads are dealt
 * individual tiles (static, contiguous chunks of the row-major tile order)
 * instead of whole tile rows. iend moved inside the jj loop so the two
 * tile loops are perfectly nested, as collapse requires.
 *
 * 03-BKP3 (diagnostic): no reduction. Tiles are coloured like a
 * checkerboard by the parity of I + J (I = ii/bs, J = jj/bs) and run in two
 * phases, even tiles then odd tiles, with the implicit barrier of each
 * parallel for between them; threads accumulate straight into the shared
 * c. This is NOT race-free for this tiling: tile (I, J) writes
 * c[(I+J)*bs .. (I+J+2)*bs - 2], so every tile on the same anti-diagonal
 * (same I + J, hence same colour) writes the same range of c. Built to
 * measure the race and its cost (sweep.sh --allow-gate-failure).
 *
 * BKP3.2: the body of one tile is a separate function, bkq_tile, whose
 * pointer parameters are restrict-qualified. Without it, inside the
 * OpenMP-outlined loop c is reached through a pointer without restrict,
 * the compiler can't keep c[i0 + t] in a register across the 8 rows, and
 * stores c after every FMA (BKP3.1). noinline keeps the function (and its
 * restrict parameters) a separate unit.
 *
 * 03-BKP4: race-free without a reduction, by diagonal parity. Tile (I, J)
 * writes c[(I+J)*bs .. (I+J+2)*bs - 2], so tiles overlap exactly when their
 * tile diagonals d = I + J differ by 0 or 1; tiles on diagonals d and d + 2
 * never write the same element. Phase 0 runs the even diagonals, phase 1
 * the odd ones, with the implicit barrier of each parallel for between
 * them. Within a phase each diagonal is one unit of work: one thread runs
 * all of its tiles in order, and diagonals are dealt with
 * schedule(dynamic, 1) since their lengths vary from 1 to min(TI, TJ)
 * tiles. Threads accumulate straight into the shared c (and comp).
 *
 * 03-BKP5: BKP4's schedule with the BKQ7 kernel: zero-padded b segments per
 * tile column and a fused loop over each row group's whole trapezoid, so
 * full row groups have no scalar edge work. Unlike BKQ7, the zero-product
 * padding that rounds a group's loop up to a multiple of 8 iterations is
 * kept inside [ii + jj - 1, iend + jend - 2] (the tile's own range of c
 * plus one element below), which concurrently running tiles (diagonals
 * d - 2 and d + 2) never touch: padding past the top of the range would
 * write (adding 0, but still a read-modify-write) elements that diagonal
 * d + 2 owns. Square tiles only (the diagonal rule needs them). */
#define R 8
#define NCOPY 4

#ifdef CHECKING
#define COMP_PARAM , double *restrict comp
#define COMP_ARG   , comp
#else
#define COMP_PARAM
#define COMP_ARG
#endif

/* One bs x bs tile: rows [ii, iend), columns [jj, jend). seg0 is this
 * tile column's segment in copy 0 of the padded copies of b; copy s's
 * segment is seg0 + s * clen, holding seg[s + 15 + x] = b[jj + x] for
 * 0 <= x < w and zeros elsewhere. */
__attribute__((noinline, optimize("no-associative-math")))
static void bkq_tile(const float *restrict a, const float *restrict b,
                     float *restrict c COMP_PARAM,
                     const float *restrict seg0, size_t clen,
                     int ii, int iend, int jj, int jend) {
    /* Row r reads from copy s = (r + 1) % 4 through p[r] = seg + s + 15 - r,
     * so p[r][u] = b[jj + u - r] (0 outside the tile). s + 15 - r is a
     * multiple of 4: loads start on 16-byte boundaries when u is a
     * multiple of 8. */
    const float *p[R];
    for (int r = 0; r < R; r++) {
        int s = (r + 1) % NCOPY;
        p[r] = seg0 + s * clen + s + 15 - r;
    }
    const float *restrict p0 = p[0], *restrict p1 = p[1];
    const float *restrict p2 = p[2], *restrict p3 = p[3];
    const float *restrict p4 = p[4], *restrict p5 = p[5];
    const float *restrict p6 = p[6], *restrict p7 = p[7];

    /* A group's products cover c[k0 .. k0 + w + 6]. The loop is padded
     * with zero products to a multiple of 8 iterations, but only inside
     * [lo, hi]: this tile's own range of c plus one element below. Tiles
     * on diagonals d - 2 and d + 2, which run at the same time, end two
     * below lo and start one above hi. */
    int w = jend - jj;
    int extra = ((w + 7 + 7) & ~7) - (w + 7);
    int lo = (ii + jj > 0) ? ii + jj - 1 : 0;
    int hi = iend + jend - 2;
    int i0 = ii;
    for (; i0 + R <= iend; i0 += R) {
        const float a0 = a[i0],     a1 = a[i0 + 1];
        const float a2 = a[i0 + 2], a3 = a[i0 + 3];
        const float a4 = a[i0 + 4], a5 = a[i0 + 5];
        const float a6 = a[i0 + 6], a7 = a[i0 + 7];
        int k0 = i0 + jj;
        int up = hi - (k0 + w + 6);
        if (up > extra) up = extra;
        int down = k0 - lo;
        if (down > extra - up) down = extra - up;

        /* all 8 rows into c[k0 + u], ragged ends included */
        for (int u = -down; u < w + 7 + up; u++) {
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

    /* leftover rows (last tile row only) */
    for (int i = i0; i < iend; i++) {
        for (int j = jj; j < jend; j++) {
            BPM_ACC(c, comp, i + j, a[i] * b[j]);
        }
    }
}

__attribute__((optimize("no-associative-math")))
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    long bs_val = bpm_tune_get(tune, "block_size", 0);
    int bs = (bs_val > 0) ? (int)bs_val : 64;
    long pad_val = bpm_tune_get(tune, "copy_pad", 0);
    size_t pad = (pad_val > 0) ? ((size_t)pad_val + 15) & ~(size_t)15 : 0;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    /* Zero-padded, shifted copies of b, one segment per tile column J:
     * copy s, segment J holds seg[s + 15 + x] = b[J*bs + x] for the
     * tile's w columns, zeros elsewhere. Segments are whole 64-byte lines,
     * copies spaced a multiple of 4096 bytes apart (+ copy_pad). */
    int TI = (dA + bs) / bs;                        /* tile rows    */
    int TJ = (dB + bs) / bs;                        /* tile columns */
    size_t seg = ((size_t)bs + 40 + 15) & ~(size_t)15;
    size_t clen = (size_t)TJ * seg;
    clen = (clen + 1023) & ~(size_t)1023;           /* 1024 floats = 4096 B */
    clen += pad;
    float *bcbuf = aligned_alloc(64, NCOPY * clen * sizeof(float));
    for (size_t x = 0; x < NCOPY * clen; x++) bcbuf[x] = 0.0f;
    for (int s = 0; s < NCOPY; s++) {
        for (int J = 0; J < TJ; J++) {
            int jj = J * bs;
            int jend = (jj + bs <= dB + 1) ? jj + bs : dB + 1;
            float *dst = bcbuf + s * clen + (size_t)J * seg + s + 15;
            for (int x = 0; x < jend - jj; x++) dst[x] = b[jj + x];
        }
    }

    BPM_COMP_DECL(comp, n);

    for (int parity = 0; parity < 2; parity++) {
        #pragma omp parallel for schedule(dynamic, 1)
        for (int d = parity; d <= TI + TJ - 2; d += 2) {
            int Ilo = (d - (TJ - 1) > 0) ? d - (TJ - 1) : 0;
            int Ihi = (d < TI - 1) ? d : TI - 1;
            for (int I = Ilo; I <= Ihi; I++) {
                int ii = I * bs, jj = (d - I) * bs;
                int iend = (ii + bs <= dA + 1) ? ii + bs : dA + 1;
                int jend = (jj + bs <= dB + 1) ? jj + bs : dB + 1;
                bkq_tile(a, b, c COMP_ARG, bcbuf + (size_t)(d - I) * seg, clen,
                         ii, iend, jj, jend);
            }
        }
    }

    BPM_COMP_FREE(comp);
    free(bcbuf);
}

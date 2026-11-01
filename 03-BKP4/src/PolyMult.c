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
 * tiles. Threads accumulate straight into the shared c (and comp). */
#define R 8
#define NCOPY 4

#ifdef CHECKING
#define COMP_PARAM , double *restrict comp
#define COMP_ARG   , comp
#else
#define COMP_PARAM
#define COMP_ARG
#endif

/* One bs x bs tile: rows [ii, iend), columns [jj, jend). */
__attribute__((noinline, optimize("no-associative-math")))
static void bkq_tile(const float *restrict a, const float *restrict b,
                     float *restrict c COMP_PARAM,
                     const float *const *restrict bc,
                     int ii, int iend, int jj, int jend) {
    int i0 = ii;
    if (jend - jj >= R) {
        /* Row r reads b[t - r] = bc[s][t - r + s]. The fused loop
         * starts at t0 = jj + R - 1 and steps 8 floats, so choosing
         * s with (t0 - r + s) % 4 == 0 puts every load of row r on
         * a 16-byte boundary. */
        int t0 = jj + R - 1;
        const float *p[R];
        int o[R];
        for (int r = 0; r < R; r++) {
            int s = ((r - t0) % NCOPY + NCOPY) % NCOPY;
            p[r] = bc[s];
            o[r] = s - r;
        }
        const float *restrict p0 = p[0], *restrict p1 = p[1];
        const float *restrict p2 = p[2], *restrict p3 = p[3];
        const float *restrict p4 = p[4], *restrict p5 = p[5];
        const float *restrict p6 = p[6], *restrict p7 = p[7];
        const int o0 = o[0], o1 = o[1], o2 = o[2], o3 = o[3];
        const int o4 = o[4], o5 = o[5], o6 = o[6], o7 = o[7];

        for (; i0 + R <= iend; i0 += R) {
            const float a0 = a[i0],     a1 = a[i0 + 1];
            const float a2 = a[i0 + 2], a3 = a[i0 + 3];
            const float a4 = a[i0 + 4], a5 = a[i0 + 5];
            const float a6 = a[i0 + 6], a7 = a[i0 + 7];

            /* fused interior: all 8 rows into c[i0 + t] */
            for (int t = t0; t < jend; t++) {
                BPM_ACC(c, comp, i0 + t, a0 * p0[t + o0]);
                BPM_ACC(c, comp, i0 + t, a1 * p1[t + o1]);
                BPM_ACC(c, comp, i0 + t, a2 * p2[t + o2]);
                BPM_ACC(c, comp, i0 + t, a3 * p3[t + o3]);
                BPM_ACC(c, comp, i0 + t, a4 * p4[t + o4]);
                BPM_ACC(c, comp, i0 + t, a5 * p5[t + o5]);
                BPM_ACC(c, comp, i0 + t, a6 * p6[t + o6]);
                BPM_ACC(c, comp, i0 + t, a7 * p7[t + o7]);
            }

            /* ragged ends of each row */
            for (int r = 0; r < R; r++) {
                int i = i0 + r;
                for (int j = jj; j < jj + R - 1 - r; j++)
                    BPM_ACC(c, comp, i + j, a[i] * b[j]);
                for (int j = jend - r; j < jend; j++)
                    BPM_ACC(c, comp, i + j, a[i] * b[j]);
            }
        }
    }

    /* leftover rows, or every row of a block narrower than R */
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

    /* shifted copies of b: bc[s][x + s] = b[x], each base 64-byte aligned,
     * spaced a multiple of 4096 bytes apart (+ copy_pad) */
    size_t clen = (size_t)(dB + 1 + NCOPY);
    clen = (clen + 1023) & ~(size_t)1023;           /* 1024 floats = 4096 B */
    clen += pad;
    float *bcbuf = aligned_alloc(64, NCOPY * clen * sizeof(float));
    const float *bc[NCOPY];
    for (int s = 0; s < NCOPY; s++) {
        float *dst = bcbuf + s * clen;
        for (int x = 0; x < s; x++) dst[x] = 0.0f;
        for (int x = 0; x <= dB; x++) dst[x + s] = b[x];
        bc[s] = dst;
    }

    BPM_COMP_DECL(comp, n);

    int TI = (dA + bs) / bs;                        /* tile rows    */
    int TJ = (dB + bs) / bs;                        /* tile columns */
    for (int parity = 0; parity < 2; parity++) {
        #pragma omp parallel for schedule(dynamic, 1)
        for (int d = parity; d <= TI + TJ - 2; d += 2) {
            int Ilo = (d - (TJ - 1) > 0) ? d - (TJ - 1) : 0;
            int Ihi = (d < TI - 1) ? d : TI - 1;
            for (int I = Ilo; I <= Ihi; I++) {
                int ii = I * bs, jj = (d - I) * bs;
                int iend = (ii + bs <= dA + 1) ? ii + bs : dA + 1;
                int jend = (jj + bs <= dB + 1) ? jj + bs : dB + 1;
                bkq_tile(a, b, c COMP_ARG, bc, ii, iend, jj, jend);
            }
        }
    }

    BPM_COMP_FREE(comp);
    free(bcbuf);
}

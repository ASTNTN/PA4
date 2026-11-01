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
 * 03-BKQ6: the copy spacing is rounded up to a multiple of 4096 bytes
 * before copy_pad is added (as in 03-BKP1 onward). Tiles may be
 * rectangular: block_size (bs) is the tile height (rows of a, the ii
 * loop) and block_width (--tune block_width=N, default bs) is the tile
 * width (columns of b, the jj loop). A narrow tile keeps a smaller window
 * of the copies of b and of c in use while its rows are processed; tiles
 * narrower than R run entirely as plain OPQ rows.
 *
 * 03-BKQ7: no scalar edge work in full row groups. Each tile column gets
 * its own zero-padded segment in each copy of b (7 zeros before the
 * tile's columns, zeros after), and the fused loop runs over the whole
 * trapezoid of the group, t = jj .. jend + 6, rounded up to a multiple of
 * 8: where row r has no b[t - r] in the tile it reads a zero and adds
 * a * 0. The ragged-end loops and the fused loop's leftover iterations
 * are gone, and tiles narrower than R take the same path. Only the
 * leftover rows of the last tile row (height not a multiple of R) stay
 * scalar. The copy for row r is chosen once, s = (r + 1) % 4, since every
 * segment starts on a 64-byte boundary. Assumes finite inputs (a * 0 is
 * NaN for infinite a). */
#define R 8
#define NCOPY 4

__attribute__((optimize("no-associative-math")))
void kernel_multiply(const float *restrict a, int dA,
                     const float *restrict b, int dB,
                     float *restrict c, const bpm_tune_t *restrict tune) {
    long bs_val = bpm_tune_get(tune, "block_size", 0);
    int bs = (bs_val > 0) ? (int)bs_val : 64;
    long bw_val = bpm_tune_get(tune, "block_width", 0);
    int bw = (bw_val > 0) ? (int)bw_val : bs;
    long pad_val = bpm_tune_get(tune, "copy_pad", 0);
    size_t pad = (pad_val > 0) ? ((size_t)pad_val + 15) & ~(size_t)15 : 0;

    int n = dA + dB + 1;
    for (int k = 0; k < n; k++) c[k] = 0.0f;

    /* Zero-padded, shifted copies of b, one segment per tile column J
     * (jj = J * bw, width w = jend - jj). Copy s, segment J holds
     *   seg[s + 7 + x] = b[jj + x]  for 0 <= x < w,  zeros elsewhere,
     * so row r of a group can read b[jj + u - r] = seg[s + 7 + u - r] for
     * every u in [0, tlen) and gets 0 outside the tile's columns. Segments
     * are whole 64-byte lines; copies are spaced a multiple of 4096 bytes
     * apart (+ copy_pad). */
    int TJ = (dB + bw) / bw;                        /* tile columns */
    size_t seg = ((size_t)bw + 7 + 8 + 7 + NCOPY + 15) & ~(size_t)15;
    size_t clen = (size_t)TJ * seg;
    clen = (clen + 1023) & ~(size_t)1023;           /* 1024 floats = 4096 B */
    clen += pad;
    float *bcbuf = aligned_alloc(64, NCOPY * clen * sizeof(float));
    for (size_t x = 0; x < NCOPY * clen; x++) bcbuf[x] = 0.0f;
    for (int s = 0; s < NCOPY; s++) {
        for (int J = 0; J < TJ; J++) {
            int jj = J * bw;
            int jend = (jj + bw <= dB + 1) ? jj + bw : dB + 1;
            float *dst = bcbuf + s * clen + (size_t)J * seg + s + 7;
            for (int x = 0; x < jend - jj; x++) dst[x] = b[jj + x];
        }
    }

    BPM_COMP_DECL(comp, n);

    for (int ii = 0; ii <= dA; ii += bs) {
        int iend = (ii + bs <= dA + 1) ? ii + bs : dA + 1;
        for (int J = 0; J < TJ; J++) {
            int jj = J * bw;
            int jend = (jj + bw <= dB + 1) ? jj + bw : dB + 1;

            /* Row r reads from copy s = (r + 1) % 4 through
             * p[r] = seg + s + 7 - r, so p[r][u] = b[jj + u - r] (0 outside
             * the tile). s + 7 - r is a multiple of 4, so each load of row r
             * starts on a 16-byte boundary when u is a multiple of 8. */
            const float *p[R];
            for (int r = 0; r < R; r++) {
                int s = (r + 1) % NCOPY;
                p[r] = bcbuf + s * clen + (size_t)J * seg + s + 7 - r;
            }
            const float *restrict p0 = p[0], *restrict p1 = p[1];
            const float *restrict p2 = p[2], *restrict p3 = p[3];
            const float *restrict p4 = p[4], *restrict p5 = p[5];
            const float *restrict p6 = p[6], *restrict p7 = p[7];

            /* The whole trapezoid of a group, t = jj + u for u in
             * [0, w + 7), rounded up to a multiple of 8 so the vector loop
             * has no remainder; the extra products are a * 0. Clamped so
             * c[i0 + jj + u] stays inside c (only zero products are cut). */
            int tlen = (jend - jj + 7 + 7) & ~7;
            int i0 = ii;
            for (; i0 + R <= iend; i0 += R) {
                const float a0 = a[i0],     a1 = a[i0 + 1];
                const float a2 = a[i0 + 2], a3 = a[i0 + 3];
                const float a4 = a[i0 + 4], a5 = a[i0 + 5];
                const float a6 = a[i0 + 6], a7 = a[i0 + 7];
                int k0 = i0 + jj;
                int ulen = (tlen <= n - k0) ? tlen : n - k0;

                /* all 8 rows into c[k0 + u], ragged ends included */
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

            /* leftover rows (last tile row only) */
            for (int i = i0; i < iend; i++) {
                for (int j = jj; j < jend; j++) {
                    BPM_ACC(c, comp, i + j, a[i] * b[j]);
                }
            }
        }
    }

    BPM_COMP_FREE(comp);
    free(bcbuf);
}

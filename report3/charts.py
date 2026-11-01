"""Inline SVG charts for the PA3 report, built from the sweep CSVs.

Run from the project root: python3 report3/build.py (build.py imports this).
"""
import csv
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TPP = 35.2


def load(path, key):
    """Return {key value: gflops_median} from a sweep CSV."""
    rows = list(csv.reader(open(os.path.join(ROOT, path))))
    h = [i for i, r in enumerate(rows) if r and r[0] == 'threads'][0]
    hdr = rows[h]
    out = {}
    for r in rows[h + 1:]:
        if not r:
            continue
        d = dict(zip(hdr, r))
        out[int(d[key])] = float(d['gflops_median'])
    return out


def load2(path):
    """Two-axis CSV (threads x block_size) -> {(t, bs): gflops}."""
    rows = list(csv.reader(open(os.path.join(ROOT, path))))
    h = [i for i, r in enumerate(rows) if r and r[0] == 'threads'][0]
    hdr = rows[h]
    out = {}
    for r in rows[h + 1:]:
        d = dict(zip(hdr, r))
        out[(int(d['threads']), int(d['block_size']))] = float(d['gflops_median'])
    return out


def fmt(v):
    return f'{v:g}'


def chart(series, xticks, yticks, xlab, ylab, xmap=None, refs=(), h=340,
          xticklabels=None):
    """series: list of dict(pts=[(x,y)], cls='s1', dash=False, hollow=False,
    label='')  refs: list of dict(pts=[(x,y)], kind='peak'|'ceil'|'ideal')."""
    W, L, R, T, B = 680, 56, 16, 14, h - 44
    xmap = xmap or (lambda v: v)
    xs = [xmap(x) for x in xticks]
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(yticks), max(yticks)

    def X(v):
        return L + 12 + (xmap(v) - x0) / (x1 - x0) * (W - L - R - 24)

    def Y(v):
        return B - (v - y0) / (y1 - y0) * (B - T)

    o = [f'<figure><div class="scroll"><svg viewBox="0 0 {W} {h}" role="img" class="chart">']
    for v in yticks:
        o.append(f'<line x1="{L}" x2="{W-R}" y1="{Y(v):.1f}" y2="{Y(v):.1f}" class="grid"/>'
                 f'<text x="{L-6}" y="{Y(v)+4:.1f}" class="tick" text-anchor="end">{fmt(v)}</text>')
    labels = xticklabels or [fmt(v) for v in xticks]
    for v, lab in zip(xticks, labels):
        o.append(f'<line x1="{X(v):.1f}" x2="{X(v):.1f}" y1="{B}" y2="{B+4}" class="axis"/>'
                 f'<text x="{X(v):.1f}" y="{B+17}" class="tick" text-anchor="middle">{lab}</text>')
    o.append(f'<line x1="{L}" x2="{W-R}" y1="{B}" y2="{B}" class="axis"/>'
             f'<line x1="{L}" x2="{L}" y1="{T}" y2="{B}" class="axis"/>')
    o.append(f'<text x="{(L+W-R)/2:.0f}" y="{h-6}" class="lab" text-anchor="middle">{xlab}</text>')
    o.append(f'<text x="14" y="{(T+B)/2:.0f}" class="lab" text-anchor="middle" '
             f'transform="rotate(-90 14 {(T+B)/2:.0f})">{ylab}</text>')
    for r in refs:
        d = ' '.join(f'{"M" if i == 0 else "L"}{X(x):.1f},{Y(y):.1f}' for i, (x, y) in enumerate(r['pts']))
        o.append(f'<path d="{d}" class="{r["kind"]}" fill="none"/>')
        if r.get('label'):
            x, y = r['pts'][-1]
            o.append(f'<text x="{X(x)-4:.1f}" y="{Y(y)-6:.1f}" class="hl" text-anchor="end">{r["label"]}</text>')
    for s in series:
        pts = sorted(s['pts'])
        col = f'var(--{s["cls"]})'
        if not s.get('nolines'):
            d = ' '.join(f'{"M" if i == 0 else "L"}{X(x):.1f},{Y(y):.1f}' for i, (x, y) in enumerate(pts))
            dash = ' stroke-dasharray="5 4"' if s.get('dash') else ''
            o.append(f'<path d="{d}" class="ln" style="stroke:{col}"{dash}/>')
        for x, y in pts:
            if s.get('hollow'):
                o.append(f'<circle cx="{X(x):.1f}" cy="{Y(y):.1f}" r="4" class="hollow" style="stroke:{col}"/>')
            else:
                o.append(f'<circle cx="{X(x):.1f}" cy="{Y(y):.1f}" r="3" style="fill:{col}"/>')
    o.append('</svg></div>')
    o.append('<div class="legend">')
    for s in series:
        col = f'var(--{s["cls"]})'
        if s.get('hollow'):
            o.append(f'<span class="key"><i class="hk" style="border-color:{col}"></i>{s["label"]}</span>')
        else:
            o.append(f'<span class="key"><i style="background:{col}"></i>{s["label"]}</span>')
    for r in refs:
        if r.get('key'):
            o.append(f'<span class="key"><i class="ik"></i>{r["key"]}</span>')
    o.append('</div></figure>')
    return ''.join(o)


LOG2 = lambda v: math.log2(v)


def c_single_core():
    """% TPP vs block size, one core, 100K: BKQ .. BKQ7."""
    src = [('BKQ', '03-BKQ/results/2026.10.18.007_bs_sweep_100000x100000.csv', 's4', True),
           ('BKQ2 (unroll-and-jam)', '03-BKQ2/results/2026.10.18.007_bs_sweep_100000x100000.csv', 's3', True),
           ('BKQ3 (FMA chain kept)', '03-BKQ3/results/2026.10.18.005_bs_sweep_100000x100000.csv', 's2', True),
           ('BKQ4 (aligned copies)', '03-BKQ4/results/2026.10.18.005_bs_sweep_100000x100000.csv', 's5', True),
           ('BKQ7 (vector edges)', '03-BKQ7/results/2026.10.18.002_bs_sweep_100000x100000.csv', 's1', False)]
    series = []
    for lab, p, cls, dash in src:
        d = load(p, 'block_size')
        series.append(dict(pts=[(k, v / TPP * 100) for k, v in d.items()], cls=cls, dash=dash, label=lab))
    xt = [256, 512, 768, 1024, 1536, 2048, 3072, 4096]
    return chart(series, xt, [0, 20, 40, 60, 80, 100], 'block size (square tiles, log scale)',
                 '% of one core\'s TPP', xmap=LOG2,
                 refs=[dict(pts=[(256, 100), (4096, 100)], kind='peak', key='TPP (35.2 GFLOP/s)')])


def c_spacing():
    """% TPP vs copy spacing mod 4096, bs=3072, three sizes."""
    src = [(100000, '03-BKQ4/results/2026.10.18.006_copy_pad_sweep_100000x100000.csv', 's1', False, False),
           (40000, '03-BKQ4/results/2026.10.18.008_copy_pad_sweep_40000x40000.csv', 's2', True, True)]
    series = []
    for n, p, cls, dash, hollow in src:
        d = load(p, 'copy_pad')
        pts = []
        for pad, g in d.items():
            r16 = lambda v: (v + 15) // 16 * 16
            s = 4 * r16(n + 5 + r16(pad)) % 4096
            pts.append((s, g / TPP * 100))
        series.append(dict(pts=pts, cls=cls, dash=dash, hollow=hollow, nolines=hollow,
                           label=f'{n//1000}K × {n//1000}K'))
    xt = [0, 512, 1024, 1536, 2048, 2560, 3072, 3584, 4032]
    return chart(series, xt, [40, 45, 50, 55, 60, 65], 'spacing between copies of b, mod 4096 bytes',
                 '% of one core\'s TPP',
                 xticklabels=['0', '512', '1024', '1536', '2048', '2560', '3072', '3584', '4032'])


def c_width():
    """BKQ6 width sweep at height 3072, plus BKQ7 spot checks."""
    d = load('03-BKQ6/results/2026.10.18.002_width_bs3072_100000x100000.csv', 'block_width')
    q7 = {64: 21.976, 256: 24.799, 3072: 25.246}   # BKQ7.1 quick timings (3 reps)
    series = [dict(pts=list(d.items()), cls='s2', label='BKQ6, height 3072 (scalar edges)'),
              dict(pts=list(q7.items()), cls='s1', hollow=True, label='BKQ7, height 3072 (vector edges, spot checks)')]
    xt = [1, 4, 16, 64, 256, 1024, 3072]
    return chart(series, xt, [0, 5, 10, 15, 20, 25, 30, 35], 'tile width (columns of b, log scale)',
                 'GFLOP/s, one core', xmap=LOG2,
                 refs=[dict(pts=[(1, 35.2), (3072, 35.2)], kind='peak', key='TPP')])


def c_threads():
    """Part B thread sweeps, best block of each variant."""
    src = [('BKP1 rows + reduction, bs 1024', '03-BKP1/results/2026.10.18.002_threads_bs1024_100000x100000.csv', 's4', True),
           ('BKP2 tiles + reduction, bs 1024', '03-BKP2/results/2026.10.18.002_threads_bs1024_100000x100000.csv', 's3', True),
           ('BKP3 checkerboard (racy), bs 1024', '03-BKP3/results/diagnostic/2026.10.18.003_threads_bs1024_100000x100000.csv', 's5', True),
           ('BKP4 diagonal parity, bs 1024', '03-BKP4/results/2026.10.18.002_threads_bs1024_100000x100000.csv', 's2', False),
           ('BKP5 parity + BKQ7 kernel, bs 512', '03-BKP5/results/2026.10.18.003_threads_bs512_100000x100000.csv', 's1', False)]
    series = []
    for lab, p, cls, dash in src:
        d = load(p, 'threads')
        series.append(dict(pts=list(d.items()), cls=cls, dash=dash, label=lab))
    xt = [1, 2, 4, 6, 8, 10, 12, 14, 16]
    return chart(series, xt, [0, 100, 200, 300, 400, 500, 600], 'threads (cores 16–31)', 'GFLOP/s',
                 refs=[dict(pts=[(1, 35.2), (16, 563.2)], kind='peak', key='TPP (35.2 × threads)')], h=380)


def c_bkp2_per_core():
    """BKP2: per-thread % TPP vs threads, three block sizes."""
    src = [('bs 1024', '03-BKP2/results/2026.10.18.002_threads_bs1024_100000x100000.csv', 's1'),
           ('bs 1536', '03-BKP2/results/2026.10.18.003_threads_bs1536_100000x100000.csv', 's3'),
           ('bs 3072', '03-BKP2/results/2026.10.18.004_threads_bs3072_100000x100000.csv', 's2')]
    series = []
    for lab, p, cls in src:
        d = load(p, 'threads')
        series.append(dict(pts=[(t, g / (TPP * t) * 100) for t, g in d.items()], cls=cls, label=lab))
    xt = [1, 2, 4, 6, 8, 10, 12, 14, 16]
    return chart(series, xt, [40, 45, 50, 55, 60, 65], 'threads', '% TPP per core')


def c_bkp5_bs():
    """BKP5: GF/s vs block size at 8 and 16 threads."""
    d = load2('03-BKP5/results/2026.10.18.002_threads_x_bs_100000x100000.csv')
    bss = sorted({k[1] for k in d})
    series = [dict(pts=[(b, d[(16, b)]) for b in bss], cls='s1', label='16 threads'),
              dict(pts=[(b, d[(8, b)]) for b in bss], cls='s3', label='8 threads'),
              dict(pts=[(b, d[(1, b)] * 16) for b in bss], cls='s4', dash=True, label='16 × the 1-thread rate')]
    return chart(series, bss, [0, 100, 200, 300, 400, 500], 'block size (log scale)', 'GFLOP/s', xmap=LOG2)

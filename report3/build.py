"""Build PA3-report.html from report3/body.html, report3/style.css and the
sweep CSVs (charts.py). Run from anywhere: python3 report3/build.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import charts  # noqa: E402


def tile_grid(mark):
    """5x5 tile grid. mark(I, J) -> (fill var, text)."""
    s, o = 44, 30
    out = [f'<figure><svg viewBox="0 0 {o*2 + 5*s + 220} {o*2 + 5*s}" role="img" class="diagram" '
           f'style="max-width:520px;width:100%;height:auto;display:block">']
    for I in range(5):
        for J in range(5):
            fill, txt = mark(I, J)
            x, y = o + J * s, o + I * s
            out.append(f'<rect x="{x}" y="{y}" width="{s-3}" height="{s-3}" rx="3" '
                       f'style="fill:{fill};stroke:var(--rule)"/>')
            if txt:
                out.append(f'<text x="{x + (s-3)/2}" y="{y + (s-3)/2 + 4}" text-anchor="middle" '
                           f'style="font:500 12px \'IBM Plex Mono\',monospace;fill:var(--ink)">{txt}</text>')
    for k in range(5):
        out.append(f'<text x="{o + k*s + (s-3)/2}" y="{o-8}" text-anchor="middle" class="tick" '
                   f'style="fill:var(--muted);font:11px \'IBM Plex Mono\',monospace">J={k}</text>')
        out.append(f'<text x="{o-6}" y="{o + k*s + (s-3)/2 + 4}" text-anchor="end" '
                   f'style="fill:var(--muted);font:11px \'IBM Plex Mono\',monospace">I={k}</text>')
    return out


def diag_overlap():
    def mark(I, J):
        if (I, J) == (2, 2):
            return 'var(--s5)', 'X'
        d = I + J - 4
        if d == 0:
            return 'var(--warn-bg)', 'same'
        if abs(d) == 1:
            return 'var(--note-bg)', '±1'
        return 'var(--card)', ''
    out = tile_grid(mark)
    x = 30 * 2 + 5 * 44 + 4
    out.append(f'<text x="{x}" y="70" style="font:12px \'IBM Plex Sans\',sans-serif;fill:var(--ink)">'
               f'<tspan x="{x}" dy="0">X: tile (2, 2), writes</tspan>'
               f'<tspan x="{x}" dy="16">c[4·bs .. 6·bs − 2]</tspan>'
               f'<tspan x="{x}" dy="26">same: same diagonal I+J,</tspan>'
               f'<tspan x="{x}" dy="16">same range of c (and the</tspan>'
               f'<tspan x="{x}" dy="16">same checkerboard colour)</tspan>'
               f'<tspan x="{x}" dy="26">±1: neighbouring diagonal,</tspan>'
               f'<tspan x="{x}" dy="16">half the range overlaps</tspan></text>')
    out.append('</svg></figure>')
    return ''.join(out)


def diag_parity():
    def mark(I, J):
        d = I + J
        return ('var(--note-bg)' if d % 2 == 0 else 'var(--warn-bg)'), f'd{d}'
    out = tile_grid(mark)
    x = 30 * 2 + 5 * 44 + 4
    out.append(f'<text x="{x}" y="70" style="font:12px \'IBM Plex Sans\',sans-serif;fill:var(--ink)">'
               f'<tspan x="{x}" dy="0">Phase 0: even diagonals</tspan>'
               f'<tspan x="{x}" dy="16">d0, d2, d4, d6, d8 at once,</tspan>'
               f'<tspan x="{x}" dy="16">one thread per diagonal</tspan>'
               f'<tspan x="{x}" dy="26">barrier</tspan>'
               f'<tspan x="{x}" dy="26">Phase 1: odd diagonals</tspan>'
               f'<tspan x="{x}" dy="16">d1, d3, d5, d7</tspan></text>')
    out.append('</svg></figure>')
    return ''.join(out)


def main():
    body = open(os.path.join(HERE, 'body.html')).read()
    css = open(os.path.join(HERE, 'style.css')).read()
    subs = {
        '@@C_SINGLE@@': charts.c_single_core(),
        '@@C_SPACING@@': charts.c_spacing(),
        '@@C_WIDTH@@': charts.c_width(),
        '@@C_THREADS@@': charts.c_threads(),
        '@@C_BKP2@@': charts.c_bkp2_per_core(),
        '@@C_BKP5BS@@': charts.c_bkp5_bs(),
        '@@D_OVERLAP@@': diag_overlap(),
        '@@D_PARITY@@': diag_parity(),
    }
    for k, v in subs.items():
        assert k in body, k
        body = body.replace(k, v)
    html = ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>PA3 Blocking Report</title>'
            '<link rel="preconnect" href="https://fonts.googleapis.com">'
            '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500'
            '&family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;1,400&family=IBM+Plex+Sans+Condensed:wght@600'
            '&display=swap">'
            f'<style>\n{css}\n</style></head><body>\n{body}\n</body></html>\n')
    out = os.path.join(os.path.dirname(HERE), 'PA3-report.html')
    open(out, 'w').write(html)
    print('wrote', out, len(html), 'bytes')


if __name__ == '__main__':
    main()

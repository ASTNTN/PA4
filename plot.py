#!/usr/bin/env python3
"""Turn one or more StudentPolyMult results csvs (collect.py's preamble +
data-table format) into an .xlsx workbook with native charts.

Two chart styles, chosen automatically per csv's own preamble:

CLASSIC (a csv with no axis_order, or axis_order == "threads" -- i.e. a
plain or classic --threads-sweep sweep.sh call): the original combined
Speedup (line, left axis) + Performance (%TPP bars, right axis) chart vs.
thread count. Each --csv is one run/series here; multiple --csv values
superpose on Speedup and group side by side on Performance.

MULTI-AXIS (a csv whose axis_order names a tuning parameter, from
sweep.sh's --tune KEY=RANGE support): a %TPP bar chart per swept
configuration -- axis 1 (x-axis), axis 2 (series/cluster color, sorted by
its own numeric value and assigned colors from a fixed, colorblind
-validated order -- never reassigned by rank), axis 3/4 (facet panels,
laid out side by side / in a grid). Only a single --csv is supported in
this style for now -- comparing runs would need "which csv" as another
axis, not yet implemented. This style is always Performance-only (no
Speedup/seq_time -- see sweep.sh/EXPERIMENTS.md for why).

%TPP uses a thread-scaled denominator, so an ideal linear speedup reads as
a flat 100% line:

    %TPP(t) = GFLOPs/s(t) / (TPP_per_core * t) * 100

This is the corrected formula (matches BestPolyMult/tools/plot_results.py);
an earlier draft of this tool (PlottingScripts/plot.py) used a fixed,
non-thread-scaled denominator, which grows linearly with thread count under
ideal speedup instead of staying flat, and has not itself been fixed yet.

Speedup(t) = seq_time / stat_time(t), where seq_time is the csv preamble's
own T(1) (supplied by sweep.sh's T(seq) carry-through, see
EXPERIMENTS.md) and stat_time is the median or mean_wo_outliers
column, per --stat. A classic-path csv missing seq_time is refused
(SystemExit) rather than silently plotted without a baseline.

Output placement: if --out is not given, it's derived from where the input
csvs live and today's date. Every csv under the same NN-VARIANT directory
(e.g. 00-GSQ) is a single-variant plot and lands inside that variant's own
tree: <variant-dir>/plots/YYYY.MM.DD.NNN.<Topic>.xlsx -- NNN is the next
unused sequence number for today's date in that directory (starts at 001
each day). Csvs spanning more than one variant directory are a
cross-variant plot and land one level up, at the common parent's plots/ --
e.g. two csvs under 00-GSQ and 01-OPQ produce
StudentPolyMult/plots/YYYY.MM.DD.NNN.<Topic>.xlsx. <Topic> is --topic,
required whenever --out is omitted (no more auto-derivation from --title --
pass --topic explicitly). An explicit --out always wins over all of this.

Usage:
  plot.py --csv FILE [--csv FILE ...] --tpp-per-core VALUE
          [--out WORKBOOK.xlsx | --topic TOPIC] [--label NAME ...]
          [--tmp VALUE] [--stat median|mean_wo_outliers] [--title TITLE]
"""
import argparse
import csv
import datetime
import os
import re
import sys

import xlsxwriter
from xlsxwriter.utility import xl_range, xl_rowcol_to_cell

STAT_CHOICES = ("median", "mean_wo_outliers")

# Categorical palette, fixed order -- validated for adjacent-pair
# colorblind safety in this order (see the dataviz skill's palette.md).
# Axis-2 series are colored by their SORTED NUMERIC position in this
# order, never reassigned per chart -- this is what keeps color tied to
# the palette's own validated adjacency rather than to how any one
# dataset happens to rank.
CATEGORICAL_PALETTE = [
    "#2a78d6",  # blue
    "#eb6834",  # orange
    "#1baf7a",  # aqua
    "#eda100",  # yellow
    "#e87ba4",  # magenta
    "#008300",  # green
    "#4a3aa7",  # violet
    "#e34948",  # red
]
MUTED = "#898781"
GRID = "#e1e0d9"
INK = "#0b0b0b"


def peek_preamble(path):
    """Reads just the preamble (everything before the 'threads' header
    row), without parsing the data table -- cheap enough to call on every
    --csv up front just to decide which chart style applies."""
    preamble = {}
    with open(path, newline="") as f:
        for row in csv.reader(f):
            if row and row[0] == "threads":
                break
            if len(row) >= 2:
                preamble[row[0]] = row[1]
    return preamble


def read_run_csv(path):
    """Classic-path reader, unchanged: returns (preamble: dict[str,str],
    table: dict[int, dict[str,float-or-None]]) keyed by thread count."""
    with open(path, newline="") as f:
        rows = list(csv.reader(f))

    preamble = {}
    i = 0
    header = None
    while i < len(rows):
        row = rows[i]
        if row and row[0] == "threads":
            header = row
            i += 1
            break
        if len(row) >= 2:
            preamble[row[0]] = row[1]
        i += 1
    if header is None:
        raise SystemExit(f"error: {path}: no 'threads' header row found "
                          f"(malformed results csv)")

    table = {}
    for row in rows[i:]:
        if not row or not row[0]:
            continue
        vals = dict(zip(header, row))
        t = int(float(vals["threads"]))
        entry = {}
        for key in ("median", "mean_wo_outliers", "gflops_median",
                    "gflops_mean_wo_outliers"):
            raw = vals.get(key, "")
            entry[key] = float(raw) if raw not in (None, "") else None
        table[t] = entry
    return preamble, table


def read_tidy_csv(path):
    """Multi-axis-path reader: returns (preamble, axis_order: list[str],
    rows: list[dict[str,str]]) -- one dict per swept configuration, every
    column (threads, swept axes, reps, stats) as a raw string; caller
    converts as needed."""
    with open(path, newline="") as f:
        raw_rows = list(csv.reader(f))
    preamble = {}
    i = 0
    header = None
    while i < len(raw_rows):
        row = raw_rows[i]
        if row and row[0] == "threads":
            header = row
            i += 1
            break
        if len(row) >= 2:
            preamble[row[0]] = row[1]
        i += 1
    if header is None:
        raise SystemExit(f"error: {path}: no 'threads' header row found "
                          f"(malformed results csv)")
    rows = []
    for row in raw_rows[i:]:
        if not row or not row[0]:
            continue
        rows.append(dict(zip(header, row)))
    axis_order = [a for a in preamble.get("axis_order", "threads").split(",") if a]
    return preamble, axis_order, rows


def parse_args(argv):
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--csv", action="append", required=True, dest="csvs",
                    help="input results csv (collect.py format); repeatable")
    p.add_argument("--label", action="append", default=[], dest="labels",
                    help="series label, paired positionally with --csv; "
                         "defaults to the csv's own 'variant' preamble value")
    p.add_argument("--tpp-per-core", required=True, type=float,
                    help="theoretical peak GFLOPs/s of one core; the "
                         "thread-scaled %%TPP denominator is this * threads")
    p.add_argument("--tmp", type=float, default=None,
                    help="theoretical machine peak GFLOPs/s; stored in the "
                         "Config tab only, not used in any chart")
    p.add_argument("--stat", choices=STAT_CHOICES, default="median",
                    help="which aggregate time feeds GFLOPs/s and speedup "
                         "(default: median)")
    p.add_argument("--out", default=None,
                    help="output .xlsx path; if omitted, derived "
                         "automatically (see module docstring)")
    p.add_argument("--topic", default=None,
                    help="topic name for the auto-derived output filename "
                         "(plots/YYYY.MM.DD.NNN.<Topic>.xlsx); required "
                         "whenever --out is omitted")
    p.add_argument("--title", default=None,
                    help="chart display title; independent of --topic")
    args = p.parse_args(argv)
    if args.labels and len(args.labels) != len(args.csvs):
        p.error("--label, if given, must be given exactly once per --csv")
    if args.out is None and args.topic is None:
        p.error("--out requires either an explicit value or --topic "
                 "(auto-naming from --title has been retired)")
    return args


VARIANT_DIR_RE = re.compile(r"^\d{2}-[A-Za-z0-9]+$")


def slugify(text):
    s = re.sub(r"[^A-Za-z0-9]+", "-", text.strip()).strip("-")
    return s or "plot"


def find_variant_dir(csv_path):
    """Walk up from csv_path looking for an ancestor matching the project's
    NN-VARIANT directory convention (e.g. 00-GSP1, 01-OPQ). Returns that
    ancestor's absolute path, or None if csv_path isn't under one."""
    p = os.path.abspath(csv_path)
    d = os.path.dirname(p)
    while d and d != os.path.dirname(d):
        if VARIANT_DIR_RE.match(os.path.basename(d)):
            return d
        d = os.path.dirname(d)
    return None


def next_sequence(out_dir, date_str):
    """Next unused NNN for date_str in out_dir -- scans existing
    date_str.NNN.*.xlsx files there and returns one past the highest
    found, or 1 if none exist (or out_dir doesn't exist yet). Resets to 1
    each new date_str, matching the existing hand-made
    2026.09.14.002/003.block_size_sweep.xlsx precedent."""
    if not os.path.isdir(out_dir):
        return 1
    pat = re.compile(re.escape(date_str) + r"\.(\d+)\.")
    best = 0
    for name in os.listdir(out_dir):
        m = pat.match(name)
        if m:
            best = max(best, int(m.group(1)))
    return best + 1


def derive_out_path(csv_paths, topic):
    """Single-variant plot (every --csv under the same NN-VARIANT dir) goes
    inside that variant's own plots/ directory; a plot spanning more than
    one variant dir goes one level up, at their common parent's plots/.
    Flat filename, no per-topic subdirectory: YYYY.MM.DD.NNN.<Topic>.xlsx.
    A csv not under any recognized variant dir can't be placed
    automatically."""
    variant_dirs = {find_variant_dir(c) for c in csv_paths}
    if None in variant_dirs:
        return None
    if len(variant_dirs) == 1:
        base_dir = next(iter(variant_dirs))
    else:
        parents = {os.path.dirname(d) for d in variant_dirs}
        if len(parents) != 1:
            return None
        base_dir = next(iter(parents))
    out_dir = os.path.join(base_dir, "plots")
    date_str = datetime.date.today().strftime("%Y.%m.%d")
    seq = next_sequence(out_dir, date_str)
    safe_topic = slugify(topic).replace("-", "")
    return os.path.join(out_dir, f"{date_str}.{seq:03d}.{safe_topic}.xlsx")


def qref(sheet, row, col):
    return f"'{sheet}'!{xl_rowcol_to_cell(row, col)}"


LINEBREAK_RUN_RE = re.compile(
    r"<a:r>(<a:rPr[^>]*/>)<a:t>([^<]*?)\n([^<]*?)</a:t></a:r>")


def fix_axis_title_linebreaks(xlsx_path):
    """xlsxwriter embeds a chart title's "\\n" as a literal newline character
    inside one <a:t> text run -- valid XML, but not how DrawingML represents
    a line break (that needs a real <a:br/> element between two runs), and
    not something every consumer renders as two lines. Post-process the
    written file to split any such run into two runs joined by <a:br/>,
    each carrying the same run properties as the original."""
    import shutil
    import tempfile
    import zipfile

    with zipfile.ZipFile(xlsx_path) as zin:
        names = zin.namelist()
        changed = {}
        for name in names:
            if not re.match(r"xl/charts/chart\d+\.xml", name):
                continue
            data = zin.read(name).decode("utf-8")
            new_data, n = LINEBREAK_RUN_RE.subn(
                r"<a:r>\1<a:t>\2</a:t></a:r><a:br>\1</a:br><a:r>\1<a:t>\3</a:t></a:r>",
                data)
            if n:
                changed[name] = new_data
        if not changed:
            return

    fd, tmp_path = tempfile.mkstemp(suffix=".xlsx", dir=os.path.dirname(xlsx_path) or ".")
    os.close(fd)
    with zipfile.ZipFile(xlsx_path) as zin, zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = changed.get(item.filename)
            if data is not None:
                zout.writestr(item, data.encode("utf-8"))
            else:
                zout.writestr(item, zin.read(item.filename))
    shutil.move(tmp_path, xlsx_path)


# ---------------------------------------------------------------------------
# Classic path: combined Speedup + Performance vs. thread count. Unchanged
# from before the multi-axis redesign.
# ---------------------------------------------------------------------------

def build_classic_workbook(wb, args, csv_paths):
    time_key = args.stat
    gflops_key = "gflops_" + args.stat

    runs = []
    for i, path in enumerate(csv_paths):
        preamble, table = read_run_csv(path)
        label = args.labels[i] if args.labels else preamble.get("variant", f"run{i+1}")
        seq_time = preamble.get("seq_time")
        seq_time = float(seq_time) if seq_time not in (None, "") else None
        runs.append({
            "label": label, "path": path, "preamble": preamble,
            "table": table, "seq_time": seq_time,
        })
        if seq_time is None:
            raise SystemExit(
                f"error: {path}: no seq_time in preamble. Every sweep's "
                f"csv must carry a sequential baseline -- run "
                f"sweep.sh --record-seq once for this variant (see "
                f"EXPERIMENTS.md), which every later sweep then "
                f"picks up automatically.")

    measured_threads = sorted({t for r in runs for t in r["table"].keys()})
    all_threads = list(range(1, measured_threads[-1] + 1)) if measured_threads else []

    CAP_THRESHOLD_PCT = 67.0
    max_pct = 0.0
    for r in runs:
        for t in all_threads:
            entry = r["table"].get(t)
            gflops = entry[gflops_key] if entry else None
            if gflops is not None:
                max_pct = max(max_pct, gflops / (args.tpp_per_core * t) * 100)
    cap_axis = max_pct <= CAP_THRESHOLD_PCT
    axis_max = (max_pct // 10 + 2) * 10 if cap_axis else max(100, (max_pct // 10 + 1) * 10)

    fmt_hdr = wb.add_format({"bold": True, "bg_color": "#DCE6F1"})
    fmt_bold = wb.add_format({"bold": True})
    fmt_2_1 = wb.add_format({"num_format": "00.0"})

    cfg = wb.add_worksheet("Config")
    cfg.set_column(0, 0, 22)
    cfg.set_column(1, 1, 40)
    cfg.write(0, 0, "Parameter", fmt_hdr)
    cfg.write(0, 1, "Value", fmt_hdr)
    cfg.write(1, 0, "TPP per core (GFLOPs/s)")
    cfg.write_number(1, 1, args.tpp_per_core)
    wb.define_name("TPP_PER_CORE", "=Config!$B$2")
    cfg.write(2, 0, "TMP (GFLOPs/s)")
    if args.tmp is not None:
        cfg.write_number(2, 1, args.tmp)
    cfg.write(3, 0, "Stat used")
    cfg.write(3, 1, args.stat)
    row = 5
    cfg.write(row, 0, "Runs", fmt_hdr)
    row += 1
    for r in runs:
        cfg.write(row, 0, r["label"])
        cfg.write(row, 1, r["path"])
        row += 1
        for k, v in r["preamble"].items():
            cfg.write(row, 0, f"  {k}")
            cfg.write(row, 1, v)
            row += 1

    used_names = {"Config"}

    def safe_name(name):
        cleaned = "".join(c if c.isalnum() else "_" for c in name)[:28] or "Raw"
        candidate = cleaned
        n = 1
        while candidate in used_names:
            candidate = f"{cleaned[:26]}_{n}"
            n += 1
        used_names.add(candidate)
        return candidate

    for r in runs:
        sname = safe_name(f"{r['label']}_Raw")
        r["raw_sheet"] = sname
        ws = wb.add_worksheet(sname)
        rr = 0
        for k, v in r["preamble"].items():
            ws.write(rr, 0, k, fmt_bold)
            ws.write(rr, 1, v)
            rr += 1
        rr += 1
        cols = ["threads", "median", "mean_wo_outliers", "gflops_median",
                "gflops_mean_wo_outliers"]
        for c, name in enumerate(cols):
            ws.write(rr, c, name, fmt_hdr)
        header_row = rr
        rr += 1
        r["table_rows"] = {}
        for t in sorted(r["table"].keys()):
            entry = r["table"][t]
            ws.write_number(rr, 0, t)
            for c, name in enumerate(cols[1:], start=1):
                val = entry[name]
                if val is None:
                    ws.write_formula(rr, c, "=NA()")
                else:
                    ws.write_number(rr, c, val)
            r["table_rows"][t] = rr
            rr += 1
        r["header_row"] = header_row

    spd = wb.add_worksheet("Speedup")
    spd.write(0, 0, "Threads", fmt_hdr)
    for j, r in enumerate(runs):
        spd.write(0, 1 + j, f"{r['label']} speedup", fmt_hdr)
    c_ideal = 1 + len(runs)
    spd.write(0, c_ideal, "Ideal speedup", fmt_hdr)
    c_perf0 = c_ideal + 1
    for j, r in enumerate(runs):
        spd.write(0, c_perf0 + j, f"{r['label']} Thread-normalized Performance", fmt_hdr)
    n_t = len(all_threads)
    for i, t in enumerate(all_threads):
        row_i = i + 1
        spd.write_number(row_i, 0, t)
        for j, r in enumerate(runs):
            col = 1 + j
            entry = r["table"].get(t)
            stat_time = entry[time_key] if entry else None
            if entry is not None and stat_time and r["seq_time"] is not None:
                spd.write_number(row_i, col, r["seq_time"] / stat_time)
            else:
                spd.write_formula(row_i, col, "=NA()")
            gflops = entry[gflops_key] if entry else None
            if gflops is not None:
                spd.write_number(row_i, c_perf0 + j, gflops / (args.tpp_per_core * t) * 100, fmt_2_1)
            else:
                spd.write_formula(row_i, c_perf0 + j, "=NA()", fmt_2_1)
        spd.write_number(row_i, c_ideal, t)
    AXIS_FONT = {"size": 14}

    perf = wb.add_worksheet("Performance")
    perf.write(0, 0, "Threads", fmt_hdr)
    col_map = {}
    col = 1
    for r in runs:
        c_pct, c_gf = col, col + 1
        col_map[r["label"]] = (c_pct, c_gf)
        perf.write(0, c_pct, f"{r['label']} % of TPP", fmt_hdr)
        perf.write(0, c_gf, f"{r['label']} GFLOPs/s", fmt_hdr)
        col += 2
    c_ref = None
    if not cap_axis:
        c_ref = col
        perf.write(0, c_ref, "100% TPP", fmt_hdr)

    for i, t in enumerate(all_threads):
        row_i = i + 1
        perf.write_number(row_i, 0, t)
        for r in runs:
            c_pct, c_gf = col_map[r["label"]]
            entry = r["table"].get(t)
            gflops = entry[gflops_key] if entry else None
            if gflops is not None:
                perf.write_number(row_i, c_gf, gflops, fmt_2_1)
                pct = gflops / (args.tpp_per_core * t) * 100
                perf.write_formula(
                    row_i, c_pct,
                    f"={qref('Performance', row_i, c_gf)}/(TPP_PER_CORE*{t})*100",
                    fmt_2_1, pct)
            else:
                perf.write_formula(row_i, c_pct, "=NA()", fmt_2_1)
                perf.write_formula(row_i, c_gf, "=NA()", fmt_2_1)
        if c_ref is not None:
            perf.write_number(row_i, c_ref, 100, fmt_2_1)

    line_chart = wb.add_chart({"type": "line"})
    for j, r in enumerate(runs):
        col = 1 + j
        line_chart.add_series({
            "name": f"{r['label']} speedup",
            "categories": ["Speedup", 1, 0, n_t, 0],
            "values": ["Speedup", 1, col, n_t, col],
            "marker": {"type": "circle", "size": 6},
        })
    line_chart.add_series({
        "name": "Ideal speedup",
        "categories": ["Speedup", 1, 0, n_t, 0],
        "values": ["Speedup", 1, c_ideal, n_t, c_ideal],
        "line": {"dash_type": "dash", "color": "#888888", "width": 1.5},
        "marker": {"type": "none"},
    })
    x_axis_name = "Threads"
    if cap_axis:
        x_axis_name += (
            f"\nNote: y-axis capped at {axis_max:.0f}%, (tallest bar is "
            f"{max_pct:.1f}% of TPP)")
    line_chart.set_title({"name": (args.title or "Speedup & Performance") + " vs. thread count"})
    line_chart.set_x_axis({"name": x_axis_name,
                            "name_font": AXIS_FONT, "num_font": AXIS_FONT})
    line_chart.set_y_axis({"name": "Speedup",
                            "name_font": AXIS_FONT, "num_font": AXIS_FONT})

    bar = wb.add_chart({"type": "column", "subtype": "clustered"})
    for r in runs:
        c_pct, c_gf = col_map[r["label"]]
        custom_labels = [{"value": qref("Performance", 1 + i, c_gf)}
                          for i in range(n_t)]
        bar.add_series({
            "name": r["label"],
            "categories": ["Performance", 1, 0, n_t, 0],
            "values": ["Performance", 1, c_pct, n_t, c_pct],
            "y2_axis": True,
            "data_labels": {"custom": custom_labels, "num_format": "00.0"},
        })
    if not cap_axis:
        bar.add_series({
            "name": "100% TPP",
            "categories": ["Performance", 1, 0, n_t, 0],
            "values": ["Performance", 1, c_ref, n_t, c_ref],
            "y2_axis": True,
            "fill": {"color": "#888888"},
        })
    bar.set_y2_axis({"name": "Thread-normalized Performance", "min": 0, "max": axis_max,
                      "num_format": "0", "name_font": AXIS_FONT, "num_font": AXIS_FONT})

    line_chart.combine(bar)
    line_chart.set_legend({"position": "bottom", "font": AXIS_FONT})
    line_chart.set_size({"width": 760, "height": 920})
    spd.insert_chart(1, 7, line_chart)

    spd.activate()
    return len(runs), all_threads


# ---------------------------------------------------------------------------
# Multi-axis path: one or more facet panels, each a %TPP clustered-bar
# chart. Performance-only (no Speedup/seq_time) -- see module docstring.
# ---------------------------------------------------------------------------

def build_multiaxis_workbook(wb, args, csv_path):
    preamble, axis_order, rows = read_tidy_csv(csv_path)
    gflops_key = "gflops_" + args.stat

    ax1 = axis_order[0]
    ax2 = axis_order[1] if len(axis_order) > 1 else None
    ax3 = axis_order[2] if len(axis_order) > 2 else None
    ax4 = axis_order[3] if len(axis_order) > 3 else None

    def col(row, name):
        return int(float(row[name]))

    def pct_tpp(row):
        gflops = float(row[gflops_key])
        threads = col(row, "threads")
        return gflops / (args.tpp_per_core * threads) * 100

    ax1_values = sorted({col(r, ax1) for r in rows})
    ax2_values = sorted({col(r, ax2) for r in rows}) if ax2 else [None]
    ax3_values = sorted({col(r, ax3) for r in rows}) if ax3 else [None]
    ax4_values = sorted({col(r, ax4) for r in rows}) if ax4 else [None]

    if len(ax2_values) > len(CATEGORICAL_PALETTE):
        print(f"warning: {ax2} has {len(ax2_values)} distinct values, more "
              f"than the {len(CATEGORICAL_PALETTE)}-color validated "
              f"palette -- colors will repeat", file=sys.stderr)
    ax2_color = {v: CATEGORICAL_PALETTE[i % len(CATEGORICAL_PALETTE)]
                 for i, v in enumerate(ax2_values)}

    index = {}
    for r in rows:
        key = (col(r, ax1), col(r, ax2) if ax2 else None,
               col(r, ax3) if ax3 else None, col(r, ax4) if ax4 else None)
        index[key] = r

    fmt_hdr = wb.add_format({"bold": True, "bg_color": "#DCE6F1"})
    fmt_bold = wb.add_format({"bold": True})
    fmt_pct = wb.add_format({"num_format": "0.0"})
    note_fmt = wb.add_format({"font_color": MUTED, "italic": True, "font_size": 9})

    cfg = wb.add_worksheet("Config")
    cfg.set_column(0, 0, 22)
    cfg.set_column(1, 1, 40)
    cfg.write(0, 0, "Parameter", fmt_hdr)
    cfg.write(0, 1, "Value", fmt_hdr)
    cfg.write(1, 0, "TPP per core (GFLOPs/s)")
    cfg.write_number(1, 1, args.tpp_per_core)
    wb.define_name("TPP_PER_CORE", "=Config!$B$2")
    cfg.write(2, 0, "Stat used")
    cfg.write(2, 1, args.stat)
    cfg.write(3, 0, "Axis order")
    cfg.write(3, 1, ",".join(axis_order))
    row_i = 5
    cfg.write(row_i, 0, "Source csv", fmt_hdr)
    row_i += 1
    cfg.write(row_i, 0, csv_path)
    row_i += 1
    for k, v in preamble.items():
        cfg.write(row_i, 0, f"  {k}")
        cfg.write(row_i, 1, v)
        row_i += 1

    data_name = "Data"
    ws = wb.add_worksheet(data_name)
    data_cols = ["threads"] + [a for a in axis_order if a != "threads"] + \
        [args.stat, gflops_key, "pct_tpp"]
    for c, name in enumerate(data_cols):
        ws.write(0, c, name, fmt_hdr)
    data_row_of = {}
    gflops_of = {}
    GFLOPS_COL = data_cols.index(gflops_key)
    for r_i, r in enumerate(rows):
        rr = r_i + 1
        for c, name in enumerate(data_cols[:-1]):
            ws.write_number(rr, c, float(r[name]) if name != "threads" and
                             name not in axis_order else int(float(r[name])))
        pct = pct_tpp(r)
        gcell = qref(data_name, rr, GFLOPS_COL)
        tcell = qref(data_name, rr, data_cols.index("threads"))
        ws.write_formula(rr, len(data_cols) - 1,
                          f"={gcell}/(TPP_PER_CORE*{tcell})*100", fmt_pct, pct)
        key = (col(r, ax1), col(r, ax2) if ax2 else None,
               col(r, ax3) if ax3 else None, col(r, ax4) if ax4 else None)
        data_row_of[key] = rr
        gflops_of[key] = float(r[gflops_key])
    PCT_COL = len(data_cols) - 1

    pct_of = {}
    for r in rows:
        key = (col(r, ax1), col(r, ax2) if ax2 else None,
               col(r, ax3) if ax3 else None, col(r, ax4) if ax4 else None)
        pct_of[key] = pct_tpp(r)

    panels = wb.add_worksheet("Panels")
    panels.hide_gridlines(2)
    panels.set_column(1, 60, 13)
    title = args.title or preamble.get("variant", "Performance")
    panels.merge_range(0, 0, 0, 20, f"{title}: %TPP vs. {ax1}"
                        + (f", by {ax2}" if ax2 else "")
                        + (f", faceted by {ax3}" if ax3 else "")
                        + (f" x {ax4}" if ax4 else ""),
                        wb.add_format({"bold": True, "font_size": 14}))

    CAP_THRESHOLD_PCT = 67.0
    PANEL_TABLE_ROW0 = 3
    N1 = len(ax1_values)
    N2 = len(ax2_values)
    table_height = N1 + 2
    chart_height_rows = 18
    PANEL_COL_STRIDE = max(N2 + 2, 6) + 2
    PANEL_ROW_STRIDE = table_height + chart_height_rows + 3

    for a4_i, a4v in enumerate(ax4_values):
        for a3_i, a3v in enumerate(ax3_values):
            top = PANEL_TABLE_ROW0 + a4_i * PANEL_ROW_STRIDE
            left = 1 + a3_i * PANEL_COL_STRIDE

            panel_title = ", ".join(
                f"{name}={val}" for name, val in
                ((ax3, a3v), (ax4, a4v)) if val is not None) or title
            panels.write(top - 1, left, panel_title, fmt_bold)

            panels.write(top, left, ax1, fmt_hdr)
            for j, a2v in enumerate(ax2_values):
                panels.write(top, left + 1 + j,
                              f"{ax2}={a2v}" if ax2 else "value", fmt_hdr)

            panel_max_pct = 0.0
            for i_, a1v in enumerate(ax1_values):
                r = top + 1 + i_
                panels.write_number(r, left, a1v)
                for j, a2v in enumerate(ax2_values):
                    key = (a1v, a2v, a3v, a4v)
                    data_r = data_row_of.get(key)
                    if data_r is None:
                        panels.write_formula(r, left + 1 + j, "=NA()", fmt_pct)
                    else:
                        pct = pct_of[key]
                        panel_max_pct = max(panel_max_pct, pct)
                        panels.write_formula(
                            r, left + 1 + j,
                            f"={qref(data_name, data_r, PCT_COL)}",
                            fmt_pct, pct)

            cap_axis = panel_max_pct <= CAP_THRESHOLD_PCT
            axis_max = (panel_max_pct // 10 + 2) * 10 if cap_axis \
                else max(100, (panel_max_pct // 10 + 1) * 10)
            ref_col = None
            if not cap_axis:
                ref_col = left + 1 + N2
                panels.write(top, ref_col, "100% TPP", fmt_hdr)
                for i_ in range(N1):
                    panels.write_number(top + 1 + i_, ref_col, 100, fmt_pct)

            chart = wb.add_chart({"type": "column"})
            cats = ["Panels", top + 1, left, top + N1, left]
            for j, a2v in enumerate(ax2_values):
                key_for = lambda a1v: (a1v, a2v, a3v, a4v)  # noqa: E731
                custom_labels = []
                for a1v in ax1_values:
                    dr = data_row_of.get(key_for(a1v))
                    if dr is None:
                        custom_labels.append({"delete": True})
                    else:
                        custom_labels.append({"value": qref(data_name, dr, GFLOPS_COL)})
                series = {
                    "name": f"{ax2}={a2v}" if ax2 else title,
                    "categories": cats,
                    "values": ["Panels", top + 1, left + 1 + j, top + N1, left + 1 + j],
                    "fill": {"color": ax2_color[a2v]},
                    "border": {"none": True},
                    "gap": 150,
                    "overlap": -3,
                    "data_labels": {"custom": custom_labels, "num_format": "0"},
                }
                chart.add_series(series)
            if ref_col is not None:
                chart.add_series({
                    "name": "100% TPP",
                    "categories": cats,
                    "values": ["Panels", top + 1, ref_col, top + N1, ref_col],
                    "fill": {"color": "#888888"},
                })
            chart.set_title({"name": panel_title, "name_font": {"size": 11, "bold": True}})
            x_axis_name = ax1
            if cap_axis:
                x_axis_name += (f"\nNote: y-axis capped at {axis_max:.0f}%, "
                                 f"(tallest bar is {panel_max_pct:.1f}% of TPP)")
            chart.set_x_axis({"name": x_axis_name, "name_font": {"size": 9},
                                "num_font": {"size": 9, "color": MUTED},
                                "line": {"color": GRID}})
            chart.set_y_axis({"name": "%TPP", "name_font": {"size": 9},
                                "num_font": {"size": 9, "color": MUTED},
                                "min": 0, "max": axis_max,
                                "major_gridlines": {"visible": True, "line": {"color": GRID}}})
            if ax2 or ref_col is not None:
                chart.set_legend({"position": "bottom", "font": {"size": 9}})
            else:
                chart.set_legend({"none": True})
            chart.set_size({"width": 90 * max(N2, 1) + 220, "height": 320})
            chart.set_plotarea({"border": {"none": True}})
            chart.set_chartarea({"border": {"none": True}})
            panels.insert_chart(top + table_height, left, chart)

    if ax2 and len(ax2_values) > len(CATEGORICAL_PALETTE[:5]):
        panels.write(
            PANEL_TABLE_ROW0 - 2, 1,
            f"Note: {ax2} colors are assigned by sorted numeric value from "
            f"a fixed palette, not re-optimized for this data -- with "
            f"{len(ax2_values)} series, adjacent-pair colorblind safety "
            f"beyond the first few is not independently validated here.",
            note_fmt)

    panels.activate()
    return len(rows), axis_order


def main(argv=None):
    args = parse_args(sys.argv[1:] if argv is None else argv)

    axis_orders = []
    for path in args.csvs:
        pre = peek_preamble(path)
        raw = pre.get("axis_order", "threads")
        axis_orders.append(tuple(a for a in raw.split(",") if a) or ("threads",))

    is_classic = all(a == ("threads",) for a in axis_orders)

    if not is_classic:
        if len(set(axis_orders)) > 1:
            raise SystemExit(
                "error: all --csv runs must share the same axis_order to "
                f"be plotted together; got {set(axis_orders)}")
        if len(args.csvs) > 1:
            raise SystemExit(
                "error: multiple --csv with a multi-axis (non-threads) "
                "axis_order isn't supported yet -- comparing runs here "
                "would need \"which csv\" as another axis; pass one --csv")

    out_path = args.out
    if out_path is None:
        out_path = derive_out_path(args.csvs, args.topic)
        if out_path is None:
            raise SystemExit(
                "error: --out omitted and it can't be derived automatically "
                "-- not every --csv is under a recognized NN-VARIANT "
                "directory (or they don't share a common parent); pass "
                "--out explicitly")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    wb = xlsxwriter.Workbook(out_path)
    if is_classic:
        n_runs, all_threads = build_classic_workbook(wb, args, args.csvs)
        wb.close()
        fix_axis_title_linebreaks(out_path)
        print(f"wrote {out_path}: {n_runs} run(s), threads={all_threads}")
    else:
        n_rows, axis_order = build_multiaxis_workbook(wb, args, args.csvs[0])
        wb.close()
        print(f"wrote {out_path}: {n_rows} row(s), axes={axis_order}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Turn one or more raw per-rep timing csv blocks (as emitted by
PolyMult.time[-par], possibly several concatenated by sweep.sh's --tune
axis loop) into one StudentPolyMult results csv: a preamble of parameters
constant for this sweep, then one row per unique (threads, *swept-tune
-value) combination.

Preamble: plain two-column csv rows (name,value), terminated by the row
whose first field is literally "threads" -- that row is the data table's
own header, everything after is data. No fixed preamble length, no blank
line needed: a new constant parameter is one more preamble line, nothing
else changes.

Tune columns (any raw-csv column beyond variant,dA,dB,threads,
build_params,rep,seconds,gflops -- one per --tune key the timing binary
was given, per time_main.c) are classified automatically from the data,
not from a fixed set of CLI flags: a column with exactly one distinct
value across every raw row is a CONSTANT (written to the preamble, same
as an --extra field); a column with more than one distinct value is a
SWEPT axis (becomes part of the grouping key and its own output column).
This replaces the old fixed --sched/--block-size/--leaf-size/
--task-threshold flags, which named only the tuning knobs that existed
before the generic bpm_tune_t redesign -- a new tunable key needs no
change here.

Data table columns: threads, [swept tune columns...], rep1..N, median,
mean_wo_outliers, gflops_median, gflops_mean_wo_outliers. GFLOPs/s is
computed once per aggregate stat, never per rep, using dA/dB (degrees, so
a degree-d polynomial has d+1 coefficients): flops = 2*(dA+1)*(dB+1).

Outlier rule: matches BestPolyMult's existing tools/collect_results.py --
a repetition more than 2x its own group's fastest rep is excluded from
median/mean_wo_outliers (ratio-to-group-min, ratio=2.0). This is the
established, already-validated production rule; it supersedes an earlier,
unvalidated "drop exactly one slowest rep" phrasing that only ever existed
as draft text in PlottingScripts/Specs.md.
"""
import argparse
import csv
import statistics
import sys

OUTLIER_RATIO = 2.0
CORE_COLUMNS = {"variant", "dA", "dB", "threads", "build_params", "rep",
                 "seconds", "gflops"}


def read_raw(path):
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        raise SystemExit(f"error: {path}: no data rows")
    return rows


def tune_columns(rows):
    """Raw-csv columns beyond the fixed core set, in the order they first
    appear in the header (which is the order sweep.sh gave --tune flags to
    the binary: fixed values first, then ranged ones in axis order)."""
    if not rows:
        return []
    seen = []
    for k in rows[0].keys():
        if k not in CORE_COLUMNS and k not in seen:
            seen.append(k)
    return seen


def classify_tune_columns(rows, columns):
    """Splits tune columns into (constants: {col: value}, swept: [col,
    ...]) by counting each column's distinct values across every raw row."""
    constants = {}
    swept = []
    for col in columns:
        values = {r[col] for r in rows}
        if len(values) <= 1:
            constants[col] = next(iter(values)) if values else ""
        else:
            swept.append(col)
    return constants, swept


def group_key(row, swept_cols):
    return (int(float(row["threads"])),) + tuple(row[c] for c in swept_cols)


def group_rows(rows, swept_cols):
    groups = {}
    for r in rows:
        groups.setdefault(group_key(r, swept_cols), []).append(float(r["seconds"]))
    return groups


def included_reps(seconds_list):
    fastest = min(seconds_list)
    limit = fastest * OUTLIER_RATIO
    return [s for s in seconds_list if s <= limit]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw-csv", required=True,
                     help="raw per-rep csv from PolyMult.time[-par] "
                          "(sweep.sh may concatenate several combos' "
                          "output into one file before calling this)")
    ap.add_argument("--variant", required=True)
    ap.add_argument("--dA", required=True, type=int)
    ap.add_argument("--dB", required=True, type=int)
    ap.add_argument("--axis-order", default=None,
                     help="comma-separated swept-axis names in x-axis, "
                          "series, facet-column, facet-row order (e.g. "
                          "block_size,chunk_size); written verbatim to "
                          "the preamble for plot.py. Omit for a plain "
                          "single-configuration sweep.")
    ap.add_argument("--seq-time", default=None, type=float,
                     help="T(1), the sequential baseline (seconds); "
                          "supplied by the caller, never discovered here")
    ap.add_argument("--seq-source", default=None,
                     help="provenance note/path for --seq-time")
    ap.add_argument("--extra", action="append", default=[], metavar="KEY=VALUE",
                     help="additional preamble field for something not "
                          "covered by a --tune key (e.g. --extra "
                          "gate_status=PASSED); repeatable")
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)

    if args.seq_source and args.seq_time is None:
        ap.error("--seq-source given without --seq-time")

    extra_fields = []
    for item in args.extra:
        if "=" not in item:
            ap.error(f"--extra {item!r}: expected KEY=VALUE")
        k, v = item.split("=", 1)
        extra_fields.append((k, v))

    raw_rows = read_raw(args.raw_csv)
    columns = tune_columns(raw_rows)
    constants, swept_cols = classify_tune_columns(raw_rows, columns)

    groups = group_rows(raw_rows, swept_cols)
    keys_sorted = sorted(groups.keys())

    flop_count = 2.0 * (args.dA + 1) * (args.dB + 1)

    table_rows = []
    max_reps = 0
    for key in keys_sorted:
        secs = groups[key]
        included = included_reps(secs)
        median_s = statistics.median(included)
        mean_wo_s = statistics.fmean(included)
        gflops_median = flop_count / median_s / 1e9
        gflops_mean_wo = flop_count / mean_wo_s / 1e9
        table_rows.append({
            "key": key, "reps": secs,
            "median": median_s, "mean_wo_outliers": mean_wo_s,
            "gflops_median": gflops_median,
            "gflops_mean_wo_outliers": gflops_mean_wo,
        })
        max_reps = max(max_reps, len(secs))

    with open(args.out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["variant", args.variant])
        w.writerow(["dA", args.dA])
        w.writerow(["dB", args.dB])
        for k, v in constants.items():
            w.writerow([k, v])
        for k, v in extra_fields:
            w.writerow([k, v])
        if args.axis_order:
            w.writerow(["axis_order", args.axis_order])
        if args.seq_time is not None:
            w.writerow(["seq_time", args.seq_time])
            if args.seq_source:
                w.writerow(["seq_time_source", args.seq_source])

        header = ["threads"] + swept_cols + [f"rep{i+1}" for i in range(max_reps)] + \
            ["median", "mean_wo_outliers", "gflops_median", "gflops_mean_wo_outliers"]
        w.writerow(header)

        for row in table_rows:
            reps = row["reps"] + [""] * (max_reps - len(row["reps"]))
            w.writerow(list(row["key"]) + reps + [
                row["median"], row["mean_wo_outliers"],
                row["gflops_median"], row["gflops_mean_wo_outliers"],
            ])

    print(f"wrote {args.out}: {len(keys_sorted)} row(s)"
          + (f", swept: {swept_cols}" if swept_cols else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())

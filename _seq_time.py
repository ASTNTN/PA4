#!/usr/bin/env python3
"""Sidecar helper for T(seq) carry-through, invoked by sweep.sh only --
not meant to be run directly. See EXPERIMENTS.md.

T(seq) is schedule-independent (a compile-time knob like SCHED has no
effect on a build with no -fopenmp) but NOT problem-size-independent --
different (dA, dB) means different work, so the sidecar is keyed by the
exact (dA, dB) pair, not just the variant. A sweep at a size with no
matching entry gets no seq_time at all (same as no sidecar existing),
never a stale value from a different size.

record: from a --record-seq call's own raw csv, compute the threads=1
median (same outlier rule as collect.py) and store it under this call's
(dA, dB) key in the variant's own seq_time.json sidecar -- non
-destructive, every other recorded size is left alone. Use this when
sweeping a (dA, dB) that has never been recorded before. Every variant
records its own baseline this way -- a *P<n> parallel variant is not an
exception: its own --record-seq measures its own kernel_multiply built
without -fopenmp, whatever loop structure that variant actually uses.

renew: same measurement, but first wipes every existing entry, keeping
only the one just measured. Use this -- and only this -- when the
variant's sequential kernel source has changed, since every previously
recorded size (not just the current one) is now stale.

resolve: given a later sweep's raw csv, its (dA, dB), and its variant
directory, the baseline is min() of up to three candidates, since a
*P<n> variant may restructure its *Q ancestor's loop nest (not just
annotate it) -- so no single one of these is trustworthy alone:
  - "own": this variant's own recorded seq_time.json entry.
  - "base": for a *P<n> variant only, its *Q ancestor's own recorded
    seq_time.json entry (e.g. 03-BKP2's ancestor is 03-BKQ), derived
    from the directory name -- not applicable to a *Q variant itself,
    where base and own are the same thing.
  - "par@1": this sweep's own t=1 row, when present.
Prints nothing if none of the three are available for this size. This
makes Speedup an approximation, not a precisely cross-variant-fair
number -- Performance (%TPP) is the metric for comparing across
variants; Speedup is only ever meant to judge one variant's own
scaling against itself.
"""
import json
import re
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from collect import read_raw, included_reps  # noqa: E402

# Matches a *P<n> variant directory name, e.g. "03-BKP2" -> ("03-", "BK"),
# "OPP1" -> ("", "OP"). Does not match a *Q variant, or a name like
# "OPPreductionOverhead" that merely starts with the same letters.
_P_VARIANT_RE = re.compile(r'^(\d+-)?([A-Z]+)P\d+$')


def size_key(da, db):
    return f"{da}x{db}"


def group_by_threads(rows):
    """Groups purely by threads, ignoring any other (tune) column. Only
    ever called from a context sweep.sh has already restricted to at most
    a --threads axis (NEEDS_SEQ) -- see sweep.sh's own axis analysis --
    so there is no swept tune column to also group by here."""
    groups = {}
    for r in rows:
        t = int(float(r["threads"]))
        groups.setdefault(t, []).append(float(r["seconds"]))
    return groups


def median_at_threads_1(raw_csv):
    groups = group_by_threads(read_raw(raw_csv))
    if 1 not in groups:
        return None
    return statistics.median(included_reps(groups[1]))


def load_sidecar(sidecar_path):
    if not Path(sidecar_path).exists():
        return {"entries": {}}
    with open(sidecar_path) as f:
        data = json.load(f)
    data.setdefault("entries", {})
    return data


def base_variant_dir(variant_dir):
    """The *Q ancestor directory for a *P<n> variant (e.g. 03-BKP2 ->
    03-BKQ), or None if variant_dir doesn't match that naming pattern
    (already a *Q variant, or something else entirely, e.g. a
    diagnostic-only directory)."""
    p = Path(variant_dir)
    m = _P_VARIANT_RE.match(p.name)
    if not m:
        return None
    prefix, code = m.group(1) or "", m.group(2)
    return p.parent / f"{prefix}{code}Q"


def _measure_and_write(raw_csv, sidecar_path, out_csv, da, db, entries, flag_name):
    m = median_at_threads_1(raw_csv)
    if m is None:
        sys.exit(f"error: {flag_name} requires a threads=1 row, none found")
    entries[size_key(da, db)] = {
        "dA": int(da), "dB": int(db), "seq_time": m,
        "seq_time_source": f"recorded via {flag_name} ({out_csv})",
    }
    data = {"entries": entries}
    Path(sidecar_path).parent.mkdir(parents=True, exist_ok=True)
    with open(sidecar_path, "w") as f:
        json.dump(data, f, indent=2)
    print(m)


def cmd_record(raw_csv, sidecar_path, out_csv, da, db):
    # Non-destructive: adds/updates only this (dA, dB), every other
    # recorded size is left alone. Use for a new problem size.
    entries = load_sidecar(sidecar_path)["entries"]
    _measure_and_write(raw_csv, sidecar_path, out_csv, da, db, entries,
                        "--record-seq")


def cmd_renew(raw_csv, sidecar_path, out_csv, da, db):
    # Destructive: wipes every existing entry first. Use only when the
    # sequential kernel source changed -- every size's old entry, not just
    # this one, is now stale.
    old = load_sidecar(sidecar_path)["entries"]
    wiped = [k for k in old if k != size_key(da, db)]
    if wiped:
        print(f"warning: --renew-seq wiped {len(wiped)} other recorded "
              f"size(s), now stale: {', '.join(sorted(wiped))} -- "
              f"re-run --record-seq for each before sweeping it again",
              file=sys.stderr)
    _measure_and_write(raw_csv, sidecar_path, out_csv, da, db, {},
                        "--renew-seq")


def cmd_resolve(raw_csv, variant_dir, da, db):
    variant_dir = Path(variant_dir)
    key = size_key(da, db)

    candidates = []

    own_sidecar = variant_dir / "results" / "seq_time.json"
    own_entry = load_sidecar(own_sidecar)["entries"].get(key)
    if own_entry is not None:
        candidates.append((own_entry["seq_time"],
                            f"own: {own_entry['seq_time_source']}"))

    base_dir = base_variant_dir(variant_dir)
    if base_dir is not None:
        base_sidecar = base_dir / "results" / "seq_time.json"
        base_entry = load_sidecar(base_sidecar)["entries"].get(key)
        if base_entry is not None:
            candidates.append((base_entry["seq_time"],
                                f"base {base_dir.name}: {base_entry['seq_time_source']}"))

    par1 = median_at_threads_1(raw_csv)
    if par1 is not None:
        candidates.append((par1, f"this sweep's own t=1 median ({par1:.9f}s)"))

    if not candidates:
        return  # nothing recorded anywhere for this size; nothing to resolve

    chosen, src = min(candidates, key=lambda c: c[0])
    print(chosen)
    print(f"min of {len(candidates)}: {src}")


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "record":
        cmd_record(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
    elif mode == "renew":
        cmd_renew(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
    elif mode == "resolve":
        cmd_resolve(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    else:
        sys.exit(f"unknown mode {mode}")

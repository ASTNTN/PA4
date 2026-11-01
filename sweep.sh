#!/bin/bash
# sweep.sh -- run one sweep for a StudentPolyMult variant and write one
# results csv (preamble of constant parameters, then one row per swept
# configuration) via collect.py.
#
# Every parallel invocation -- gate and timed run alike -- is bound (see
# _gate.sh): a parallel binary is never invoked bare.
#
# A compile-time knob (schedule clause, unroll factor, ...) needs its own
# rebuild per value -- pass it via one or more --make-var KEY=VALUE, forwarded
# to `make` before the gate/timed run. This script does not sweep such a knob
# itself: call it once per value, each to its own output.
#
# Multi-axis sweeps: --threads and --tune both accept a range (enumeration
# 1,2,4 / stride 2:16:2 / powers of 2 1...16, or a bare single value, which
# is just a length-1 range). Whichever of --threads/--tune is given FIRST
# on the command line, among those whose value actually expands to more
# than one value, is axis 1 (the eventual chart's x-axis); the next such
# flag is axis 2 (series/cluster color); a 3rd and 4th are facet-panel
# columns/rows. At most 4 axes total. A --threads range is always handled
# by the timing binary's own internal loop (one invocation covers every
# thread count); a --tune range is looped IN THIS SCRIPT, one binary
# invocation per value (no rebuild between them -- that's what makes
# --tune different from --make-var), and every combination's raw output is
# concatenated into one csv before collect.py sees it. See EXPERIMENTS.md's
# "Multi-Axis Sweeps" section for the full rule, including why T(seq) is
# only attempted for a plain single-configuration or classic thread-only
# sweep (see the T(seq) section below).
#
# This never launches its own sequential baseline run to fill in a missing
# --seq-time on its own initiative.
#
# --allow-gate-failure lets a deliberately-incorrect build (e.g. a diagnostic
# nowait) still be timed after a failing gate, instead of the normal hard
# refusal -- the csv lands under results/diagnostic/ and records
# gate_status=PASSED|FAILED in its preamble.
#
# T(seq) carry-through: --record-seq (a --threads 1 call, no --make-var, no
# --tune) writes the measured value to <variant-dir>/results/seq_time.json
# -- the one explicit, deliberate measurement that establishes it. A later
# plain or classic-thread-sweep sweep.sh call for that variant then picks
# it up automatically (combined with that call's own t=1 row via min(), per
# the speedup-baseline rule) unless --seq-time overrides it. A sweep with a
# second+ swept axis is Performance-only and never attempts this at all --
# see EXPERIMENTS.md.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_gate.sh
source "$SCRIPT_DIR/_gate.sh"

usage() {
    cat <<'EOF'
Usage: sweep.sh --variant-dir DIR --dA N --dB N --threads RANGE --reps N
                 (--out FILE.csv | --name NAME)
                 [--make-var KEY=VALUE ...]
                 [--tune KEY=RANGE ...]
                 [--extra KEY=VALUE ...]
                 [--seq-time SECONDS [--seq-source TEXT] | --record-seq | --renew-seq]
                 [--allow-gate-failure]

Rebuilds the variant (with any --make-var overrides), runs its correctness
gate under the project's bound-thread protocol, runs the timed sweep(s),
and writes one csv.

A sweep's raw data belongs to its variant: with --name (not --out), the csv
is written to <variant-dir>/results/<name>.csv automatically. --out is an
explicit override for a different location. Recommended --name/--out stem:
a dotted date plus a same-day sequence number, e.g.
2026.09.14.001_5thr or 2026.09.14.002_block_size_sweep.

Required:
  --variant-dir DIR      variant directory containing a Makefile
  --dA N                 degree of polynomial A
  --dB N                 degree of polynomial B
  --threads RANGE        enumeration (1,2,4), stride (2:16:2), powers of 2
                          (1...16), or a bare single value; see "Multi-Axis
                          Sweeps" above for when this becomes an axis
  --reps N                repetitions per timed configuration
  --name NAME             output filename stem; writes to
                          <variant-dir>/results/<name>.csv
  --out FILE.csv          explicit output csv path (overrides --name)

Optional:
  --make-var KEY=VALUE    forwarded to `make` before building, e.g.
                           --make-var SCHED=dynamic,8 ; repeatable. One
                           rebuild covers this entire call -- to compare
                           values, call sweep.sh once per value.
  --tune KEY=RANGE        runtime tuning knob, forwarded to the timing
                           binary's own --tune KEY=VALUE; repeatable. A
                           bare single value ("--tune block_size=64") is
                           forwarded unchanged to every invocation this
                           call makes, exactly as before. A real range
                           ("--tune block_size=32:512:2") loops THIS
                           SCRIPT once per value -- no rebuild needed,
                           that's the difference from --make-var -- and
                           becomes a swept axis (see "Multi-Axis Sweeps").
                           Cannot be combined with --record-seq/--renew-seq
                           (T(seq) must reflect the untuned default, not
                           one specific tuning config).
  --extra KEY=VALUE       recorded verbatim in the output csv's preamble
                           (e.g. --extra unroll=4, for a knob held constant
                           this call); repeatable; passed through to
                           collect.py

Sequential baseline (needed for plot.py to compute speedup; only attempted
for a plain single-configuration call or a classic --threads-only sweep --
see "Multi-Axis Sweeps" above):
  --seq-time SECONDS       T(1), the sequential baseline execution time.
                            Overrides any recorded seq_time.json. sweep.sh
                            never measures this on its own initiative.
  --seq-source TEXT         provenance note for --seq-time.
  --record-seq              this call IS the sequential-baseline
                            measurement for a (dA, dB) never recorded
                            before: requires --threads 1 and no
                            --make-var/--tune, adds/updates just this
                            size's entry in
                            <variant-dir>/results/seq_time.json -- every
                            other recorded size is left alone. Every later
                            sweep.sh call at this same size picks it up
                            automatically.
  --renew-seq               same measurement, same requirements, but
                            wipes every other recorded size first, keeping
                            only this one. Use this -- and only this --
                            when the variant's sequential kernel source
                            changed: every previously recorded size, not
                            just the current one, is now stale.

If neither --seq-time, --record-seq, nor --renew-seq is given, and this
call has at most one swept axis which (if present) is --threads, a
matching entry in seq_time.json (same variant, same dA/dB) is used
automatically, combined with this call's own t=1 row via min() when the
thread range includes 1. A sweep at a (dA, dB) with no matching entry
gets no baseline at all. A call with a second+ swept axis skips this
entirely (Performance-only; see EXPERIMENTS.md).

  --allow-gate-failure      time the build even if its correctness gate
                            fails -- for deliberately-incorrect diagnostic
                            runs (e.g. a nowait that should race). The gate
                            still runs and its outcome is recorded
                            (--extra gate_status=PASSED|FAILED); the csv
                            lands under <variant-dir>/results/diagnostic/
                            instead of results/, and this can never be
                            combined with --record-seq/--renew-seq (a
                            diagnostic build must never become the trusted
                            sequential baseline).

  -h, --help                this message
EOF
}

VARIANT_DIR=""
DA=""
DB=""
THREADS=""
REPS=""
OUT=""
NAME=""
SEQ_TIME=""
SEQ_SOURCE=""
RECORD_SEQ=0
RENEW_SEQ=0
ALLOW_GATE_FAILURE=0
MAKE_VARS=()
TUNE_VARS=()   # every --tune KEY=VALUE_OR_RANGE, in command-line order
EXTRAS=()
AXIS_SEQ=()    # "threads" or "tune:N" (N = index into TUNE_VARS), in
               # command-line order, for every --threads/--tune seen

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)          usage; exit 0 ;;
        --variant-dir)       VARIANT_DIR="$2"; shift 2 ;;
        --dA)                DA="$2"; shift 2 ;;
        --dB)                DB="$2"; shift 2 ;;
        --threads)           THREADS="$2"; AXIS_SEQ+=("threads"); shift 2 ;;
        --reps)              REPS="$2"; shift 2 ;;
        --out)               OUT="$2"; shift 2 ;;
        --name)               NAME="$2"; shift 2 ;;
        --make-var)           MAKE_VARS+=("$2"); shift 2 ;;
        --tune)
            TUNE_IDX=${#TUNE_VARS[@]}
            TUNE_VARS+=("$2")
            AXIS_SEQ+=("tune:$TUNE_IDX")
            shift 2 ;;
        --extra)              EXTRAS+=("$2"); shift 2 ;;
        --seq-time)          SEQ_TIME="$2"; shift 2 ;;
        --seq-source)        SEQ_SOURCE="$2"; shift 2 ;;
        --record-seq)         RECORD_SEQ=1; shift ;;
        --renew-seq)           RENEW_SEQ=1; shift ;;
        --allow-gate-failure)  ALLOW_GATE_FAILURE=1; shift ;;
        *) echo "Unrecognized argument: $1" >&2; usage; exit 1 ;;
    esac
done

for req in VARIANT_DIR DA DB THREADS REPS; do
    if [ -z "${!req}" ]; then
        echo "Missing required argument: --$(echo "$req" | tr 'A-Z' 'a-z')" >&2
        exit 1
    fi
done
if [ -z "$OUT" ] && [ -z "$NAME" ]; then
    echo "Missing required argument: --out or --name" >&2
    exit 1
fi
if [ -n "$SEQ_SOURCE" ] && [ -z "$SEQ_TIME" ]; then
    echo "--seq-source given without --seq-time" >&2
    exit 1
fi
if [ "$RECORD_SEQ" -eq 1 ] && [ "$RENEW_SEQ" -eq 1 ]; then
    echo "--record-seq and --renew-seq are mutually exclusive" >&2
    exit 1
fi
if [ "$ALLOW_GATE_FAILURE" -eq 1 ] && { [ "$RECORD_SEQ" -eq 1 ] || [ "$RENEW_SEQ" -eq 1 ]; }; then
    echo "--allow-gate-failure cannot be combined with --record-seq/--renew-seq (a diagnostic build must never become the trusted sequential baseline)" >&2
    exit 1
fi
if [ "$RECORD_SEQ" -eq 1 ] || [ "$RENEW_SEQ" -eq 1 ]; then
    FLAG_NAME="--record-seq"
    [ "$RENEW_SEQ" -eq 1 ] && FLAG_NAME="--renew-seq"
    if [ "$THREADS" != "1" ]; then
        echo "$FLAG_NAME requires --threads 1 (it must be the true sequential binary)" >&2
        exit 1
    fi
    if [ ${#MAKE_VARS[@]} -ne 0 ]; then
        echo "$FLAG_NAME cannot be combined with --make-var (T(seq) must be schedule-independent)" >&2
        exit 1
    fi
    if [ ${#TUNE_VARS[@]} -ne 0 ]; then
        echo "$FLAG_NAME cannot be combined with --tune (T(seq) must reflect the untuned default, not one specific tuning config)" >&2
        exit 1
    fi
    if [ -n "$SEQ_TIME" ]; then
        echo "$FLAG_NAME cannot be combined with --seq-time" >&2
        exit 1
    fi
fi

# -- Axis analysis: expand --threads and every --tune value, decide which
# flags (in command-line order) are actually swept axes (expand to more
# than one value) versus a fixed constant forwarded to every invocation. --

mapfile -t THREADS_VALUES < <(python3 "$SCRIPT_DIR/_range.py" expand "$THREADS") || exit 1

declare -a TUNE_KEYS TUNE_VALUES_STR TUNE_N
for i in "${!TUNE_VARS[@]}"; do
    kv="${TUNE_VARS[$i]}"
    if [[ "$kv" != *=* ]]; then
        echo "--tune expects KEY=VALUE (got $kv)" >&2
        exit 1
    fi
    TUNE_KEYS[$i]="${kv%%=*}"
    TUNE_VALUES_STR[$i]="${kv#*=}"
    mapfile -t _expanded < <(python3 "$SCRIPT_DIR/_range.py" expand "${TUNE_VALUES_STR[$i]}") || exit 1
    TUNE_N[$i]="${#_expanded[@]}"
done

AXIS_ORDER=()
for tok in "${AXIS_SEQ[@]}"; do
    if [ "$tok" = "threads" ]; then
        [ "${#THREADS_VALUES[@]}" -gt 1 ] && AXIS_ORDER+=("threads")
    else
        i="${tok#tune:}"
        [ "${TUNE_N[$i]}" -gt 1 ] && AXIS_ORDER+=("$tok")
    fi
done

if [ "${#AXIS_ORDER[@]}" -gt 4 ]; then
    AXIS_NAMES_ERR=()
    for tok in "${AXIS_ORDER[@]}"; do
        if [ "$tok" = "threads" ]; then
            AXIS_NAMES_ERR+=("threads")
        else
            AXIS_NAMES_ERR+=("${TUNE_KEYS[${tok#tune:}]}")
        fi
    done
    echo "error: at most 4 swept axes (x-axis, series, and 2 facet-panel dimensions); got ${#AXIS_ORDER[@]}: ${AXIS_NAMES_ERR[*]}" >&2
    exit 1
fi

# T(seq)/speedup is only meaningful, and only attempted, for a plain
# single-configuration call or a classic threads-only sweep -- a second+
# swept axis (even if --threads is one of them) would need a T(seq)
# baseline PER combination of the other axis/axes, which this script does
# not yet compute; rather than silently blend different configurations'
# t=1 rows together into one misleading number, such a call is always
# Performance-only. See EXPERIMENTS.md.
NEEDS_SEQ=0
if [ "${#AXIS_ORDER[@]}" -eq 0 ] || { [ "${#AXIS_ORDER[@]}" -eq 1 ] && [ "${AXIS_ORDER[0]}" = "threads" ]; }; then
    NEEDS_SEQ=1
fi

RANGED_TUNE_IDX=()
for tok in "${AXIS_ORDER[@]}"; do
    [ "$tok" = "threads" ] && continue
    RANGED_TUNE_IDX+=("${tok#tune:}")
done

FIXED_TUNE_IDX=()
for i in "${!TUNE_VARS[@]}"; do
    is_ranged=0
    for j in "${RANGED_TUNE_IDX[@]:-}"; do
        [ "$i" = "$j" ] && is_ranged=1 && break
    done
    [ "$is_ranged" -eq 0 ] && FIXED_TUNE_IDX+=("$i")
done

COMBOS=("")
if [ "${#RANGED_TUNE_IDX[@]}" -gt 0 ]; then
    RANGES_FOR_CARTESIAN=()
    for i in "${RANGED_TUNE_IDX[@]}"; do
        RANGES_FOR_CARTESIAN+=("${TUNE_VALUES_STR[$i]}")
    done
    mapfile -t COMBOS < <(python3 "$SCRIPT_DIR/_range.py" cartesian "${RANGES_FOR_CARTESIAN[@]}") || exit 1
fi

VARIANT_DIR="$(cd "$VARIANT_DIR" && pwd)"
VARIANT="$(basename "$VARIANT_DIR" | sed 's/^[0-9-]*//')"
SEQ_TIME_JSON="$VARIANT_DIR/results/seq_time.json"

if [ -z "$OUT" ]; then
    if [ "$ALLOW_GATE_FAILURE" -eq 1 ]; then
        mkdir -p "$VARIANT_DIR/results/diagnostic"
        OUT="$VARIANT_DIR/results/diagnostic/$NAME.csv"
    else
        mkdir -p "$VARIANT_DIR/results"
        OUT="$VARIANT_DIR/results/$NAME.csv"
    fi
fi

bpm_build "$VARIANT_DIR" "${MAKE_VARS[@]}" || { echo "Build failed"; exit 1; }

USE_PAR=0
if [ "$THREADS" != "1" ]; then
    USE_PAR=1
fi

GATE_STATUS="PASSED"
if [ "$ALLOW_GATE_FAILURE" -eq 1 ]; then
    bpm_gate_check "$VARIANT_DIR" || GATE_STATUS="FAILED"
    if [ "$USE_PAR" -eq 1 ]; then
        bpm_gate_check_par "$VARIANT_DIR" || GATE_STATUS="FAILED"
    fi
    if [ "$GATE_STATUS" = "FAILED" ]; then
        echo "== Gate FAILED -- proceeding anyway (--allow-gate-failure): this is a deliberately-diagnostic run, not a trusted measurement =="
    fi
else
    bpm_gate_check "$VARIANT_DIR" || { echo "Gate FAILED"; exit 1; }
    if [ "$USE_PAR" -eq 1 ]; then
        bpm_gate_check_par "$VARIANT_DIR" || { echo "Gate FAILED"; exit 1; }
    fi
fi

BINARY="$VARIANT_DIR/bin/PolyMult.time"
[ "$USE_PAR" -eq 1 ] && BINARY="$VARIANT_DIR/bin/PolyMult.time-par"
if [ ! -x "$BINARY" ]; then
    echo "Expected binary not found: $BINARY" >&2
    exit 1
fi

# -- Timed sweep: one binary invocation per Cartesian-product combination
# of the ranged --tune axes (a single, argument-less combination when
# there are none). --threads is always passed through unchanged -- when
# it's ranged, the binary loops over it internally in every invocation;
# when it's fixed, every invocation just uses that one value, as before.
# No rebuild between combinations. --

RAW_CSV="$(mktemp)"
FIRST=1
for combo in "${COMBOS[@]}"; do
    read -r -a combo_vals <<< "$combo"

    TIME_ARGS=(-dA "$DA" -dB "$DB" -t "$THREADS" -r "$REPS")
    for i in "${FIXED_TUNE_IDX[@]:-}"; do
        [ -n "$i" ] && TIME_ARGS+=(--tune "${TUNE_KEYS[$i]}=${TUNE_VALUES_STR[$i]}")
    done
    for k in "${!RANGED_TUNE_IDX[@]}"; do
        i="${RANGED_TUNE_IDX[$k]}"
        TIME_ARGS+=(--tune "${TUNE_KEYS[$i]}=${combo_vals[$k]}")
    done

    echo "== Timed sweep (bound): $BINARY ${TIME_ARGS[*]} =="
    ITER_CSV="$(mktemp)"
    if [ "$USE_PAR" -eq 1 ]; then
        OMP_PROC_BIND=close OMP_PLACES="$BPM_OMP_PLACES" taskset -c "$BPM_CORESET" "$BINARY" "${TIME_ARGS[@]}" > "$ITER_CSV"
    else
        taskset -c "$BPM_SEQ_CORE" "$BINARY" "${TIME_ARGS[@]}" > "$ITER_CSV"
    fi
    if [ $? -ne 0 ]; then
        echo "Timed run failed (combo: ${combo_vals[*]:-none})" >&2
        rm -f "$ITER_CSV" "$RAW_CSV"
        exit 1
    fi
    if [ "$FIRST" -eq 1 ]; then
        cat "$ITER_CSV" > "$RAW_CSV"
        FIRST=0
    else
        tail -n +2 "$ITER_CSV" >> "$RAW_CSV"
    fi
    rm -f "$ITER_CSV"
done

if [ "$RECORD_SEQ" -eq 1 ]; then
    echo "== Recording T(seq) to $SEQ_TIME_JSON (dA=$DA dB=$DB) =="
    SEQ_TIME="$(python3 "$SCRIPT_DIR/_seq_time.py" record "$RAW_CSV" "$SEQ_TIME_JSON" "$OUT" "$DA" "$DB")" \
        || { rm -f "$RAW_CSV"; exit 1; }
    SEQ_SOURCE="recorded via --record-seq ($OUT)"
elif [ "$RENEW_SEQ" -eq 1 ]; then
    echo "== Renewing T(seq) at $SEQ_TIME_JSON (dA=$DA dB=$DB, wiping other sizes) =="
    SEQ_TIME="$(python3 "$SCRIPT_DIR/_seq_time.py" renew "$RAW_CSV" "$SEQ_TIME_JSON" "$OUT" "$DA" "$DB")" \
        || { rm -f "$RAW_CSV"; exit 1; }
    SEQ_SOURCE="recorded via --renew-seq ($OUT)"
elif [ "$NEEDS_SEQ" -eq 1 ] && [ -z "$SEQ_TIME" ]; then
    echo "== Resolving T(seq) for $VARIANT_DIR (dA=$DA dB=$DB) =="
    RESOLVED="$(python3 "$SCRIPT_DIR/_seq_time.py" resolve "$RAW_CSV" "$VARIANT_DIR" "$DA" "$DB")" \
        || { rm -f "$RAW_CSV"; exit 1; }
    SEQ_TIME="$(printf '%s\n' "$RESOLVED" | sed -n '1p')"
    SEQ_SOURCE="$(printf '%s\n' "$RESOLVED" | sed -n '2p')"
    if [ -z "$SEQ_TIME" ]; then
        echo "   (no recorded T(seq) for dA=$DA dB=$DB -- run --record-seq here or in this variant's *Q ancestor first)"
    fi
fi

echo "== Collecting into $OUT =="
COLLECT_ARGS=(--raw-csv "$RAW_CSV" --variant "$VARIANT" --dA "$DA" --dB "$DB" --out "$OUT")
for kv in "${EXTRAS[@]}"; do
    COLLECT_ARGS+=(--extra "$kv")
done
if [ "$ALLOW_GATE_FAILURE" -eq 1 ]; then
    COLLECT_ARGS+=(--extra "gate_status=$GATE_STATUS")
fi
if [ "${#AXIS_ORDER[@]}" -gt 0 ]; then
    AXIS_NAMES=()
    for tok in "${AXIS_ORDER[@]}"; do
        if [ "$tok" = "threads" ]; then
            AXIS_NAMES+=("threads")
        else
            AXIS_NAMES+=("${TUNE_KEYS[${tok#tune:}]}")
        fi
    done
    AXIS_ORDER_CSV="$(IFS=,; echo "${AXIS_NAMES[*]}")"
    COLLECT_ARGS+=(--axis-order "$AXIS_ORDER_CSV")
fi
if [ -n "$SEQ_TIME" ]; then
    COLLECT_ARGS+=(--seq-time "$SEQ_TIME")
    [ -n "$SEQ_SOURCE" ] && COLLECT_ARGS+=(--seq-source "$SEQ_SOURCE")
fi

python3 "$SCRIPT_DIR/collect.py" "${COLLECT_ARGS[@]}"
STATUS=$?
rm -f "$RAW_CSV"
exit $STATUS

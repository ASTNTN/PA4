#!/bin/bash
# 04-DCP2 run script. Builds the variant and runs its correctness gate --
# nothing else. Use this any time to check a kernel compiles and passes
# correctness, without running a timed sweep at all.
#
# For a timed experiment, use ../sweep.sh instead -- it builds, gates,
# times, and writes the results csv in one call. sweep.sh does its own
# build+gate directly (via ../_gate.sh, the same shared logic this script
# uses) rather than calling this script.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_gate.sh
source "$SCRIPT_DIR/../_gate.sh"
VARIANT="DCP2"

usage() {
    cat <<EOF
Usage: $0 [-h|--help]

Builds $VARIANT and runs its correctness gate (oracle suite, sequential and
parallel binaries, both bound). Exits 0 if the gate passes, 1 otherwise.

For a timed experiment (thread sweep, GFLOPs/s, speedup/performance csv),
use ../sweep.sh.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        *) echo "Unrecognized argument: $1" >&2; usage; exit 1 ;;
    esac
done

bpm_build "$SCRIPT_DIR" || { echo "Build failed"; exit 1; }

GATE_STATUS=0
bpm_gate_check "$SCRIPT_DIR" || GATE_STATUS=1
bpm_gate_check_par "$SCRIPT_DIR" || GATE_STATUS=1

if [ "$GATE_STATUS" -ne 0 ]; then
    echo "Correctness gate FAILED"
    exit 1
fi

echo "Correctness gate PASSED"
exit 0

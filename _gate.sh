# _gate.sh -- shared build + correctness-gate + binding logic, sourced by
# both run.sh and sweep.sh so the two never drift out of sync. Not meant
# to be run directly. See EXPERIMENTS.md.
#
# Every parallel invocation -- gate and timed run alike -- is bound: a
# parallel binary is never invoked bare (an unbound team can stall for
# minutes on an asymmetric large test case, waiting on the OS scheduler
# instead of the correctness check itself).
#
# Defaults assume the department's fish machines: 16 E-cores (cpus 16-31),
# cluster-cyclic placement. Override any of BPM_CORESET / BPM_SEQ_CORE /
# BPM_OMP_PLACES in the environment to bind differently -- e.g. to try a
# P-core, a different cluster order, or a machine with a different layout
# -- sweep.sh and run.sh both pick up the override automatically.

: "${BPM_CORESET:=16-31}"
: "${BPM_SEQ_CORE:=16}"
# ${VAR:=default} does not brace-count literal { } in default -- it stops
# at the first unescaped }, silently truncating a value like this one. A
# plain conditional assignment avoids that parsing hazard entirely.
if [ -z "${BPM_OMP_PLACES:-}" ]; then
    BPM_OMP_PLACES='{16},{20},{24},{28},{17},{21},{25},{29},{18},{22},{26},{30},{19},{23},{27},{31}'
fi

# bpm_build VARIANT_DIR [MAKE_VAR ...]
bpm_build() {
    local dir="$1"; shift
    echo "== Build: make $* all =="
    ( cd "$dir" && make -s clean && make -s "$@" all )
}

# bpm_gate_check VARIANT_DIR -- sequential checking binary, pinned to one core.
bpm_gate_check() {
    local dir="$1"
    echo "== Correctness gate: PolyMult.check =="
    ( cd "$dir" && taskset -c "$BPM_SEQ_CORE" ./bin/PolyMult.check )
}

# bpm_gate_check_par VARIANT_DIR -- parallel checking binary, bound per the
# project's binding protocol. Never invoke ./bin/PolyMult.check-par directly.
bpm_gate_check_par() {
    local dir="$1"
    echo "== Correctness gate: PolyMult.check-par (bound: taskset -c $BPM_CORESET, OMP_PROC_BIND=close) =="
    ( cd "$dir" && OMP_PROC_BIND=close OMP_PLACES="$BPM_OMP_PLACES" taskset -c "$BPM_CORESET" ./bin/PolyMult.check-par )
}

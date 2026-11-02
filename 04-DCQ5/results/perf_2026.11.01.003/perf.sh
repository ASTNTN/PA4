#!/bin/bash
# Top-down / memory perf profile of a DCQ variant's timing binary, 1 thread,
# core 16, one run at a time. Usage: perf.sh <variant-dir> <outdir> <leaf_size>...
# Groups follow PA3 BKQ3.2 (G1-G4) plus G5 (DCQ3.4's extra events); every
# group also counts cpu_atom/cycles/ (fixed counter).
set -u
V=$1; OUT=$2; shift 2
B=$V/bin/PolyMult.time
E() { local s=""; for x in "$@"; do s="$s,cpu_atom/$x/"; done; echo "${s#,}"; }
G1=$(E cycles instructions uops_issued.any topdown_be_bound.all topdown_be_bound.mem_scheduler topdown_be_bound.non_mem_scheduler)
G2=$(E cycles mem_uops_retired.all_loads mem_uops_retired.all_stores mem_uops_retired.split_loads mem_load_uops_retired.l1_hit mem_load_uops_retired.l1_miss)
G3=$(E cycles mem_scheduler_block.all mem_scheduler_block.ld_buf mem_scheduler_block.st_buf mem_scheduler_block.rsv topdown_be_bound.register topdown_be_bound.reorder_buffer)
G4=$(E cycles topdown-retiring topdown-fe-bound topdown-be-bound topdown-bad-spec topdown_be_bound.alloc_restrictions topdown_be_bound.serialization)
G5=$(E cycles uops_retired.all ld_head.any_at_ret mem_bound_stalls.load ld_blocks.address_alias)
for L in "$@"; do
  for g in 1 2 3 4 5; do
    eval EV=\$G$g
    tag=leaf${L}_g$g
    { date '+%F %T'; uptime; ps -eLo user,pid,psr,pcpu,comm --sort=-pcpu | awk 'NR==1 || $3==16' | head -5; } >> $OUT/core16.log
    taskset -c 16 perf stat -x, -e "$EV" -o $OUT/$tag.perf \
        $B -dA 100000 -dB 100000 -t 1 -r 3 --tune leaf_size=$L > $OUT/$tag.out 2>&1
  done
done

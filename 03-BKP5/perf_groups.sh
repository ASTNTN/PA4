#!/bin/bash
# BKP5 perf groups: $1 = threads, output dir $2
PL='{16},{20},{24},{28},{17},{21},{25},{29},{18},{22},{26},{30},{19},{23},{27},{31}'
G[1]=cpu_atom/cycles/,cpu_atom/instructions/,cpu_atom/uops_issued.any/,cpu_atom/topdown_be_bound.all/,cpu_atom/topdown_be_bound.mem_scheduler/,cpu_atom/topdown_be_bound.non_mem_scheduler/
G[2]=cpu_atom/mem_uops_retired.all_loads/,cpu_atom/mem_uops_retired.all_stores/,cpu_atom/mem_uops_retired.split_loads/,cpu_atom/mem_load_uops_retired.l1_hit/,cpu_atom/mem_load_uops_retired.l1_miss/
G[3]=cpu_atom/mem_scheduler_block.all/,cpu_atom/mem_scheduler_block.ld_buf/,cpu_atom/mem_scheduler_block.st_buf/,cpu_atom/mem_scheduler_block.rsv/,cpu_atom/topdown_be_bound.register/,cpu_atom/topdown_be_bound.reorder_buffer/
G[4]=cpu_atom/topdown-retiring/,cpu_atom/topdown-fe-bound/,cpu_atom/topdown-be-bound/,cpu_atom/topdown-bad-spec/,cpu_atom/topdown_be_bound.alloc_restrictions/,cpu_atom/topdown_be_bound.serialization/
G[5]=cpu_atom/cycles/,cpu_atom/mem_bound_stalls.load/,cpu_atom/mem_bound_stalls.load_l2_hit/,cpu_atom/l2_request.all/,cpu_atom/mem_load_uops_retired.l2_hit/,cpu_atom/ld_blocks.address_alias/
for g in 1 2 3 4 5; do
  OMP_PROC_BIND=close OMP_PLACES="$PL" taskset -c 16-31 perf stat -x, -e ${G[$g]} \
    ./bin/PolyMult.time-par -dA 100000 -dB 100000 -t $1 -r 3 --tune block_size=512 2> $2/t$1_g$g.txt | tail -1
done

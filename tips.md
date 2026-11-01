# How to use perf

# Available modifications

# Why does static scheduling still yield overhead for me?

Memory reordering

try an outer loop for OPP1 with no reduction - it doesn't look like I've tried that yet

Explore atomics and criticals - they will kill performance but cause linearization


# Trick with Reductions

`reduction(+:c[:n])` all threads will accumulate into this.

Each thread will write into half of the array

Declare the target of the reduction to be an array instead of a scalar.

# Blocked

Exploit locality

Blocking is hard with this parallelogram


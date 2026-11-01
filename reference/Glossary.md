# Glossary of Terms (Procinfo1/2/3)

Every technical term used in `Procinfo1.md`, `Procinfo2.md`, and `Procinfo3.md`,
defined plainly — no prior computer-architecture course assumed. Alphabetical;
each entry is self-contained, so you can look up one term without having read
the others first. Where useful, an entry points back to the section it comes
from and to related entries.

---

### AVX2

The specific set of CPU instructions this chip uses to do vector math (see
**SIMD**). "AVX2" names the instruction set; **FMA3** is the particular
multiply-add instruction in it on which the processor's peak-performance numbers
are based. This chip does not support the newer, wider **AVX-512** at all.
*(Procinfo1 § 1)*

### Back end

The half of a core that actually *executes* instructions once they've been
fetched and decoded — the **ports**, the **FMA** unit, the load/store units, and
the memory system behind them. Contrast with **front end**, which supplies the
back end with work. Either half can be the reason a program runs slow,
independently of the other. *(Procinfo3 § 1.A)*

### Backend Bound

One of the four **TMA** categories. Means: the **front end** was supplying
instructions just fine, but the **back end** couldn't execute them fast enough —
either its execution units were busy, or an instruction was stuck waiting on
data from memory. Splits further into **Core Bound** and **Resource Bound**.
*(Procinfo3 § 1.C, § 1.D)*

### Bad Speculation

One of the four **TMA** categories. Means: work was done that turned out to be
wasted, almost always because the CPU guessed which way a branch (an `if`, or a
loop's exit test) would go, started executing down that path, and guessed wrong.
Since the control flow of PolyMult is very predictablem this is likely to be
rare in our experiments. *(Procinfo3 § 1.C)*

### Cache

One or more small, fast blocks of memory that sit between a core and much slower
main memory (**DRAM**) or differenet levels of the memory hierarchy, holding
recently- or soon-to-be-used data so the core doesn't have to wait for DRAM
every time. See **L1 cache**, **L2 cache**, **L3 cache** for the specific levels
on this chip, each bigger and slower than the last. *(Procinfo1 § 4)*

### Cache coherence

The guarantee that if two different cores each keep their own copy of the same
cache line, those copies stay consistent — when one core writes its copy, every
other core's copy is automatically invalidated and has to be refetched. This
happens for correctness, whether or not the program actually has a bug, and can
be expensive if it happens a lot. See **false sharing** for the common way this
becomes a performance problem. *(Procinfo3 § 4.A)*

### Cache line

The unit memory actually moves in: 64 bytes at a time, always as a whole block,
never a single byte on its own — reading even one 4-byte float pulls in its
whole 64-byte line along with it. On this chip, 64 bytes is 16 single-precision
floats — exactly two of this project's 256-bit vector loads' worth (8 floats
each).

Cache-line size is why *alignment* matters for performance, not just
correctness. An access is **aligned** when it starts exactly on a cache-line
boundary (every 64 bytes) and **misaligned** otherwise; the load-port mechanics
in Procinfo3 § 2.D actually care about a finer, 16-byte boundary, since that's
how wide one of this chip's load-port halves is. A misaligned access can end up
straddling two different cache lines instead of fitting inside one — see
**cache-line split** for what that actually costs on this machine. This
project's harness controls alignment explicitly through the `BPM_ALIGN` build
setting: the default (0) reproduces plain `malloc`'s usual 16-byte alignment;
`BPM_ALIGN=64` aligns every array to a full cache line, so a 256-bit vector
load into it can never start misaligned. *(Procinfo1 § 4, Procinfo3 § 2.D)*

### Cache-line split

What happens when one load's data straddles two different **cache lines** —
part of it in one 64-byte block, the rest in the next — because the load
started at a **misaligned** address. A split load costs roughly twice as long
as one that fits inside a single line: measured on this chip's E-cores
(Procinfo3 § 2.D), a 128-bit load goes from 0.5 to 1.0 cycle when split, and
the 256-bit loads this project's kernels actually use go from 1.0 to 2.0
cycles. Internally the hardware works in 16-byte halves, so a 256-bit load
only splits if one of its two halves crosses a line boundary — a load
starting on any multiple of 16 bytes never does, which is exactly what
`BPM_ALIGN=64` (or even just 16) guarantees. Without it, a loop whose
starting offset shifts by one 4-byte float every iteration (e.g. a sliding
window) lands on a different alignment each time, and roughly one iteration
in five ends up split. *(Procinfo3 § 2.D)*

### Cluster

A group of 4 **E-cores** that share one **L2 cache** between them (this chip has
4 such clusters, 16 E-cores total). Which cluster a thread runs in — and how
many other threads share it — has a real, measurable effect on performance; see
**thread-to-core placement**. *(Procinfo1 § 1, Procinfo3 § 3)*

### Core Bound

The first of the two ways **Backend Bound** can split: means the execution
**ports** themselves were the constraint — not enough independent work was ready
to keep them busy, or every port able to do the needed work was already full.
Contrast with **Resource Bound**. *(Procinfo3 § 1.D)*

### cpu_atom / cpu_core

The names Linux's `perf` tool uses for this chip's two kinds of core: `cpu_atom`
means **E-core**, `cpu_core` means **P-core**. Needed because the chip actually
has two separate sets of hardware performance counters (see **PMU**), one per
core type, and most `perf` commands need to be told explicitly which one to
read. *(Procinfo1 § 1, Procinfo3 § 5.C)*

### Decode

The step where the **front end** translates the raw bytes of a fetched
instruction into the internal signals the rest of the core acts on. A core can
only decode a limited number of instructions per cycle, regardless of how idle
the **back end** is. *(Procinfo3 § 1.A)*

### Dependency chain (independent chain)

A sequence of instructions where each one needs the *result* of the one before
it (e.g. `sum += ...` inside a loop, where each iteration needs the previous
iteration's `sum`). A single dependency chain can only execute as fast as its
slowest instruction's **latency**, no matter how many execution ports are free —
the fix is to keep several *independent* chains running at once, so the ports
always have something ready to work on. *(Procinfo2 § 2.A)*

### DRAM

Main memory — far bigger than any **cache**, and far slower to reach (roughly
200-300 cycles, versus ~5 for the fastest cache). The last and slowest stop in
the memory hierarchy. *(Procinfo1 § 4)*

### E-core (Efficient core)

One of this chip's 16 smaller, individually slower cores, built for efficient
multi-threaded work. E-cores are grouped into 4 **clusters** of 4, sharing L2
within a cluster. Contrast with **P-core**. Labeled `cpu_atom` in commands like
`perf`. *(Procinfo1 § 1)*

### False sharing

A specific, common cause of expensive **cache coherence** traffic: two threads
are writing to *different* values that just happen to land in the same 64-byte
**cache line**. The values themselves aren't shared — only the cache line they
happen to sit in is — but the hardware still has to treat it as a conflict.
*(Procinfo3 § 4.A)*

### FLOP / FLOPs and FLOPS

FLOP = one **floating-point** operation (one multiply, or one add). FLOPs =
plural of FLOP, and FLOPS (may sound the same), is the number of operations
executed *per second* (the S is part of the acronym); All three may be prefixed
by M (mega), G (giga), etc. *(Procinfo1 § 2)*

### FMA (Fused Multiply-Add)

A single instruction that computes `d = a × b + c` — a multiply and an add
together, with only one rounding step at the end (which is also why it's
slightly more accurate than doing the multiply and add separately). Because it
does two arithmetic operations (one multiply, one add) in one instruction, an
FMA counts as **two** floating-point operations when computing GFLOPs. This is
the instruction the whole project's peak performance numbers are built on.
*(Procinfo2 § 1.C)*

### Front end

The half of a core that fetches instructions from memory and **decodes** them,
keeping a steady stream of work flowing to the **back end**. Contrast with back
end. Either half can be the bottleneck on its own. *(Procinfo3 § 1.A)*

### Frontend Bound

One of the four **TMA** categories. Means: the **back end** was ready and
waiting for work, but instruction fetch/**decode** in the **front end** couldn't
supply it fast enough. *(Procinfo3 § 1.C)*

### GFLOPs

See **FLOP / FLOPs / FLOPS,**.

### Hybrid architecture

This chip's design: two different kinds of core (**P-core** and **E-core**) on
the same chip, rather than many identical cores. *(Procinfo1 § 1)*

### IPC (Instructions Per Cycle)

A single summary number: how many instructions, on average, finished ("retired")
per clock cycle during a run. Easy to compute, but easy to over-read — a
"reasonable" IPC doesn't tell you whether that work was genuinely useful or
mostly bookkeeping; a **TMA** breakdown answers that, IPC alone can't.
*(Procinfo3 § 5.E)*

### L1 cache

The smallest and fastest **cache**, private to one core (~5-cycle latency here).
Split into a separate data cache and instruction cache (the front end's cache is
the I-cache; Procinfo2's discussion of loads is about the D-cache). *(Procinfo1
§ 4)*

### L2 cache

The second cache level: bigger and slower than L1. On a **P-core** it's private
(2 MB, one core only); on an **E-core** it's larger (4 MB total) but shared by a
**cluster** of 4 cores. Because it's shared, the number of active threads in a
cluster changes how much L2 bandwidth each one actually gets — see
**thread-to-core placement**. *(Procinfo1 § 4, Procinfo3 § 3.A)*

### L3 cache

The largest, slowest on-chip cache level (36 MB), shared by every core on the
chip — Intel calls it "Smart Cache." Any active core can claim up to the whole
36 MB if other cores aren't using it. *(Procinfo1 § 4)*

### Lane

One of the fixed positions inside a **vector register**. A 256-bit register
holds 8 single-precision numbers side by side, in 8 lanes; one vector
instruction operates on all 8 lanes in the same cycle. See **SIMD**, **lane
shift**. *(Procinfo2 § 1.B)*

### Lane shift (shuffle)

An extra instruction needed when a loop wants the same numbers again but
permuted differently (e.g. a sliding window or a broadcast) so they have to be
moved before they can be used again. *(Procinfo3 § 2.D)*

### Instruction Latency

How long it takes for one instruction's *result* to actually be ready for
another instruction to use — as opposed to **throughput**, which is how often
new instructions can *start*. The two are not in conflict: a core can start a
new instruction every cycle even though each individual one takes several cycles
to finish, the same way an assembly line can finish a new car every minute even
though building one car takes an hour. Latency only becomes a direct problem
when instructions form a **dependency chain**. *(Procinfo2 § 2.A)* A simular
concept is also used for memory access times

### Load port

A **port** dedicated to starting load instructions (reading a value from cache
or memory into a register). This chip's E-cores have 2 load ports; P-cores have
3. See **port**, **load queue**. *(Procinfo2 § 1.A)*

### Load queue (load buffer)

A small hardware structure that tracks every load instruction from the moment it
starts until it actually finishes (a different question from how many loads can
be *started* per cycle, which is what **load ports** count). If every tracking
slot is full — because loads are taking a while to complete and new ones keep
arriving — the core has to stall issuing more loads even if the ports themselves
have room. *(Procinfo3 § 2.B)*

### Micro-operation (uop)

An internal step a hardware unit performs in one cycle; one machine instruction
can be broken into more than one of these behind the scenes. Relevant here
because a wide (256-bit) load or store on an E-core takes *two* micro-operations
(two 128-bit halves) instead of one, which is why it costs two port-slots
instead of one. *(Procinfo3 § 2.D)*

### P-core (Performance core)

One of this chip's 8 larger, individually faster cores, built for heavy
single-threaded work; each has its own private L2 cache and supports **SMT**
(simultaneous multi-threading or the ability for the hardware itself to execute
two or more threads per core). SMT happens at the hardware level with a very
small cost to contex-switch, because the state of the other thread is maintained
in a separate set of "shadow registers". Labeled `cpu_core` in commands like
`perf`. *(Procinfo1 § 1)*. Contrast with **E-core**.

### PAPI (Performance API)

A programming library that reads the same underlying hardware counters as `perf
stat` (see **PMU**), but from inside your own program instead of as an external
command wrapping the whole run — useful for measuring just one part of a program
rather than the whole thing. *(Procinfo3 § 5.D)*

### perf / perf stat

The standard Linux command-line tool for reading a CPU's hardware performance
counters (see **PMU**). Given a program and a list of events to count, it prints
the totals when the program finishes. `perf stat --topdown` is the specific form
that prints the **TMA** categories directly. *(Procinfo3 § 5.B)*

### Pipeline / pipelined

The design that lets **throughput** and **latency** be different numbers: an
execution unit can start a new instruction before the previous one has finished,
the same way an assembly line can start a new car before the last one rolls off
the end. *(Procinfo2 § 2.A)*

### Pipeline slot

The basic unit **TMA** measures in: one opportunity, once per cycle, to start
one **micro-operation**. Every slot in a run gets classified into exactly one of
the four top-level **TMA** categories, so they always add up to 100%.
*(Procinfo3 § 1.B)*

### PMU (Performance Monitoring Unit)

Dedicated hardware, built into every core, that counts specific kinds of events
(instructions finished, cache hits, cycles stalled, ...) as a program runs,
essentially for free — this is what tools like **perf stat** and **PAPI**
actually read from. This chip has two separate PMUs, one for each core type; see
**cpu_atom / cpu_core**. *(Procinfo3 § 5.A, § 5.C)*

### Port

Think of a port as a service window inside a core: each cycle, the core can hand
at most one instruction to each port, and different ports offer different
services (some do floating-point math, some do loads, some do stores). The
number and kind of ports a core has directly limits how much work it can start
per cycle — a program's speed is capped by whichever port it needs most. See
**load port**, **store port**. *(Procinfo2 § 1.A)*

### Prefetching (prefetcher)

Dedicated hardware that watches the pattern of addresses a program is reading,
and — if the pattern is simple and predictable, like "the next address after the
last one" — starts fetching further-ahead data into cache *before* the program
actually asks for it. This is why a loop can stream through an array far bigger
than L1 and still show a high L1 hit rate: the data was already prefetched in by
the time it's needed. Prefetching hides the *wait*, not the underlying data
movement — the bytes still have to travel from wherever they were and the
bandwidth is that of the slowest level in the chain. *(Procinfo3 § 2.A)*

### Register

The fastest possible place to hold a value — inside the core itself, zero-cycle
access, used directly as the operand of an instruction. This chip has 16 vector
registers per core (see **vector register**); running out of them forces a
**register spill**. *(Procinfo1 § 4.B, Procinfo2 § 1.B)*

### Register spill

What happens when a loop needs more values alive at once than there are
registers to hold them (16, on this chip): the compiler has to write some values
out to memory and read them back later, which costs load and store instructions
— consuming exactly the port capacity the program was trying to conserve.
Usually a serious performance problem, not a minor one, when it happens inside a
hot loop. *(Procinfo2 § 1.D)*

### Resource Bound

The second of the two ways **Backend Bound** can split: means some *other*
limited resource — usually somewhere in the memory pipeline, like a **load
queue** — was full or busy, even though the execution ports themselves had room
to spare. Contrast with **Core Bound**. Intel's usual name for this on
non-E-cores is "memory-bound." *(Procinfo3 § 1.D)*

### Retiring

One of the four **TMA** categories, and the one you want to be high: the slot
did useful work that made it all the way to completion. *(Procinfo3 § 1.C)*

### SIMD (Single Instruction, Multiple Data)

The idea behind vector instructions: one instruction operates on several numbers
at once (the **lanes** of a **vector register**) instead of one number at a
time. This chip's vector registers hold 8 single-precision numbers, so one SIMD
instruction does the work of 8 ordinary ones. *(Procinfo2 § 1.B)*

### SMT (Simultaneous Multithreading)

A feature of this chip's **P-cores** (not E-cores) that lets one physical core
run two software threads at once, sharing the core's execution resources between
them. *(Procinfo1 § 1)*

### Store port

A **port** dedicated to starting store instructions (writing a value from a
register out to cache or memory). Both core types on this chip have 2 store
ports. *(Procinfo2 § 1.A)*

### Store queue

The store-instruction counterpart to a **load queue**: tracks every in-flight
store from issue until it completes, in a small, fixed-size hardware structure.
*(Procinfo3 § 2.B)*

### Thread-to-core placement (affinity)

Which physical core a software thread actually runs on — not automatic, but
something you control explicitly (`taskset` for a whole process, OpenMP's
`OMP_PLACES` for individual threads). This matters a lot on E-cores
specifically, because it decides whether several threads end up sharing one
**cluster**'s L2 cache or not; identical code and thread count can perform very
differently depending purely on this choice. *(Procinfo3 § 3.B)*

### Throughput

How often a new operation can be *started* — as opposed to **latency**, which is
how long one operation takes to finish. See **pipeline**. *(Procinfo2 § 2.A)*

### TMA (Topdown Microarchitecture Analysis)

A method, built on the hardware's own performance counters, for answering *why*
a specific, measured run fell short of its theoretical peak — as opposed to
port-counting (Procinfo2), which only tells you what the ceiling is, not why a
real run misses it. Classifies every **pipeline slot** into **Retiring**, **Bad
Speculation**, **Frontend Bound**, or **Backend Bound**, then lets you split
**Backend Bound** further into **Core Bound** vs. **Resource Bound**. Read
top-down: rule out Bad Speculation and Frontend Bound first, then decide whether
Backend Bound is core- or resource-bound before going any further. *(Procinfo3 §
1)*

### TPP / TMP/ TPP_per_core

Theoretical Program Peak: the best performance in GFLOPs/s that can ever be
ttained for that program.  Compare to TMP (theoretical Machine Peak) the best
performance a processor can deliver -- based on the hardware. In this project,
almost the whole program can be executed by FMAs so they are both equal
(`TMP_per_core` for one E-core is 35.2 GFLOPs/s). TPP is not a standard
industry term but specific to this project. *(Procinfo1 § 2)*

### Turbo Boost

Intel's mechanism for running a core faster than its **base frequency** when
power and thermal headroom allow — opportunistic, not guaranteed, and **disabled
machine-wide for this project**, so it's background information only.
*(Procinfo1 § 3)*

### Vector register (YMM register)

A register that holds 256 bits at once — 8 single-precision numbers side by side
(see **lane**, **SIMD**). This chip has 16 of them per core, named YMM0-YMM15.
*(Procinfo2 § 1.B)*

### Vector width (128-bit / 256-bit)

How many bits of data one vector instruction or load moves at once. This
project's kernels are 256-bit (8 single-precision numbers). E-cores' internal
pipes and load ports are only 128 bits wide each, so a 256-bit operation has to
be split into two 128-bit halves internally — this is why an E-core's
*effective* rate for 256-bit vector work is half of what a naive port count
would suggest, for both arithmetic (Procinfo2 § 1.A) and loads (Procinfo3 §
2.D).

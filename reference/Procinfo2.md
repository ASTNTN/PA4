# Intel Core i9-13900K Architecture Details for Performance

---

## Recap of Procinfo1

The full detail is in `Procinfo1.md`; the pieces this document builds on:

- The chip has two kinds of core. **P-cores** (8 of them) are the "big"
  cores. **E-cores** (16 of them) are smaller and individually slower, but
  there are twice as many. E-cores are grouped into **4 clusters of 4**,
  and the 4 cores in one cluster share one L2 cache.
- Each core's floating-point peak follows from `Cores × Frequency ×
  Operations/cycle` (Procinfo1 § 2). This document derives the
  "Operations/cycle" number from first principles in § 1.C below.
- Cache gets slower and bigger the further it is from a core: L1 (fastest,
  smallest, private to one core) → L2 (bigger, shared within an E-core
  cluster) → L3 (biggest, shared by the whole chip) → DRAM (slowest,
  effectively unlimited) (Procinfo1 § 4).

---

## 1. Inside a Core: the Execution Engine

This section explains some of the architectural details that are essential to
get the highest performance.

### 1.A A core is not one machine, it is several

The mental model of "the CPU executes one instruction, then the next" has not
been true for about thirty years. A single core contains a number of separate
**execution units**, and it can start work on several instructions in the same
clock cycle.

Instructions reach those units through **ports**. A port is best thought of as
a service window: each cycle, the core can hand at most one instruction to each
port. Different ports offer different services, and some services are available
at more than one window.

The two core types differ here, and not only in how many. The ports that matter
for numerical work are, roughly:

| service | P-core | E-core |
|---|---|---|
| vector floating-point multiply-add (256-bit) | **2** | **1** |
| loads (reading from cache or memory) | **3** | **2** |
| stores (writing) | 2 | 2 |
| integer arithmetic | 5 | 4 |

So in one clock cycle a single P-core can begin two floating-point vector
operations *and* three loads *and* two stores, all at once — provided the
instructions are independent and the data is ready. An E-core can begin one
vector operation and two loads of 128 bits or less (but only one 256-bit
load, see below).

The E-core figure of one deserves a word, because it is not simply a smaller
number of the same thing. An E-core has two floating-point pipes, but each is
128 bits wide. A 256-bit AVX2 instruction is therefore split into two halves
that occupy both pipes together, so the core retires **one** 256-bit vector
operation per cycle rather than two. That is where Procinfo1 § 2's "16
operations per cycle" for an E-core comes from, against 32 for a P-core.

The E-core's load ports are 128 bits wide in the same way. A 256-bit
vector load is carried out as two 16-byte halves (two micro-operations) and
takes both load ports for a cycle, so an E-core starts one 256-bit load per
cycle, not two. This was measured; see Procinfo3 § 2.D.

The consequence worth remembering: **the limit on a program is whichever port
it needs most.** A loop that needs four loads per cycle will run at
three-quarters speed no matter how few arithmetic operations it has, because
the load ports are the bottleneck.

That leads to a result most people find backwards. Compare the two core types
by how many loads they can sustain *per arithmetic operation*:

- P-core: 3 load ports ÷ 2 FMA ports = **1.5 loads per FMA** (256-bit
  loads not measured on the P-core here)
- E-core: 2 load ports ÷ 1 FMA port = **2.0 loads per FMA** for loads of
  128 bits or less, but only **1.0** for 256-bit vector loads (two load
  ports, two halves per load)

For loads of 128 bits or less, the E-core is more tolerant of memory
traffic relative to its arithmetic. For 256-bit vector loads, which is
what fast numerical loops use, its figure is 1.0 and the comparison no
longer favors it, unless a 256-bit load also takes two port slots on the
P-core (not measured here). Which core is "faster" depends on the balance
of the loop, not on the core alone.

### 1.B What a single vector operation does

A **vector register** holds 256 bits. Interpreted as single-precision floats (4
bytes each) that is **8 numbers side by side**; as double-precision, 4 numbers.
One instruction operates on all lanes simultaneously — this is SIMD, *single
instruction, multiple data*.

There are **16 such registers** per core, named YMM0 through YMM15. This is a
hard architectural limit and it matters a great deal in practice; see § 1.D.

### 1.C FMA — fused multiply-add

The instruction the peak numbers are built on computes

```
d = a × b + c
```

in a single instruction. It is called **fused** because the multiply and the
add are performed with only one rounding at the end, rather than rounding the
product and then rounding the sum. That makes it very slightly *more* accurate
than a separate multiply and add — and it means an FMA counts as **two**
floating-point operations.

Now the peak follows arithmetically:

```
2 FMA ports  ×  8 float lanes  ×  2 operations per FMA  =  32 operations per cycle
```

That is the "32 Operations/Cycle" used in Procinfo1 § 2. An E-core has one FMA
port instead of two, hence 16.

### 1.D Registers, and what happens when you run out

There are only 16 vector registers. If a loop needs more live values than that,
the compiler must **spill** — write some to memory and read them back later.
Spilled values then need load and store instructions, which consume load and
store ports, which are the very resource you were trying to conserve.

Spilling in an inner loop is usually catastrophic rather than merely
unfortunate. Much of the work of tuning numerical kernels is arranging for the
working set to fit in 16 registers.

---

## 2. Optimizing Performance

Section 1 covered the machinery a core has to offer. This section is about
what it takes for a real loop to actually reach it.

### 2.A Throughput and latency are different numbers

This is the distinction that most often surprises people, and it is the main
reason real code falls short of peak.

- **Throughput** — how often a new operation can be *started*. Two FMAs per
  cycle on a P-core, one on an E-core.
- **Latency** — how long before the *result* can be used by another
  instruction. No current Intel document publishes this. The accepted
  figure, from uops.info's hardware measurements, is **4 cycles on a
  P-core, 6 on an E-core**. Our own measurement, in one experiment, gave
  6.2 cycles.

Those are not in conflict; the unit is pipelined, like an assembly line. You
can start a new car every minute even though each car takes an hour to build.

But it has a sharp consequence. Consider summing a list:

```c
for (i = 0; i < n; i++)
    sum += a[i] * b[i];        /* each iteration needs the previous sum */
```

Every iteration must wait for the previous one to finish, because `sum` is both
an input and an output. So on a P-core you get one FMA every 4 cycles instead
of two every cycle — **one eighth of peak**, and no amount of tuning the memory
access will change it.

The fix is to keep several *independent* chains in flight:

```c
for (i = 0; i < n; i += 4) {
    s0 += a[i  ] * b[i  ];      /* four separate running totals, */
    s1 += a[i+1] * b[i+1];      /* none waiting on another       */
    s2 += a[i+2] * b[i+2];
    s3 += a[i+3] * b[i+3];
}
sum = s0 + s1 + s2 + s3;
```

To keep two FMA ports busy when each result takes 4 cycles, you need
**2 × 4 = 8 independent chains**. Fewer than that and the ports idle.

The requirement is *ports × latency*, so it differs between the core types. An
E-core issues one vector FMA per cycle rather than two, but its longer 6-cycle
latency means it needs about **6** chains, not fewer — not far short of a
P-core's 8. Code written to satisfy a P-core still satisfies an E-core
automatically, but the margin between them is smaller than the port count
alone would suggest, which matters when the same binary runs on both.

(Note that this transformation changes the order of the additions. In exact
arithmetic that is harmless; in floating point it changes the result slightly,
which is why a compiler will not do it for you unless you permit it.)

### 2.B A cache hit is not free

A natural assumption is that once data is in cache, access is free. It is not.
Every value that is not already in a *register* needs a load instruction to
fetch it, and that instruction occupies a load port whether the data comes from
L1 cache or from main memory.

Cache determines **how long** a load takes (roughly 5 cycles from L1, a few
hundred from DRAM). The port count determines **how many** loads can be started
per cycle. A loop can be perfectly cache-resident and still be limited entirely
by load ports. How much port time one load takes depends on its width and
alignment; see Procinfo3 § 2.D.

This is why keeping values in registers and reusing them matters even when
everything fits in cache.

### 2.C Putting it together

To approach the peak in Procinfo1 § 2 — 32 operations per cycle on a P-core,
16 on an E-core — a loop must satisfy all of:

1. use FMA instructions, on vectors, in single precision;
2. issue no more loads than the load ports can supply alongside the FMAs
   (1.5 per FMA on a P-core, 2.0 on an E-core for loads of 128 bits or
   less, 1.0 for 256-bit vector loads);
3. keep enough independent dependency chains in flight (~8 on a P-core, ~6 on
   an E-core);
4. fit its working set within 16 vector registers — the same on both;
5. and, of course, have its data in cache.

Failing any one of these caps performance regardless of the other four. Most
disappointing numerical code fails 2, 3, or 4 — not 5, which is where people
usually look first.

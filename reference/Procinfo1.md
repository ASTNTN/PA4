# Intel Core i9-13900K Architecture and Performance Summary

## 1. Processor Details, Cores, and Frequencies

- **Core Configuration:** The processor features a total of 24 physical cores
  and 32 execution threads, leveraging a performance hybrid architecture.
- **Naming in commands and system calls:** in commands and system calls
  (e.g. `perf`), E-cores are labeled `cpu_atom` and P-cores are labeled
  `cpu_core`.
- **Performance Cores (8 P-Cores):** Designed to handle heavy, single-threaded
  primary workloads. These cores do not use clusters. Each P-core has its own
  completely independent 2 MB L2 cache. These cores have Simultaneous
  MultiThreading (SMT), which lets one core execute two threads at once.
- **Base Frequency (Without Turbo):** 3.00 GHz
- **Efficient Cores (16 E-Cores):** Optimized for background processes and
  scalable, massive multi-threaded tasks. They are physically grouped into
  **4 distinct clusters**. Each cluster contains exactly 4 E-cores, and all 4
  cores within a single cluster must share one 4 MB block of L2 cache.
- **Base Frequency (Without Turbo):** 2.20 GHz
- **Vector Execution Units:** Execution relies strictly on the 256-bit AVX2 /
  FMA3 instruction set baseline (AVX-512 capability is absent or permanently
  disabled on this processor architecture).
- **P-Core Execution Density:** Each P-core can issue **two** Fused
  Multiply-Add (FMA) instructions per clock cycle. This results in 32
  Single-Precision (FP32) operations per cycle per core.
- **E-Core Execution Density:** Each E-core can issue only **one** Fused
  Multiply-Add (FMA) instruction per clock cycle. This results in 16
  Single-Precision (FP32) operations per cycle per core.

---

## 2. Maximum Performance Calculation at Nominal Frequency

The maximum theoretical computing performance under standard baseline operating
speeds is determined directly by multiplying the core count, nominal base
frequency, and vector hardware capabilities:

- **Mathematical Formula:**
  `Performance (GFLOPs) = Cores × Frequency (GHz) × Operations per Cycle`
- **P-Cores Base Calculation (3.00 GHz):**
  `8 Cores × 3.00 GHz × 32 Operations/Cycle = 768.0 GFLOPs`
- **E-Cores Base Calculation (2.20 GHz):**
  `16 Cores × 2.20 GHz × 16 Operations/Cycle = 563.2 GFLOPs`
  (35.2 GFLOPs on a single E-core — this is `TPP_per_core` as used
  throughout this project, e.g. `EXPERIMENTS.md`, `VARIANTS.md`)
- **Combined Nominal Base Performance (Sum):**
  `768.0 GFLOPs + 563.2 GFLOPs = 1331.2 GFLOPs (1.331 TFLOPs)`

---

## 3. Turbo Boost and Max Turbo Performance

**Turbo Boost is disabled on the fish machines for the semester, so this
section is informational.** Turbo Boost is Intel's mechanism for scaling core
clock frequency above the nominal base rate when workload demand, available
power budget, and thermal headroom allow it. The busier and hotter the chip
runs, the less margin there is to boost, so the achieved frequency is
opportunistic, not guaranteed. The peak figures below are a ceiling. Intel
does not publish a distinct *all-core* sustained turbo figure.

- **P-Core Turbo Scaling:** Intel's published Max Turbo Frequency is 5.40
  GHz; with Intel Turbo Boost Max Technology 3.0 (the single favored core)
  that rises to 5.70 GHz, and with Intel Thermal Velocity Boost (thermal
  headroom permitting) to 5.80 GHz.
- **E-Core Turbo Scaling:** The E-cores scale from their baseline up to a
  published Max Turbo Frequency of 4.30 GHz.
- **P-Cores Peak Turbo Calculation (5.40 GHz, Intel's published Max Turbo
  Frequency):**
  `8 Cores × 5.40 GHz × 32 Operations/Cycle = 1,382.4 GFLOPs`
- **E-Cores Peak Turbo Calculation (4.30 GHz):**
  `16 Cores × 4.30 GHz × 16 Operations/Cycle = 1,100.8 GFLOPs`
- **Combined Maximum Theoretical Turbo Peak (Sum):**
  `1,382.4 GFLOPs + 1,100.8 GFLOPs = 2,483.2 GFLOPs (2.483 TFLOPs)`

---

## 4. Cache Hierarchy

### 4.A Cache Hierarchy Breakdown

- **L1 Cache (2.125 MB Total):** Smallest, fastest cache level operating at
  core clock speed for immediate instructions; dedicated strictly per
  individual core.
- **L2 Cache (32 MB Total):** Mid-tier buffer split equally between 16 MB for
  Performance-cores (2 MB dedicated per core) and 16 MB for Efficient-core
  clusters (4 MB shared per 4-core cluster).
- **L3 Cache (36 MB Total):** The only level officially branded as **Intel
  Smart Cache**; acts as a massive shared pool before the CPU must access
  slower system RAM. The L3 cache has some interesting features:
  - **Dynamic Sharing:** Like most level-3 caches, all 24 processor cores
    access the same 36 MB pool.
  - **Elastic Allocation:** Active cores can dynamically claim up to the entire
    36 MB cache size if other cores are idle.
  - **Latency Reduction:** by keeping critical data centrally accessible to
    whichever core needs it next.

### 4.B Approximate Access Costs

Useful for reasoning about where time goes. Figures are typical rather than
exact, and latency matters far less than it appears when many independent
accesses are in flight at once. The L2 row below is the P-core case (private
2 MB); an E-core's L2 is a 4 MB block shared by its whole 4-core cluster, so
when sibling cores are contending for it, actual latency can run higher than
this figure.

| level | size | approximate latency |
|---|---|---|
| register | 16 × 32 bytes | 0 cycles (operand of the instruction) |
| L1 data | 48 KB per core | ~5 cycles |
| L2 | 2 MB per P-core | ~15 cycles |
| L3 | 36 MB shared | ~50 cycles |
| DRAM | — | ~200–300 cycles |

The jump that usually dominates is the last one. The jump that usually
surprises people is the first: moving a value from L1 into a register still
costs an instruction and a port, as discussed in Procinfo2 § 2.B.

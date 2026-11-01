# VARIANTS

The student will explore these variants in sequence, each building on
insights from prior stages. Claude is a robot: it implements what the
student decides, not its own design choices. This document specifies
what each variant should accomplish.

---

## 00-GSQ: Grade-School Reference

Computes the polynomial-multiplication definition directly, with no
parallelism. Once validated, GSQ is the gold standard every later
variant's correctness is checked against.

---

## 01-OPQ: Outer-Product Loop Order

Reorganize the loops to expose outer-product structure:

for i = 0 to dA:
    for j = 0 to dB:
        // NEW LOOP BODY

Parallel variants: `OPP1`, `OPP2`, etc.

---

## 02-EXQ: Loop Exchange

Exchange the i and j loops:

for j = 0 to dB:
    for i = 0 to dA:
        // NEW LOOP BODY

Parallel variants: `EXP1`, `EXP2`, etc.

---

## 03-BKQ: Blocked

Apply blocking to the loop nest, using square blocks only.

Parallel variants: `BKP1`, `BKP2`, etc.

---

## 04-DCQ: Divide-and-Conquer

Recursively divide into quadrants, switching to the best-performing
blocked variant below a leaf-size threshold. The leaf size is to be
explored.

---

## 05-DCP: Divide-and-Conquer Parallel

Parallelize DCQ using OpenMP tasks. Each strategy explored gets its own
variant directory (`DCP1`, `DCP2`, ...), with the common infrastructure
copied into each, per the naming convention in `DESIGN.md`.

---

## Progression

GSQ -> OPQ, EXQ, BKQ -> DCQ -> DCP

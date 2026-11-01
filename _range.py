#!/usr/bin/env python3
"""Shared range-expansion helper, used by sweep.sh for shell-side --tune
axis looping. Mirrors shared/harness/range.c's bpm_parse_range EXACTLY --
the three forms (powers-of-two, stride, enumeration) and their precedence
(check "..." first, then ":", else comma-enumeration, which also accepts a
single bare integer as a length-1 list). Keep both in sync by hand; there
is no other shared implementation.

Not meant to be run directly except by sweep.sh.
"""
import sys


def parse_powers_of_two(lower, upper):
    if lower <= 0 or upper <= 0 or lower > upper:
        raise ValueError(f"bad powers-of-two range: {lower}...{upper}")
    out = []
    v = 1
    while v <= upper:
        if v >= lower:
            out.append(v)
        if v > upper // 2:
            break
        v *= 2
    if not out:
        raise ValueError(f"empty powers-of-two range: {lower}...{upper}")
    return out


def parse_stride(expr):
    parts = expr.split(":")
    if len(parts) != 3:
        raise ValueError(f"bad stride range: {expr!r} (want start:end:stride)")
    start, end, stride = (int(p) for p in parts)
    if stride <= 0 or start > end:
        raise ValueError(f"bad stride range: {expr!r}")
    return list(range(start, end + 1, stride))


def parse_enumeration(expr):
    out = []
    for tok in expr.split(","):
        tok = tok.strip()
        if not tok:
            raise ValueError(f"bad enumeration: {expr!r}")
        out.append(int(tok))
    if not out:
        raise ValueError(f"empty enumeration: {expr!r}")
    return out


def parse_range(expr):
    """Returns the expanded list of int values, in the same order range.c
    would produce. A bare single integer ("8") is a valid 1-element
    enumeration -- callers decide "is this an axis" from len() > 1, not
    from any syntax check here."""
    if "..." in expr:
        lower_s, upper_s = expr.split("...", 1)
        return parse_powers_of_two(int(lower_s), int(upper_s))
    if ":" in expr:
        return parse_stride(expr)
    return parse_enumeration(expr)


def cartesian(exprs):
    """One line per combination, values space-separated, axes in the given
    order (leftmost varies slowest -- matches a nested-loop reading)."""
    lists = [parse_range(e) for e in exprs]
    combos = [[]]
    for lst in lists:
        combos = [c + [v] for c in combos for v in lst]
    return combos


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit("usage: _range.py expand RANGE_EXPR | _range.py cartesian RANGE_EXPR ...")
    try:
        if sys.argv[1] == "expand":
            if len(sys.argv) != 3:
                sys.exit("usage: _range.py expand RANGE_EXPR")
            # One value per line -- sweep.sh reads this with `mapfile`,
            # which splits on newlines, not whitespace.
            for v in parse_range(sys.argv[2]):
                print(v)
        elif sys.argv[1] == "cartesian":
            for combo in cartesian(sys.argv[2:]):
                print(" ".join(str(v) for v in combo))
        else:
            sys.exit(f"unknown mode {sys.argv[1]!r}")
    except ValueError as e:
        sys.exit(f"error: {e}")

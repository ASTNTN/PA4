# Updating from `~/provided/StudentPolyMult`

Whenever the provided project changes — a new infrastructure redesign, a
corrected reference doc, a bug fix — the same two steps apply. The worked
example below (the Multi-Axis Sweep Infrastructure) is one instance of
this process, not the only case it covers.

## 1. Merge the provided project over your own

```
cp -r ~/provided/StudentPolyMult/. /path/to/your/project/
```

The trailing `/.` is essential — without it, `cp` nests everything under a
new `StudentPolyMult/` subfolder instead of merging. This only overwrites
files that exist in `~/provided/StudentPolyMult`; your own variant dirs,
results, and plots are untouched, but any infrastructure file you'd
locally edited is silently overwritten too.

## 2. Fix your own code against whatever changed

A shared-infrastructure update can break your own variant code if it
depended on the old shape of something (a struct field, a function
signature, a file that no longer exists). The compiler or runtime error
is usually the fastest way to find out what changed and where — fix your
code to the new interface, keeping your own logic/fallback values; don't
just revert the merge.

### Worked example: Multi-Axis Sweep Infrastructure (`bpm_tune_t` redesign)

If your `sweep.sh` mentions `--tune` but you're hitting errors like
`can't open file '_range.py'`, you have a partial or pre-redesign copy.
Merge again (step 1) rather than copying files one at a time — the
pieces only work together.

If any of your variants reads a tuning parameter the old way:

```c
int bs = (tune->block_size > 0) ? tune->block_size : 100;
```

it will fail to build against the new `kernel.h`:

```
error: 'bpm_tune_t' has no member named 'block_size'
```

Fix it to use the new generic accessor, keeping *your own* fallback value:

```c
long bs_val = bpm_tune_get(tune, "block_size", 0);
int bs = (bs_val > 0) ? (int)bs_val : 100;
```

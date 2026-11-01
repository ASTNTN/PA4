CC   = gcc
STD  = -std=gnu11
OPT  = -O3 -march=native
LIBS = -lm

SRC      = src/PolyMult.c
HARNESS  = ../shared/harness
INCLUDE  = -I../shared/include -I$(HARNESS)
VARIANT  = -DBPM_VARIANT='"GSQ"'

CHECK_SRCS = $(SRC) $(HARNESS)/oracle.c $(HARNESS)/check_main.c
TIME_SRCS  = $(SRC) $(HARNESS)/range.c $(HARNESS)/args.c $(HARNESS)/time_main.c

# Listed as prerequisites so editing a header actually triggers a rebuild.
# Without these, a change to accumulate.h leaves stale binaries in place
# and the correctness gate silently re-runs the old code.
HEADERS = ../shared/include/kernel.h ../shared/include/accumulate.h \
          $(HARNESS)/args.h $(HARNESS)/range.h $(HARNESS)/oracle.h

# No gold suite here, deliberately, and this is not an omission to be tidied
# up later: GSQ *is* the gold reference the other variants link against, so
# checking it against a copy of itself would pass unconditionally and prove
# nothing. GSQ is held to the oracle alone. See shared/harness/check_main.c.

.PHONY: all debug clean

all: bin bin/PolyMult.check bin/PolyMult.check-par bin/PolyMult.time bin/PolyMult.time-par

bin:
	mkdir -p bin

bin/PolyMult.check: $(CHECK_SRCS) $(HEADERS) | bin
	$(CC) $(STD) $(OPT) $(INCLUDE) $(VARIANT) -DCHECKING $(CHECK_SRCS) -o $@ $(LIBS)

bin/PolyMult.check-par: $(CHECK_SRCS) $(HEADERS) | bin
	$(CC) $(STD) $(OPT) $(INCLUDE) $(VARIANT) -DCHECKING -DPAR -fopenmp $(CHECK_SRCS) -o $@ $(LIBS)

bin/PolyMult.time: $(TIME_SRCS) $(HEADERS) | bin
	$(CC) $(STD) $(OPT) $(INCLUDE) $(VARIANT) -ffast-math $(TIME_SRCS) -o $@ $(LIBS)

bin/PolyMult.time-par: $(TIME_SRCS) $(HEADERS) | bin
	$(CC) $(STD) $(OPT) $(INCLUDE) $(VARIANT) -ffast-math -DPAR -fopenmp $(TIME_SRCS) -o $@ $(LIBS)

debug: OPT = -O0 -g -Wall -Wextra
debug: all

clean:
	rm -f bin/*

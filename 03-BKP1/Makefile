CC   = gcc
STD  = -std=gnu11
OPT  = -O3 -march=native
LIBS = -lm

SRC      = src/PolyMult.c
HARNESS  = ../shared/harness
INCLUDE  = -I../shared/include -I$(HARNESS)
VARIANT  = -DBPM_VARIANT='"BKP1"'

CHECK_SRCS = $(SRC) $(HARNESS)/oracle.c $(HARNESS)/check_main.c
TIME_SRCS  = $(SRC) $(HARNESS)/range.c $(HARNESS)/args.c $(HARNESS)/time_main.c

# Listed as prerequisites so editing a header actually triggers a rebuild.
HEADERS = ../shared/include/kernel.h ../shared/include/accumulate.h \
          $(HARNESS)/args.h $(HARNESS)/range.h $(HARNESS)/oracle.h \
          $(HARNESS)/gold.h

# Gold suite: the checking binaries also link the precompiled gold.o plus a
# fresh recompile of GSQ's own kernel renamed to bpm_gold_multiply. That
# recompile takes neither this variant's -DBPM_VARIANT nor -DPAR, so it stays
# GSQ's true sequential checking build. See DESIGN.md "Build system".
GSQ_SRC  = ../00-GSQ/src/PolyMult.c
GOLD_OBJ = $(HARNESS)/gold.o bin/gsq_gold.o
GOLD     = -DBPM_HAVE_GOLD

.PHONY: all debug clean

all: bin bin/PolyMult.check bin/PolyMult.check-par bin/PolyMult.time bin/PolyMult.time-par

bin:
	mkdir -p bin

bin/gsq_gold.o: $(GSQ_SRC) $(HEADERS) | bin
	$(CC) $(STD) $(OPT) $(INCLUDE) -DCHECKING -Dkernel_multiply=bpm_gold_multiply -c $(GSQ_SRC) -o $@

bin/PolyMult.check: $(CHECK_SRCS) $(GOLD_OBJ) $(HEADERS) | bin
	$(CC) $(STD) $(OPT) $(INCLUDE) $(VARIANT) $(GOLD) -DCHECKING $(CHECK_SRCS) $(GOLD_OBJ) -o $@ $(LIBS)

bin/PolyMult.check-par: $(CHECK_SRCS) $(GOLD_OBJ) $(HEADERS) | bin
	$(CC) $(STD) $(OPT) $(INCLUDE) $(VARIANT) $(GOLD) -DCHECKING -DPAR -fopenmp $(CHECK_SRCS) $(GOLD_OBJ) -o $@ $(LIBS)

bin/PolyMult.time: $(TIME_SRCS) $(HEADERS) | bin
	$(CC) $(STD) $(OPT) $(INCLUDE) $(VARIANT) -ffast-math $(TIME_SRCS) -o $@ $(LIBS)

bin/PolyMult.time-par: $(TIME_SRCS) $(HEADERS) | bin
	$(CC) $(STD) $(OPT) $(INCLUDE) $(VARIANT) -ffast-math -DPAR -fopenmp $(TIME_SRCS) -o $@ $(LIBS)

debug: OPT = -O0 -g -Wall -Wextra
debug: all

clean:
	rm -f bin/*

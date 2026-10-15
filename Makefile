# =====================================================================
# CS 253 -- Scratch: throwaway builds for demos and in-class work
#
# THIS IS NOT A GRADED LAB. There is no fixed target. You name what you
# want built, every time, on the command line.
#
#   make NAME                 NAME.c -> NAME
#   make NAME-asan            NAME.c -> NAME-asan, with the sanitizers
#   make NAME-O0 / -O1 / -O2  NAME.c -> NAME-O0 etc, forced optimisation
#   make NAME.i / .s / .o     stop after preprocess / assembly / compile
#   make PROG=x SRCS="..."    multi-file or multi-program builds
#   make style                clang-format over whatever .c and .h exist
#   make bigfile              write big.txt, about 20 MB
#   make fixtures             write fixtures/, four awkward input files
#   make clean                remove what this file can safely name
#   make help                 the same list, with examples
#
# NOTHING HERE RUNS YOUR PROGRAM. It builds and stops. The lab Makefile
# wraps things in a 20 second alarm, and that is right for grading and
# wrong here: a runaway loop you stop with Ctrl-C, and a recursion you
# let run until it smashes the stack, are both demos. Build it, then run
# it yourself, and decide when it stops.
#
# The warning set is the enhanced one from Module 05 onward, always, so
# scratch is never looser than a lab.
# =====================================================================

# `CC` has a built-in default of `cc` in make, and `?=` does not override
# a built-in default -- so set it explicitly unless the environment says.
ifeq ($(origin CC),default)
  CC = gcc
endif

# Every rule below is one I wrote on purpose. An object file left over
# from a demo three weeks ago should not let make quietly invent a rule
# I did not write.
MAKEFLAGS += --no-builtin-rules

STD = -std=c11

# ---------------------------------------------------------------------
# Warnings. Base set is supported by both gcc and clang.
# ---------------------------------------------------------------------
WARN  = -Wall -Wextra -Wpointer-arith -Wstrict-prototypes

# Enhanced static analysis, which the labs pick up at Module 05. Here it
# is on from week one: scratch should never accept something a lab would
# reject. The last two are GCC-only, so they are added conditionally and
# this still works under clang.
WARN += -Wformat-security -Wfloat-equal -Wshadow -Wconversion \
        -Wlogical-not-parentheses -Wnull-dereference
IS_GCC := $(shell $(CC) --version 2>/dev/null | head -1 | grep -ci '^gcc')
ifeq ($(IS_GCC),1)
  WARN += -Wduplicated-cond -Wjump-misses-init
endif

# _POSIX_C_SOURCE is what makes the POSIX library visible under
# -std=c11, which is strict ISO C and hides it by default. Measured on
# gcc 13.3 / Ubuntu 24.04: without this macro, fileno, fdopen, getline,
# strdup and kill are all implicitly declared. open() and read() happen
# to survive without it on glibc, so do not use those two to convince
# yourself the flag is unnecessary. Modules 13 and 14 set the same macro
# in their lab Makefiles. It is on here unconditionally, because this one
# file has to work in week 2 and week 14 without being edited, and the
# macro only adds declarations. It takes nothing away. -I. and -Isrc cover both a lone file at the top level
# and a src/ layout; an -I pointing at a directory that does not exist
# is not an error, so this does not care which you are using today.
CFLAGS = $(STD) -D_POSIX_C_SOURCE=200809L $(WARN) -g -I. -Isrc

# -lm is the math library. On Linux it is separate from the C library,
# so anything calling sqrt or pow fails to link without it. Your
# Codespace is Linux. Add LDLIBS= to any command below to drop it and
# reproduce that link failure on purpose, which is the Module 05 demo.
LDLIBS = -lm

# ---------------------------------------------------------------------
# Sanitizers. LeakSanitizer is Linux-only: on macOS -fsanitize=leak does
# not exist, so the note says what you actually got.
# ---------------------------------------------------------------------
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
  SANITIZE = -fsanitize=address,leak
  SAN_NOTE = address + leak (LeakSanitizer)
else
  SANITIZE = -fsanitize=address
  SAN_NOTE = address only, LeakSanitizer is unavailable on $(UNAME_S)
endif

.PHONY: style bigfile fixtures clean help

# ---------------------------------------------------------------------
# One file, one binary. On a directory holding readings.c, `make
# readings` is the whole rule.
#
# The rules below this one are more specific patterns: they require a
# literal -asan or -O0 at the end. A bare `%` is what make calls a
# match-anything rule, and it is used only when no more specific pattern
# applies, so `make readings-asan` always takes the sanitized rule and
# never this one. Order in the file does not decide it, though I have
# put the specific rules first anyway so it reads correctly top to
# bottom.
#
# The one case this cannot save you from: if readings.c and
# readings-asan.c both exist, `make readings-asan` still means the
# sanitized build of readings.c. Do not name a source file with a -asan,
# -O0, -O1 or -O2 suffix.
# ---------------------------------------------------------------------

# The plain build and the sanitized build of the SAME source, side by
# side under different names. Module 06 needs exactly this: the memory
# layout demo must not run from the ASan build, because ASan brings its
# own allocator and the heap address comes back wrong for the story you
# are telling. Build both, keep both.
%-asan: %.c
	@printf '%s\n' '  sanitizers: $(SAN_NOTE)'
	$(CC) $(CFLAGS) $(SANITIZE) -O1 $< -o $@ $(LDLIBS)

# Optimisation variants of one file, coexisting, same reasoning.
%-O0: %.c
	$(CC) $(CFLAGS) -O0 $< -o $@ $(LDLIBS)

%-O1: %.c
	$(CC) $(CFLAGS) -O1 $< -o $@ $(LDLIBS)

%-O2: %.c
	$(CC) $(CFLAGS) -O2 $< -o $@ $(LDLIBS)

# The Module 05 pipeline, one stage at a time, same flags at every stage
# on purpose: preprocess and stop, compile to assembly and stop,
# assemble to an object and stop. Running `nm foo.o` afterwards is yours.
%.i: %.c
	$(CC) $(CFLAGS) -E $< -o $@

%.s: %.c
	$(CC) $(CFLAGS) -S $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# The common case, last, because it matches anything.
%: %.c
	$(CC) $(CFLAGS) $< -o $@ $(LDLIBS)

# ---------------------------------------------------------------------
# The escape hatch, for anything the single-file rules cannot say:
# several sources, a shared header, or two programs built from one set
# of files. Nothing here needs editing either, set it on the command
# line.
#
#   make PROG=statspack SRCS="src/*.c"
#
# Quote the glob. Unquoted, your shell expands it before make sees it,
# against whatever happens to be in the directory you are standing in.
#
# Two programs sharing everything but main(), which is Module 13's
# mycat and mywc and Module 14's three, is one command each:
#
#   make PROG=mycat SRCS="src/mycat.c src/common.c"
#   make PROG=mywc  SRCS="src/mywc.c src/common.c"
#
# Add ASAN=1 to either for the sanitized build instead of the plain one.
# With PROG set, plain `make` builds it, so there is no target word to
# remember. With PROG unset, plain `make` prints help.
# ---------------------------------------------------------------------
PROG ?=
SRCS ?=
ASAN ?=

ifeq ($(strip $(PROG)),)
  .DEFAULT_GOAL := help
else
  .DEFAULT_GOAL := $(PROG)
  .PHONY: $(PROG)
ifeq ($(strip $(ASAN)),1)
$(PROG):
	@printf '%s\n' '  sanitizers: $(SAN_NOTE)'
	$(CC) $(CFLAGS) $(SANITIZE) -O1 $(SRCS) -o $(PROG) $(LDLIBS)
else
$(PROG):
	$(CC) $(CFLAGS) $(SRCS) -o $(PROG) $(LDLIBS)
endif
endif

# ---------------------------------------------------------------------
# Reports SKIPPED rather than failing when clang-format is absent, so a
# laptop without it is not a hard stop. In a Codespace, absent
# clang-format means NOT READY rather than not available: the container
# installs it in postCreateCommand, which finishes about 30 seconds
# after the terminal appears. There it is an error telling you to wait.
# ---------------------------------------------------------------------
STYLE_SRCS := $(wildcard *.c *.h src/*.c src/*.h)

style:
	@if [ -z "$(strip $(STYLE_SRCS))" ]; then \
	    printf '%s\n' '  no .c or .h files here yet, nothing to check'; \
	 elif ! command -v clang-format >/dev/null 2>&1; then \
	    if [ -n "$$CODESPACES" ]; then \
	        printf '%s\n' '  clang-format is not on PATH YET.' \
	                      '  Your Codespace is still finishing setup, which takes about 30' \
	                      '  seconds after the terminal appears. Wait, then run make style' \
	                      '  again. Style has NOT been checked.'; \
	        exit 1; \
	    fi; \
	    printf '%s\n' '  clang-format not installed -- SKIPPED. Style was NOT checked.'; \
	 elif clang-format --dry-run --Werror $(STYLE_SRCS) 2>&1; then \
	    printf '%s\n' '  style OK'; \
	 else \
	    exit 1; \
	 fi

# ---------------------------------------------------------------------
# big.txt, about 20 MB. Module 13 times a 4096 byte read against a one
# byte read over a file this size, and a 9 KB fixture is useless for
# that because process startup costs more than the copying. Module 14
# pipes it into head to force SIGPIPE. It is a real file, not a phony
# target, so asking twice does not rewrite 20 MB. `make clean` removes
# it.
# ---------------------------------------------------------------------
big.txt:
	@yes 'the quick brown fox' | head -n 1000000 > $@
	@ls -lh $@

bigfile: big.txt

# ---------------------------------------------------------------------
# The four awkward inputs from Module 12, each its own file for the same
# reason as big.txt: written once, kept, regenerated only after clean.
# Hand-edit one and `make fixtures` will not clobber it back.
# ---------------------------------------------------------------------
FIXTURE_DIR := fixtures
FIXTURES    := $(FIXTURE_DIR)/blank-line.txt $(FIXTURE_DIR)/no-newline.txt \
               $(FIXTURE_DIR)/empty.txt $(FIXTURE_DIR)/crlf.txt

# Each recipe makes the directory itself. The obvious alternative, an
# order-only prerequisite on $(FIXTURE_DIR), does not work here: the
# directory and the phony target are both called fixtures, so make treats
# the prerequisite as the phony target and never creates anything.
fixtures: $(FIXTURES)

$(FIXTURE_DIR)/blank-line.txt:
	@mkdir -p $(@D)
	@printf 'first line\n\nthird line\n' > $@

$(FIXTURE_DIR)/no-newline.txt:
	@mkdir -p $(@D)
	@printf 'first line\nsecond line\nno newline at the end' > $@

$(FIXTURE_DIR)/empty.txt:
	@mkdir -p $(@D)
	@: > $@

$(FIXTURE_DIR)/crlf.txt:
	@mkdir -p $(@D)
	@printf 'first line\r\nsecond line\r\n' > $@

# ---------------------------------------------------------------------
# clean removes what it can name safely: the derived suffixes, objects
# and intermediates, and the generated files. It does NOT go hunting for
# `readings` or `statspack`, because with no fixed target there is no
# way to tell a compiled binary called notes from a text file called
# notes that you wanted to keep. Name it if you want it gone:
# make clean BIN=readings
# ---------------------------------------------------------------------
BIN ?=

clean:
	rm -f *.o *.i *.s *-asan *-O0 *-O1 *-O2
	rm -f src/*.o src/*.i src/*.s
	rm -rf *.dSYM
	rm -f big.txt
	rm -rf $(FIXTURE_DIR)
ifneq ($(strip $(BIN)),)
	rm -f $(BIN) $(BIN)-asan $(BIN)-O0 $(BIN)-O1 $(BIN)-O2 $(BIN).o $(BIN).i $(BIN).s
	rm -rf $(BIN)-asan.dSYM
endif

help:
	@printf '%s\n' \
	'CS 253 scratch. There is no fixed target, so you name one:' \
	'' \
	'  make NAME               NAME.c -> NAME' \
	'  make NAME-asan          NAME.c -> NAME-asan, with the sanitizers' \
	'  make NAME-O0            forced -O0, alongside the plain build' \
	'  make NAME-O1            forced -O1' \
	'  make NAME-O2            forced -O2' \
	'  make NAME.i             stop after preprocessing' \
	'  make NAME.s             stop after compiling to assembly' \
	'  make NAME.o             stop after assembling, then try: nm NAME.o' \
	'' \
	'  make PROG=name SRCS="files or a quoted glob"' \
	'      make PROG=statspack SRCS="src/*.c"' \
	'      make PROG=statspack SRCS="src/*.c" LDLIBS=   (link failure, on purpose)' \
	'      make PROG=mycat SRCS="src/mycat.c src/common.c"' \
	'      make PROG=mywc  SRCS="src/mywc.c src/common.c"' \
	'      add ASAN=1 to either form for the sanitized build' \
	'' \
	'  make style              clang-format over every .c and .h it finds' \
	'  make bigfile            write big.txt, about 20 MB' \
	'  make fixtures           write fixtures/, four awkward input files' \
	'  make clean              remove build artifacts, add BIN=name for a binary' \
	'  make help               this message' \
	'' \
	'Flags: -std=c11 -g and the Module 05 enhanced warnings, always.' \
	'-lm is on, add LDLIBS= to turn it off. -D_POSIX_C_SOURCE=200809L is' \
	'always on, so open() and read() work. Nothing here runs your program,' \
	'and nothing here times out.'

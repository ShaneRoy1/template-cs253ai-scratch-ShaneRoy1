# CS 253 Scratch

A throwaway workspace for demos and in-class activities. Same Codespace as your labs, no
assignment attached to it, nothing graded in it.

**This is not where lab work goes.** Your lab lives in its own repository and is graded there.
Use this one for the thing I put on the screen in class, for trying an idea, and for whatever an
assistant hands you that you want to run before you trust it.

## Getting one

Click **Use this template**, set the owner to **your own GitHub account**, and give it any name
you like. Then **Code**, **Codespaces**, **Create codespace on main**.

Make as many as you want. One for the whole semester is fine. One per week is fine. Delete them
whenever. They are yours, they are not submitted anywhere, and I never look at them.

Give the Codespace about 30 seconds after the terminal appears. It is still installing
`clang-format` in the background, and `make style` will tell you to wait if you are early.

## Building

There is no fixed target here, so you name what you want:

```bash
make readings          # readings.c  ->  readings
./readings
```

That is the whole thing for a single file, which is most of what you will do.

| You type | You get |
|---|---|
| `make NAME` | `NAME.c` compiled to `NAME` |
| `make NAME-asan` | the same file built with the sanitizers, **alongside** the plain build |
| `make NAME-O0`, `-O1`, `-O2` | forced optimisation levels, all able to coexist |
| `make NAME.i` | stop after preprocessing, so you can read what `#include` actually pulled in |
| `make NAME.s` | stop after compiling to assembly |
| `make NAME.o` | stop after assembling, then try `nm NAME.o` |
| `make style` | `clang-format` over every `.c` and `.h` it can find |
| `make clean` | remove build artifacts, add `BIN=name` to remove a binary too |
| `make help` | all of this, in the terminal |

`make NAME-asan` builds a second binary rather than replacing the first on purpose. Some things
only show up in the plain build, because the sanitizer brings its own memory allocator and moves
everything around, so you often want both open at once.

### More than one file

```bash
make PROG=statspack SRCS="src/*.c"
```

Quote the glob. Without the quotes your shell expands it before `make` sees it, against whatever
happens to be in the directory you are standing in.

Two programs that share everything except `main` is one command each:

```bash
make PROG=mycat SRCS="src/mycat.c src/common.c"
make PROG=mywc  SRCS="src/mywc.c src/common.c"
```

Add `ASAN=1` to either for the sanitized build.

### Turning `-lm` off

`-lm` is linked by default. Add `LDLIBS=` to any command to drop it:

```bash
make PROG=statspack SRCS="src/*.c" LDLIBS=      # fails to find sqrt, on purpose
```

## Test data

```bash
make bigfile      # big.txt, about 20 MB, for timing and for pipes
make fixtures     # fixtures/, four files that break naive line readers:
                  #   a blank line in the middle, no trailing newline,
                  #   completely empty, and CRLF line endings
```

Both are gitignored and both come back after `make clean`.

## The flags, and why they are stricter than your lab

```
-std=c11 -g -D_POSIX_C_SOURCE=200809L
-Wall -Wextra -Wpointer-arith -Wstrict-prototypes
-Wformat-security -Wfloat-equal -Wshadow -Wconversion
-Wlogical-not-parentheses -Wnull-dereference
-Wduplicated-cond -Wjump-misses-init        (gcc only)
```

Your labs pick up the second and third rows at Module 05. Here they are on from week one, so
that code which compiles clean in scratch never turns around and fails in a lab. It can go the
other way: something your Module 02 lab accepts may warn here. That is the point.

`-D_POSIX_C_SOURCE=200809L` is what makes the POSIX library visible under `-std=c11`, which is
strict ISO C and hides it. Without it `getline`, `strdup`, `fileno` and `fdopen` are all
implicitly declared.

## Nothing here runs your program

`make` builds and stops. Your lab Makefile wraps things in a 20 second alarm so grading cannot
hang, which is right for grading and wrong here: a loop you stop with Ctrl-C and a recursion you
let run until it smashes the stack are both things we do on purpose in this course. Build it,
then run it yourself, and decide when it stops.

# PRGALIGN: project context for agents

## What this is

`PRGALIGN.PRG` is an AUTO folder program for TOS 2.06 and 3.06 on a
68020 or 68030. Their GEMDOS keeps memory blocks on even addresses
only, so a program can be loaded 2 bytes off a long word and run a few
percent slower. PRGALIGN stays resident, watches `Pexec` and makes
every program load on a long word. The README says how.

- `prgalign.S`: the resident part, the hook in the GEMDOS vector
  (XBRA id `PALN`).
- `install.c`: the part that runs once. No C library: GEMDOS and XBIOS
  only.

## Hard-won fixes (do not regress)

- **Never make a basepage to throw it away with `Mfree`.** GEMDOS
  counts a new basepage's standard handles and current directories, and
  only a process that terminates gives them back. A redirected output
  file would never be closed, and the directory counts are bytes. That
  is why the hook predicts with `Mxalloc` and never with `Pexec` mode 5
  or 7. `install.c` does make basepages to measure with, from user
  mode, and runs each as a process that only terminates.
- **Never start a process from inside the hook.** A child would run on
  the supervisor stack the hook is using. That is why mode 0 is done by
  changing the caller's own arguments to mode 6 and passing the call
  on, as Hatari's GEMDOS drive does.
- **The hook runs on its own stack.** TOS runs the AUTO folder from a
  process in supervisor mode whose stack is the command line of a
  256-byte basepage: about 40 bytes more than GEMDOS itself needs.
  GEMDOS saves a supervisor caller's registers on the caller's stack,
  50 bytes a call, so with the hook's calls on that stack GEMDOS's own
  fields in the basepage were overwritten and the first program after
  PRGALIGN crashed. A load from floppy by TOS 3.06 used under 150 bytes
  of the hook's 1024.
- **The hook's own GEMDOS calls set `bypass`**, so that they pass
  straight through it. Calls made by a driver further down the chain
  while a load is in hand come back through the hook and are passed on
  (`busy`).
- **No apostrophes in `prgalign.S`'s `|` comments**: the file goes
  through the C preprocessor.

## Build and test

```bash
STCMD_NO_TTY=1 stcmd make    # PRGALIGN.PRG and the test programs
tests/run-tests.sh           # Hatari, mtools and TOS images (tests/hrun.sh)
```

`tests/run-tests.sh` takes about ten minutes and runs two Hatari at a
time. Update the README's table from what it prints. A floppy run is
the one that matters most: there TOS loads the programs itself, where
Hatari's GEMDOS drive loads them for it.

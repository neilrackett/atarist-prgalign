# PRGALIGN for Atari ST

An AUTO folder fix for the TOS quirk that slows programs down on a
68020 or 68030, by [Neil Rackett](https://neilrackett.com/atarist)

## Introduction

TOS 2.06 and 3.06 keep memory on even addresses rather than on
multiples of 4, so they'll happily load a program 2 bytes off a long
word boundary. Whether they do depends on the length of the program's
environment, so the same program is fine on one start and unlucky on
the next.

A 68000 doesn't care. A 68020 or 68030 does: every long word that isn't
on a multiple of 4 takes two bus cycles to read instead of one, and an
unlucky program has all of its data, and usually its stack, that way.
It simply runs a few percent slower, with nothing to tell you why. Doom
on a TT030 lost between 2.6% and 8%, depending on the compiler it was
built with.

PRGALIGN sits in your `AUTO` folder and makes sure every program is
loaded on a long word boundary, so you get the lucky start every time.

You'll want it on a TT030, or on an ST, STE or Mega STE with TOS 2.06
and a 68020 or 68030 accelerator. You don't need it with TOS 4.04 or
EmuTOS, which don't have the quirk, on a 68000, or under MiNT or MagiC,
which manage memory themselves: PRGALIGN notices and stays out of the
way.

## Installation

1. Copy `PRGALIGN.PRG` into the `AUTO` folder of your boot disk, before
   any other program in there that you'd like to benefit.
2. Reset your computer. You'll see `Installed.` as it boots.

## Usage

There's nothing to set up and nothing to run: once it's installed,
every program TOS loads is on a long word boundary. It uses about 2K of
memory.

As it starts, PRGALIGN tells you what it found:

| It says                                                                      | Which means                                                  |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `Installed.`                                                                 | Programs are now loaded on long word boundaries              |
| `Already installed.`                                                         | It's in your `AUTO` folder twice                             |
| `Not installed: only a 68020 or later is slowed down.`                       | You have a 68000 or 68010, so there's nothing to gain        |
| `Not installed: this TOS loads programs on long words already.`              | You have TOS 4.04 or EmuTOS                                  |
| `Not installed: MiNT and MagiC place programs themselves.`                   | MiNT or MagiC is running                                     |
| `Not installed: needs GEMDOS 0.25 or later (TOS 2.06, 3.06).`                | Your TOS is too old for it                                   |
| `Not installed: this GEMDOS places programs in a way PRGALIGN doesn't know.` | Its measurements didn't fit, so it has left everything alone |

## How it works

PRGALIGN stays resident and watches `Pexec`. Before a program is loaded
(modes 0 and 3):

1. It works out how big TOS will make the copy of the program's
   environment.
2. For ST-RAM and for alternate RAM, such as TT-RAM, it finds out where
   the program's basepage would land using GEMDOS's own allocator: it
   allocates a block that size, takes the largest free block, notes its
   address and frees both.
3. If that address is 2 bytes off a long word, it puts a 2-byte block
   at the start of the largest free block and checks again.
4. The program is loaded, and the 2-byte blocks are freed.

"Load and go" (mode 0) becomes "load" (mode 3) followed by "go and
free" (mode 6), which is what a hard disk driver that loads programs
itself does too.

When it starts, it measures how your GEMDOS sizes an environment's copy
(TOS 3.06 rounds the length up to even and adds 2) by making four
basepages and running each as a process that only terminates. If the
answers don't fit, or every basepage is on a long word already, it
doesn't install.

## Known limitations

- Only where programs are loaded changes. Memory a running program
  allocates for itself with `Malloc` still starts on any even address.
- If GEMDOS ever puts the environment's copy in one kind of memory and
  the program in the other, PRGALIGN's prediction is wrong and that
  program may still load 2 bytes off. That hasn't been seen with TOS
  2.06 or 3.06.
- It passes its tests under Hatari, but hasn't been run on real
  hardware yet.
- Hatari's hard disk emulation loads programs itself, as ACSI2STM's
  GemDrive does, and PRGALIGN works with that. GemDrive itself hasn't
  been tried.

## What's next?

- Trying it on a real TT030, with and without GemDrive.
- Keeping the memory programs allocate for themselves on long word
  boundaries too.

Think you can help? Got an idea of your own? We'd love to hear from
you, so why not let me know on [X](https://x.com/neilrackett) or submit
a PR.

## Building

```bash
# PRGALIGN.PRG and the test programs: needs atarist-toolkit-docker
STCMD_NO_TTY=1 stcmd make

# Every test: needs Hatari, mtools and TOS images (see tests/hrun.sh)
tests/run-tests.sh
```

PRGALIGN is built with
[atarist-toolkit-docker](https://github.com/sidecartridge/atarist-toolkit-docker),
which provides `stcmd`.

### Tests

`tests/run-tests.sh` boots each machine with an `AUTO` folder that runs
`CHAIN.PRG`, which loads `WHERE.TOS` 14 times: with environments of 2
to 9 bytes, with its own environment, with modes 0 and 3, and with
standard output redirected to a file. Each row is how many of the 14
were loaded 2 bytes off:

| Machine                          | Loaded from      | Without | With PRGALIGN |
| -------------------------------- | ---------------- | :-----: | :-----------: |
| TT, TOS 3.06, 2 MB + 4 MB TT-RAM | Floppy           |    6    |       0       |
| TT, TOS 3.06, 2 MB + 4 MB TT-RAM | Hard disk folder |    6    |       0       |
| TT, TOS 3.06, 4 MB, no TT-RAM    | Floppy           |         |       0       |
| Mega STE with a 68030, TOS 2.06  | Floppy           |    8    |       0       |
| STE, TOS 1.62, 68000             | Floppy           |         | Not installed |
| Falcon, EmuTOS                   | Hard disk folder |    0    | Not installed |
| Falcon, TOS 4.04                 | Hard disk folder |    0    | Not installed |

From a floppy, TOS loads the programs itself. From the hard disk
folder, Hatari's GEMDOS drive loads them.

In every run the redirected output reached its file, and the free
memory afterwards was what it had been. On the TT, `CHAIN.PRG` was also
started from the desktop, PRGALIGN was put in the `AUTO` folder twice,
and Doom was started from the desktop, played and quit.

### Layout

| Path                 | Contents                                                                   |
| -------------------- | -------------------------------------------------------------------------- |
| `prgalign.S`         | The resident part: the `Pexec` hook                                        |
| `install.c`          | The part that runs once: the checks, the measurement and the installation  |
| `tests/where.c`      | `WHERE.TOS`, which says where it was loaded                                |
| `tests/chain.c`      | `CHAIN.PRG`, which loads `WHERE.TOS` every way PRGALIGN handles and counts |
| `tests/probe.c`      | `PROBE.TOS`, which shows where your TOS puts basepages                     |
| `tests/hrun.sh`      | Boots Hatari and prints what the machine wrote to its console              |
| `tests/run-tests.sh` | The test matrix above                                                      |

Working practices for contributors are in [AGENTS.md](AGENTS.md).

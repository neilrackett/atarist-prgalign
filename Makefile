# PRGALIGN.PRG, for the AUTO folder. Needs m68k-atari-mint-gcc: with
# atarist-toolkit-docker, "stcmd make".
CC = m68k-atari-mint-gcc
CFLAGS = -Os -Wall -fomit-frame-pointer -ffreestanding -fno-builtin

all: PRGALIGN.PRG tests

# prgalign.S first: the resident part is the start of the program
PRGALIGN.PRG: prgalign.S install.c
	$(CC) $(CFLAGS) -nostdlib -nostartfiles -s -o $@ prgalign.S install.c -lgcc

tests: tests/WHERE.TOS tests/CHAIN.PRG tests/PROBE.TOS

tests/WHERE.TOS: tests/where.c
	$(CC) -O2 -Wall -s -o $@ $<

tests/CHAIN.PRG: tests/chain.c
	$(CC) -O2 -Wall -s -o $@ $<

tests/PROBE.TOS: tests/probe.c
	$(CC) -O2 -Wall -s -o $@ $<

clean:
	rm -f PRGALIGN.PRG tests/*.TOS tests/*.PRG

.PHONY: all tests clean

/*
 * PRGALIGN: programs loaded on long-word boundaries.
 *
 * The GEMDOS of TOS 2.06 and 3.06 keeps memory blocks on even addresses
 * only. A program's memory starts behind a copy of its environment, whose
 * size depends on the environment's length, so a program can be loaded 2
 * bytes off a long word. A 68000 doesn't care. A 68020 or 68030 reads every
 * long word of such a program's data, and of its stack, in two bus cycles
 * instead of one: a few percent of its speed, on some starts and not on
 * others. (TOS 4 and EmuTOS keep blocks on long words.)
 *
 * This stays resident and watches Pexec. Before a program is loaded (modes
 * 0 and 3) it finds out where its basepage would land, in ST-RAM and in
 * alternate RAM, with GEMDOS's own allocator: it allocates a block the
 * size of the environment's copy, takes the largest free block and looks
 * at its address, then frees both. If that is 2 bytes off, a 2-byte block
 * at the start of the largest free block moves the program on to a long
 * word. The program is loaded, and the 2-byte blocks are freed again.
 *
 * No basepage is ever made to be thrown away (GEMDOS counts a basepage's
 * standard handles and directories, and only a process that terminates
 * gives them back), and the caller's environment is not touched.
 *
 * "Load and go" (mode 0) is done as GEMDOS's "load" (3) from here, then
 * "go and free" (6) by GEMDOS itself with the call's own arguments changed
 * to that, which is how a hard disk driver that loads programs itself
 * does it too. Nothing is called from here that starts a process: the
 * process would run on the supervisor stack this is using.
 *
 * install.c is the part that runs once: it checks the machine, measures
 * how big this GEMDOS makes an environment's copy (envextra), puts hook
 * into the GEMDOS vector and keeps everything up to resident_end.
 */

#define XBRA_ID	0x50414c4e		/* "PALN" */

#define OURSTACK	1024		/* bytes of stack for the hook: a load from
					   floppy by TOS 3.06 used under 150 */

#define GEMDOS(n)	st bypass; move.w IMM n,-(sp); trap IMM 1
#define IMM		#

	.text
	.globl	_start
	.globl	_oldvec
	.globl	_hook
	.globl	_envextra
	.globl	_resident_end
	.globl	_exit_stub
	.globl	_install
	.globl	_xbra_id

_start:
	jbra	start

| ---- resident ----------------------------------------------------------

_xbra_id:
	.long	XBRA_ID
_envextra:				| an environment of L bytes is copied
	.word	2			| into (L rounded up to even) + this
bypass:					| set for one call: a GEMDOS call of
	.byte	0			| our own, to be passed straight on
busy:					| a load is in hand
	.byte	0
	.even
oursp:					| the caller's stack pointer
	.long	0

	.long	0x58425241		| "XBRA"
	.long	XBRA_ID
_oldvec:
	.long	0
_hook:
	tst.b	bypass
	jbeq	look
	sf	bypass
pass:
	move.l	_oldvec(pc),-(sp)
	rts

| Is it Pexec, mode 0 or 3? The arguments are on the user stack, or on the
| supervisor stack behind the exception frame (6 bytes, 8 on a 68010 on).
look:
	move.l	a0,-(sp)
	lea	10(sp),a0
	tst.w	0x59e.w			| _longframe
	jbeq	look1
	addq.l	#2,a0
look1:
	btst	#5,4(sp)		| called from supervisor mode?
	jbne	look2
	move.l	usp,a0
look2:
	cmp.w	#0x4b,(a0)
	jbne	look3
	tst.w	2(a0)
	jbeq	load
	cmp.w	#3,2(a0)
	jbeq	load
look3:
	move.l	(sp)+,a0
	jbra	pass

| All of it on a stack of our own. The caller may have next to none: TOS
| runs the AUTO folder from a process in supervisor mode whose stack is the
| command line of its 256-byte basepage, about 40 bytes more than GEMDOS
| itself needs before it reaches the basepage's own fields. GEMDOS saves a
| supervisor caller's registers on the caller's stack, 50 bytes a call.
|
| GEMDOS keeps d3-d7 and a3-a6 over a call. a3 = the arguments of the call,
| d5 = the size of the copy of the environment, d7 = 0 ST-RAM, 1 alternate
| RAM (the mode for Mxalloc), a4 and a5 = the 2-byte blocks there, or 0.
load:
	tst.b	busy			| (never while one is in hand)
	jbne	look3
	st	busy
	move.l	sp,oursp
	lea	ourstack,sp
	movem.l	d1-d7/a1-a6,-(sp)
	move.l	a0,a3
	sub.l	a4,a4
	sub.l	a5,a5

	move.l	12(a3),d0		| the environment: the one given,
	jbne	load1
	move.l	0x4f2.w,a0		| or the calling process has one
	move.l	8(a0),a0		| (_sysbase, the OS header in ROM,
	move.l	0x28(a0),a0		| its pointer to the current
	move.l	(a0),a0			| basepage)
	move.l	0x2c(a0),d0
	jbeq	load3
load1:
	move.l	d0,a0			| its length, to the second of two
	move.l	a0,a1			| NULs
load2:
	tst.b	(a1)+
	jbne	load2
	tst.b	(a1)
	jbne	load2
	addq.l	#2,a1
	sub.l	a0,a1
	move.l	a1,d5
	bclr	#0,d5
	add.w	_envextra(pc),d5

	moveq	#0,d7
	jbsr	place
	move.l	d0,a4
	moveq	#1,d7
	jbsr	place
	move.l	d0,a5

load3:
	move.l	12(a3),-(sp)		| load it
	move.l	8(a3),-(sp)
	move.l	4(a3),-(sp)
	move.w	#3,-(sp)
	GEMDOS(0x4b)
	lea	16(sp),sp
	move.l	d0,d6

	move.l	a4,d0			| the 2-byte blocks have done
	jbsr	free			| their work
	move.l	a5,d0
	jbsr	free

	tst.w	2(a3)			| only to be loaded,
	jbne	load4
	tst.l	d6			| or not loaded:
	jble	load4
	move.w	#6,2(a3)		| else the call becomes "go and
	clr.l	4(a3)			| free" with that basepage
	move.l	d6,8(a3)
	clr.l	12(a3)
	movem.l	(sp)+,d1-d7/a1-a6
	move.l	oursp,sp
	move.l	(sp)+,a0
	sf	busy
	jbra	pass
load4:
	move.l	d6,d0			| the call is done
	movem.l	(sp)+,d1-d7/a1-a6
	move.l	oursp,sp
	move.l	(sp)+,a0
	sf	busy
	rte

| Mfree d0, if there is anything
free:
	tst.l	d0
	jbeq	free1
	move.l	d0,-(sp)
	GEMDOS(0x49)
	addq.l	#6,sp
free1:
	rts

| A program loaded into memory d7 on a long word: d0 = the 2-byte block
| that it takes, or 0 (none needed, no memory there, or no use)
place:
	jbsr	where
	btst	#1,d0
	jbeq	place2
	jbsr	largest			| the largest free block, cut down
	move.l	d0,d6			| to 2 bytes
	jble	place2
	pea	2.w
	move.l	d6,-(sp)
	clr.w	-(sp)
	GEMDOS(0x4a)			| Mshrink
	lea	12(sp),sp
	jbsr	where			| and now?
	btst	#1,d0
	jbeq	place1
	move.l	d6,d0
	jbsr	free
	jbra	place2
place1:
	move.l	d6,d0
	rts
place2:
	moveq	#0,d0
	rts

| Where would the basepage be in memory d7? d0 = its address, or 0. As
| GEMDOS will do it: a block for the copy of the environment (d5 bytes), then
| the largest free block.
where:
	move.w	d7,-(sp)
	move.l	d5,-(sp)
	GEMDOS(0x44)			| Mxalloc
	addq.l	#8,sp
	move.l	d0,d4
	jble	where2
	jbsr	largest
	move.l	d0,d3
	jble	where1
	jbsr	free
where1:
	move.l	d4,d0
	jbsr	free
	move.l	d3,d0
	jbgt	where3
where2:
	moveq	#0,d0
where3:
	rts

| Take the largest free block of memory d7: d0 = its address, or 0 or less
largest:
	move.w	d7,-(sp)
	pea	-1.w
	GEMDOS(0x44)			| Mxalloc: how big?
	addq.l	#8,sp
	tst.l	d0
	jble	largest1
	move.w	d7,-(sp)
	move.l	d0,-(sp)
	GEMDOS(0x44)
	addq.l	#8,sp
largest1:
	rts

	.even
	.space	OURSTACK
ourstack:
_resident_end:

| ---- runs once ------------------------------------------------------------

| A process that only terminates: install.c runs the basepages it measures
| with as this one
_exit_stub:
	clr.w	-(sp)
	trap	#1

start:
	move.l	4(sp),a5		| our basepage
	lea	stacktop,sp
	move.l	#stacktop,d0		| give back all the memory but ours
	sub.l	a5,d0
	move.l	d0,-(sp)
	move.l	a5,-(sp)
	clr.w	-(sp)
	move.w	#0x4a,-(sp)		| Mshrink
	trap	#1
	lea	12(sp),sp
	move.l	a5,-(sp)
	jsr	_install		| d0 = whether to stay
	addq.l	#4,sp
	tst.l	d0
	jbeq	start1
	clr.w	-(sp)
	move.l	#_resident_end,d0
	sub.l	a5,d0
	move.l	d0,-(sp)
	move.w	#0x31,-(sp)		| Ptermres
	trap	#1
start1:
	clr.w	-(sp)			| Pterm0
	trap	#1

	.bss
	.even
	.space	4096
stacktop:

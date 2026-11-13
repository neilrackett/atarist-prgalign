/* PRGALIGN, the part that runs once: is this a machine and a GEMDOS that
 * load programs 2 bytes off a long word, and does GEMDOS place a program
 * the way prgalign.S reckons with? If so the hook goes into the GEMDOS
 * vector. No C library: GEMDOS and XBIOS only. */

#include <mint/osbind.h>
#include <mint/basepage.h>

#define VERSION "1.0"

extern long xbra_id;		/* prgalign.S */
extern short envextra;
extern long oldvec;
extern void hook (void);
extern void exit_stub (void);

static long cpu, othersys, installed;

static void say (const char *s)
{
    (void) Cconws (s);
}

/* Supervisor mode: the cookies, and whether the hook is in the vector's
 * XBRA chain already */
static long look (void)
{
    long *jar = *(long **) 0x5a0L;
    long *v;

    cpu = othersys = installed = 0;
    if (jar)
	for (; jar[0]; jar += 2)
	{
	    if (jar[0] == 0x5f435055L)			/* _CPU */
		cpu = jar[1];
	    if (jar[0] == 0x4d694e54L || jar[0] == 0x4d616758L)	/* MiNT, MagX */
		othersys = 1;
	}
    for (v = *(long **) 0x84L; v[-3] == 0x58425241L; v = (long *) v[-1])
	if (v[-2] == xbra_id)
	{
	    installed = 1;
	    break;
	}
    return 0;
}

static long hookup (void)
{
    oldvec = *(long *) 0x84L;
    *(long *) 0x84L = (long) hook;
    return 0;
}

/* Where does GEMDOS put a program with an environment of len bytes? Makes
 * a basepage for one in ST-RAM (Pexec mode 7), notes its address and how
 * far behind its environment's copy it is, and runs it as a process that
 * only terminates, which gives everything back. */
static long measure (int len, long *behind)
{
    char env[8];
    BASEPAGE *bp;
    int i;

    for (i = 0; i < len - 2; i++)
	env[i] = 'A';
    env[len - 2] = env[len - 1] = 0;
    bp = (BASEPAGE *) Pexec (7, 0L, "", env);
    if ((long) bp <= 0)
	return 0;
    *behind = (long) bp - (long) bp->p_env;
    bp->p_tbase = (char *) exit_stub;
    (void) Pexec (6, 0L, bp, 0L);
    return (long) bp;
}

/* Returns whether to stay resident */
long install (BASEPAGE *me)
{
    long at, behind, extra = 0;
    int len, off = 0, unknown = 0, version;

    say ("\r\nPRGALIGN " VERSION ": programs on long-word boundaries\r\n");
    (void) Supexec (look);
    if (installed)
    {
	say ("Already installed.\r\n");
	return 0;
    }
    if (othersys)
    {
	say ("Not installed: MiNT and MagiC place programs themselves.\r\n");
	return 0;
    }
    if (cpu < 20)
    {
	say ("Not installed: only a 68020 or later is slowed down.\r\n");
	return 0;
    }
    version = Sversion ();			/* major in the low byte */
    if ((version & 0xff) != 0 || ((version >> 8) & 0xff) < 0x19)
    {
	say ("Not installed: needs GEMDOS 0.25 or later (TOS 2.06, 3.06).\r\n");
	return 0;
    }

    /* Environments of 2 to 5 bytes. The GEMDOS of TOS 3.06 copies one
     * into its length rounded up to even plus 2 bytes, and puts the
     * basepage straight behind the copy, so 4, 6, 6 and 8 bytes on: two
     * of the four 2 bytes off a long word wherever the free memory
     * starts. */
    for (len = 2; len <= 5; len++)
    {
	at = measure (len, &behind);
	if (!at)
	{
	    say ("Not installed: no memory to measure with.\r\n");
	    return 0;
	}
	if (at & 2)
	    off++;
	behind -= (len + 1) & ~1;
	if (len == 2)
	    extra = behind;
	if (behind != extra || extra < 0 || extra > 64 || (extra & 1))
	    unknown = 1;
    }
    if (!off)
    {
	say ("Not installed: this TOS loads programs on long words already.\r\n");
	return 0;
    }
    if (unknown)
    {
	say ("Not installed: this GEMDOS places programs in a way PRGALIGN doesn't know.\r\n");
	return 0;
    }
    envextra = extra;
    (void) Supexec (hookup);
    say ("Installed.\r\n");
    return 1;
}

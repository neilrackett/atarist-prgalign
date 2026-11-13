/* Loads \WHERE.TOS with environments of different lengths, in each of the
 * ways PRGALIGN handles (Pexec modes 0 and 3, standard output redirected to
 * a file), and counts the loads that were 2 bytes off a long word. Also
 * checks that nothing is left allocated and that the redirected output
 * reached its file. Built as a .PRG so that it can run from the AUTO folder
 * (after PRGALIGN.PRG), where TOS itself loads it from a floppy. */
#include <stdio.h>
#include <string.h>
#include <mint/osbind.h>
#include <mint/basepage.h>

#define CHILD "\\WHERE.TOS"

static int loads, off, errors;

static void setup (char *env, char *tail, int len, const char *what)
{
    if (len >= 2)
    {
	memset (env, 'A', 64);
	if (len > 3)
	    env[1] = '=';
	env[len - 2] = env[len - 1] = 0;
    }
    sprintf (tail + 1, "%s%d", what, len);
    tail[0] = strlen (tail + 1);
}

static void result (long r)
{
    loads++;
    if (r == 1)
	off++;
    else if (r)
    {
	printf ("  error %ld\n", r);
	errors++;
    }
}

int main (void)
{
    char env[64], tail[32];
    long st0, tt0, st1, tt1, size;
    int len, h, old;
    BASEPAGE *bp;

    /* (the C library takes its memory for the heap at the first output) */
    printf ("CHAIN: at %08lx\n", (long) _base);
    fflush (stdout);
    st0 = Mxalloc (-1L, 0);
    tt0 = Mxalloc (-1L, 1);
    printf (" largest free block: ST %ld, TT %ld\n", st0, tt0);

    printf (" load and go (mode 0), environments of 2 to 9 bytes:\n");
    for (len = 2; len <= 9; len++)
    {
	setup (env, tail, len, "go-env");
	fflush (stdout);
	result (Pexec (0, CHILD, tail, env));
    }

    printf (" load and go with our own environment:\n");
    setup (env, tail, 0, "inherit");
    fflush (stdout);
    result (Pexec (0, CHILD, tail, 0L));

    printf (" load (mode 3), then go (mode 4):\n");
    for (len = 4; len <= 7; len++)
    {
	setup (env, tail, len, "load-env");
	fflush (stdout);
	bp = (BASEPAGE *) Pexec (3, CHILD, tail, env);
	if ((long) bp <= 0)
	{
	    result ((long) bp);
	    continue;
	}
	result (Pexec (4, 0L, (char *) bp, 0L));
	Mfree (bp->p_env);
	Mfree (bp);
    }

    printf (" load and go with standard output in a file:\n");
    setup (env, tail, 5, "file-env");
    fflush (stdout);
    h = Fcreate ("\\OUT.TXT", 0);
    old = Fdup (1);
    Fforce (1, h);
    result (Pexec (0, CHILD, tail, env));
    Fforce (1, old);
    Fclose (old);
    Fclose (h);
    size = -1;
    h = Fopen ("\\OUT.TXT", 0);
    if (h >= 0)
    {
	size = Fread (h, sizeof env - 1, env);
	Fclose (h);
    }
    if (size > 0)
    {
	env[size] = 0;
	printf ("  its file holds %ld bytes: %s", size, env);
    }
    else
    {
	printf ("  ITS FILE IS EMPTY (%ld)\n", size);
	errors++;
    }
    Fdelete ("\\OUT.TXT");

    st1 = Mxalloc (-1L, 0);
    tt1 = Mxalloc (-1L, 1);
    printf ("CHAIN: %d loads, %d off a long word, %d errors; memory %s\n", loads, off,
	    errors, st1 == st0 && tt1 == tt0 ? "as before" : "NOT AS BEFORE");
    if (st1 != st0 || tt1 != tt0)
	printf ("  largest free block was ST %ld, TT %ld, now ST %ld, TT %ld\n", st0, tt0, st1, tt1);
    return 0;
}

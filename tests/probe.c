/* How does this TOS place a program? Makes basepages (Pexec mode 7) with
 * different program flags and environment lengths, and prints where the
 * environment copy and the basepage land. Each basepage is then run as a
 * process that only terminates, so nothing is left behind. */
#include <stdio.h>
#include <string.h>
#include <mint/osbind.h>
#include <mint/basepage.h>

extern void exit_stub(void);
__asm__("_exit_stub: clr.w -(sp)\n trap #1\n");

static long largest(int mode)
{
    long n = Mxalloc(-1L, mode), p;
    if (n <= 0) return 0;
    p = Mxalloc(n, mode);
    if (p > 0) Mfree(p);
    return p;
}

int main(void)
{
    static const long flagset[] = { 0, 1, 2, 4, 7 };
    char env[64];
    int f, len;

    printf("phystop %08lx  ST largest at %08lx (%ld)  TT largest at %08lx (%ld)\n",
           *(long *)0x42eL == 0 ? 0L : 0L, largest(0), Mxalloc(-1L, 0), largest(1), Mxalloc(-1L, 1));
    for (f = 0; f < 5; f++)
        for (len = 2; len <= 9; len++)
        {
            long st = largest(0), tt = largest(1);
            BASEPAGE *bp;
            /* an environment of len bytes, its two NULs included */
            memset(env, 'A', sizeof env);
            env[len - 2] = 0; env[len - 1] = 0;
            if (len > 3) env[1] = '=';
            bp = (BASEPAGE *) Pexec(7, (char *) flagset[f], "", env);
            if ((long) bp <= 0) { printf("flags %ld len %d: error %ld\n", flagset[f], len, (long) bp); continue; }
            printf("flags %ld len %d: env %08lx bp %08lx (bp-env %ld, bp-STlargest %ld, bp-TTlargest %ld) hitpa %08lx\n",
                   flagset[f], len, (long) bp->p_env, (long) bp, (long) bp - (long) bp->p_env,
                   (long) bp - st, (long) bp - tt, (long) bp->p_hitpa);
            bp->p_tbase = (char *) exit_stub;
            Pexec(6, 0L, (char *) bp, 0L);
        }
    printf("done\n");
    return 0;
}

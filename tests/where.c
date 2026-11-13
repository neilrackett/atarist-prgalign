/* Says where it was loaded. Exit code 1 if its basepage is 2 bytes off a
 * long word. The first argument is a label for the line. */
#include <stdio.h>
#include <mint/basepage.h>

int main (int argc, char **argv)
{
    long bp = (long) _base;
    int local;

    printf ("  %-10s basepage %08lx stack %08lx  %s\n", argc > 1 ? argv[1] : "",
	    bp, (long) &local, (bp & 3) ? "2 BYTES OFF" : "on a long word");
    return (bp & 3) ? 1 : 0;
}

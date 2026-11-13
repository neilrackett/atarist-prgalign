#!/bin/bash
# run-tests.sh: PRGALIGN under Hatari. Builds floppy images (mtools) and a
# hard disk folder whose AUTO folders run CHAIN.PRG, with and without
# PRGALIGN.PRG in front of it, boots them on each machine and prints what
# CHAIN counted. From a floppy TOS loads the programs itself; from the
# folder Hatari's GEMDOS drive does, as a hard disk driver that loads
# programs itself would.
# Work files: $WORK (default a new temporary folder). Up to two Hatari run
# at a time. See hrun.sh for the TOS images.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$HERE/..
WORK=${WORK:-$(mktemp -d)}
mkdir -p "$WORK"

floppy() {	# floppy IMAGE PROGRAMS-FOR-AUTO...
  local img=$1; shift
  rm -f "$img"
  dd if=/dev/zero of="$img" bs=1024 count=720 2>/dev/null
  mformat -i "$img" -f 720 ::
  mmd -i "$img" ::AUTO
  # (the AUTO folder's programs run in the order they were copied)
  n=0
  for f in "$@"; do n=$((n + 1)); mcopy -i "$img" "$f" "::AUTO/P$n.PRG"; done
  mcopy -i "$img" "$HERE/WHERE.TOS" ::
}
folder() {	# folder DIR PROGRAMS-FOR-AUTO...
  local d=$1; shift
  rm -rf "$d"; mkdir -p "$d/AUTO"
  n=0
  for f in "$@"; do n=$((n + 1)); cp "$f" "$d/AUTO/P$n.PRG"; done
  cp "$HERE/WHERE.TOS" "$d/"
}
P=$ROOT/PRGALIGN.PRG; C=$HERE/CHAIN.PRG
floppy "$WORK/without.st" "$C"
floppy "$WORK/with.st" "$P" "$C"
floppy "$WORK/twice.st" "$P" "$P" "$C"
folder "$WORK/hd-without" "$C"
folder "$WORK/hd-with" "$P" "$C"

run() {		# run NAME SECONDS MACHINE HD FLOPPY
  "$HERE/hrun.sh" "$4" - "$2" "$3" "$5" > "$WORK/$1.out" 2>&1
}
show() {
  for n in "$@"; do
    printf '%-22s %s\n' "$n" "$(grep -a 'PRGALIGN\|nstalled\|CHAIN: [0-9]\|SKIPPED\|largest free block was\|Panic\|rror' "$WORK/$n.out" | grep -av 'PRGALIGN 1' | tr '\n' ' ' | cut -c1-150)"
  done
}
pair() { run "$@" & shift 5; run "$@"; wait; }

#    name              secs machine   hard disk          floppy
pair tt-floppy-without 110 tt        -                  "$WORK/without.st" \
     tt-floppy-with    110 tt        -                  "$WORK/with.st"
pair tt-hd-without      40 tt        "$WORK/hd-without" "" \
     tt-hd-with         40 tt        "$WORK/hd-with"    ""
pair tt4-floppy-with   110 tt4       -                  "$WORK/with.st" \
     tt-floppy-twice   110 tt        -                  "$WORK/twice.st"
pair st030-floppy-without 150 st030  -                  "$WORK/without.st" \
     st030-floppy-with    150 st030  -                  "$WORK/with.st"
pair ste-floppy-with   150 ste       -                  "$WORK/with.st" \
     falcon-hd-with     40 falcon    "$WORK/hd-with"    ""
run  falcon404-hd-with  40 falcon404 "$WORK/hd-with"    ""
show tt-floppy-without tt-floppy-with tt-hd-without tt-hd-with tt4-floppy-with \
     tt-floppy-twice st030-floppy-without st030-floppy-with ste-floppy-with \
     falcon-hd-with falcon404-hd-with
echo "(full output: $WORK/*.out)"

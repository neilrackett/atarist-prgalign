#!/bin/bash
# hrun.sh HD AUTOSTART SECONDS [MACHINE] [FLOPPY]: boots Hatari with folder HD
# as drive C: (or FLOPPY as drive A: and no hard disk if HD is "-"), starts
# AUTOSTART (e.g. C:\TEST.TOS; "-" for none), waits SECONDS and prints what
# the machine wrote to its console. MACHINE: tt (TOS 3.06, 2 MB + 4 MB
# TT-RAM, the default), tt4 (4 MB ST-RAM only), st030 (TOS 2.06 on a Mega
# STE with a 68030, as an accelerated ST has), ste (TOS 1.62, 68000),
# falcon (EmuTOS), falcon404 (TOS 4.04).
# TOS images: $TOSDIR (default ../../tos, i.e. tmp/tos in ataritt-doom):
# tos306uk.img, tos206uk.img, tos162uk.img; $ETOS512 and $TOS404 for the
# Falcon's.
HD=$1; AUTO=$2; SECS=${3:-20}; MACHINE=${4:-tt}; FLOPPY=${5:-}
HERE=$(cd "$(dirname "$0")" && pwd)
TOSDIR=${TOSDIR:-$HERE/../../tos}
HATARI=${HATARI:-$(command -v hatari || echo /Applications/Hatari.app/Contents/MacOS/hatari)}
W=$(mktemp -d)
case $MACHINE in
  tt)  M="--tos $TOSDIR/tos306uk.img --machine tt --mmu off --monitor vga --memsize 2 --ttram 4 --addr24 off" ;;
  tt4) M="--tos $TOSDIR/tos306uk.img --machine tt --mmu off --monitor vga --memsize 4" ;;
  st030) M="--tos $TOSDIR/tos206uk.img --machine megaste --cpulevel 3 --memsize 4" ;;
  ste) M="--tos $TOSDIR/tos162uk.img --machine ste --memsize 4" ;;
  falcon) M="--tos ${ETOS512:-$TOSDIR/etos512uk.img} --machine falcon --monitor vga --memsize 14" ;;
  falcon404) M="--tos ${TOS404:-$TOSDIR/tos404uk.img} --machine falcon --monitor vga --memsize 14" ;;
  *) echo "unknown machine $MACHINE" >&2; exit 2 ;;
esac
set -- $M
[ -f "$2" ] || { echo "SKIPPED: no TOS image $2"; exit 0; }
D=; [ "$HD" != - ] && D="--harddrive $HD"
[ -n "$FLOPPY" ] && D="$D --disk-a $FLOPPY --drive-a on"
A=; [ "$AUTO" != - ] && A="--auto $AUTO"
: > "$W/cfg"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy "$HATARI" --configfile "$W/cfg" $M \
  --cpu-exact on --fast-forward on --confirm-quit false --fast-boot on --sound off \
  --statusbar off --alert-level fatal --conout 2 --cmd-fifo "$W/fifo" $D $A ${HEXTRA:-} \
  < /dev/null > "$W/log" 2>&1 &
HP=$!
sleep "$SECS"
# KEYS: scancodes to press then, a second apart, with 8 seconds for their effect
for k in ${KEYS:-}; do echo "hatari-event keypress $k" > "$W/fifo"; sleep 1; done
[ -n "${KEYS:-}" ] && sleep 8
# DBG: a debugger command to run before quitting (its output is printed too)
[ -n "${DBG:-}" ] && { echo "hatari-debug $DBG" > "$W/fifo"; sleep 1; }
kill -0 $HP 2>/dev/null && { echo "hatari-debug quit" > "$W/fifo"; sleep 1; }
kill -9 $HP 2>/dev/null
tr -d '\r' < "$W/log" | grep -av '^$' | grep -av '^INFO \|ApplePersistence\|No GEMDOS dir\|^> quit\|xconout\|GEMDOS hard disk emulation failed\|Can not access'
rm -rf "$W"

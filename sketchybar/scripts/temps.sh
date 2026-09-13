#!/usr/bin/env sh
# CPU temp via smctemp (Apple SMC reader, no sudo needed):
# https://github.com/narugit/smctemp

BIN="$(command -v smctemp 2>/dev/null)"
[ -n "$BIN" ] || BIN="/opt/homebrew/bin/smctemp"

if [ ! -x "$BIN" ]; then
  sketchybar --set "${NAME:-temp}" label="--°C"
  exit 0
fi

MEAN="$("$BIN" -c -f 2>/dev/null)"
[ -z "$MEAN" ] && exit 0

INT="$(printf '%.1f' "$MEAN" 2>/dev/null)"
case "$INT" in '' | *[!0-9.]*) exit 0 ;; esac

LABEL="${INT}°C"
WHOLE="${INT%%.*}"

if [ "$WHOLE" -ge 85 ]; then
  COLOR="0xFFbf616a"
elif [ "$WHOLE" -ge 75 ]; then
  COLOR="0xFF5e81ac"
else
  COLOR="0xFF88c0d0"
fi

sketchybar --set "${NAME:-temp}" label="$LABEL" icon.color="$COLOR"

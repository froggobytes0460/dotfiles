#!/bin/sh
# now_playing.sh: SketchyBar item script (POSIX sh, no bashisms).
# Serves the main track item plus the optional control siblings
# (<base>.sep / .prev / .toggle / .next); $NAME tells them apart.
# Backed by `nowplaying-cli` (github.com/kirtan-shah/nowplaying-cli), a thin
# MediaRemote CLI with no daemon/push mode: every tick polls it directly.
# Env from SketchyBar: $NAME (item), $SENDER (event), plus trigger payload:
#   $TITLE $ARTIST $PLAYING $LABEL
# Also handles `routine` ticks and mouse clicks.
#
# Dispatch is O(1) on $SENDER, then on the $NAME suffix; every branch is
# a single action.

BIN="nowplaying-cli"
if ! command -v "$BIN" >/dev/null 2>&1; then
  for dir in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    if [ -x "$dir/nowplaying-cli" ]; then
      BIN="$dir/nowplaying-cli"
      break
    fi
  done
fi

# Idle fallback text; while the bar shows this (or nothing), no track exists.
PLACEHOLDER="Play Something"

ICON_PLAY=""
ICON_PAUSE=""
ICON_PREV=""
ICON_NEXT=""

set_label() {
  # $1=label $2=playing ("true" scrolls, anything else stays put).
  # Sticky last track: empty label means idle, never hide. Keep the previous
  # label, only stop motion. No `drawing` change, so the wiring-time
  # placeholder stays until the first track.
  if [ -z "$1" ]; then
    sketchybar --set "$NAME" scroll_texts=off
  elif [ "$2" = "true" ]; then
    sketchybar --set "$NAME" label="$1" scroll_texts=on drawing=on
  else
    sketchybar --set "$NAME" label="$1" scroll_texts=off drawing=on
  fi
}

set_control() {
  # $1=icon. Sticky: idle (empty $LABEL) refreshes the glyph but leaves
  # `drawing` untouched, so the placeholder and controls stay exactly as
  # the wiring left them until the first track.
  if [ -z "${LABEL:-}" ]; then
    sketchybar --set "$NAME" icon="$1"
  else
    sketchybar --set "$NAME" icon="$1" drawing=on
  fi
}

set_sep() {
  # Sticky: idle leaves the separator exactly as-is (no `drawing` change).
  if [ -z "${LABEL:-}" ]; then
    :
  else
    sketchybar --set "$NAME" label="|" drawing=on
  fi
}

# True when no player exists, so media commands must not fire: a stray
# toggle with no active client wakes Apple Music. Ground truth is the
# displayed main-item label; a query failure also blocks (a missed click
# is harmless, a stray launch is not).
is_idle() {
  # $1=base item (callers resolve control siblings to the main item).
  current="$(sketchybar --query "$1" 2>/dev/null | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["label"]["value"])' 2>/dev/null)" || return 0
  [ -z "$current" ] || [ "$current" = "$PLACEHOLDER" ]
}

toggle_glyph() {
  if [ "${PLAYING:-}" = "true" ]; then
    printf '%s' "$ICON_PAUSE"
  else
    printf '%s' "$ICON_PLAY"
  fi
}

# Polls nowplaying-cli and fans the result out to the main item plus
# control siblings via a trigger, mirroring what a push daemon would have
# sent. playbackRate is the playing/paused bit: 1 while playing, null when
# paused (isPlaying and elapsedTime are unreliable/stale on this system).
do_sync() {
  base="${NAME%.*}"
  info="$("$BIN" get --json title artist playbackRate 2>/dev/null)" || info=""
  title="$(printf '%s' "$info" | /usr/bin/python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get("title") or "")
except Exception:
    print("")' 2>/dev/null)"
  artist="$(printf '%s' "$info" | /usr/bin/python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get("artist") or "")
except Exception:
    print("")' 2>/dev/null)"
  rate="$(printf '%s' "$info" | /usr/bin/python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    v=d.get("playbackRate")
    print(v if v is not None else "")
except Exception:
    print("")' 2>/dev/null)"

  playing="false"
  if [ -n "$title" ] && [ -n "$rate" ] && [ "$rate" != "0" ]; then
    playing="true"
  fi

  if [ -n "$title" ]; then
    if [ -n "$artist" ]; then
      label="$artist - $title"
    else
      label="$title"
    fi
  else
    label=""
  fi

  if [ "$playing" = "true" ]; then
    toggle_icon="$ICON_PAUSE"
  else
    toggle_icon="$ICON_PLAY"
  fi

  sketchybar --trigger now_playing_change NAME="$base" LABEL="$label" PLAYING="$playing" TOGGLE_ICON="$toggle_icon" >/dev/null 2>&1
}

handle_event() {
  case "$NAME" in
  *.prev)
    set_control "$ICON_PREV"
    ;;
  *.toggle)
    set_control "${TOGGLE_ICON:-$(toggle_glyph)}"
    ;;
  *.next)
    set_control "$ICON_NEXT"
    ;;
  *.sep)
    set_sep
    ;;
  *)
    set_label "$LABEL" "$PLAYING"
    ;;
  esac
}

handle_click() {
  # Control siblings always fire their own action; the main item keeps
  # left toggle / right skip. No optimistic scroll flip: `scroll_texts`
  # strictly follows the derived PLAYING ground truth via the change event
  # and the sync tick, so a click never starts motion on its own.
  case "$NAME" in
  *.sep | *.prev | *.toggle | *.next) base="${NAME%.*}" ;;
  *) base="$NAME" ;;
  esac
  # Dead clicks when idle: with no player loaded every media command is a
  # no-op at best and wakes Apple Music at worst. Controls resolve to the
  # main item, whose label carries the idle state.
  if is_idle "$base"; then
    return
  fi
  case "$NAME" in
  *.prev)
    "$BIN" previous >/dev/null 2>&1
    ;;
  *.toggle)
    "$BIN" togglePlayPause >/dev/null 2>&1
    ;;
  *.next)
    "$BIN" next >/dev/null 2>&1
    ;;
  *)
    if [ "${BUTTON:-left}" = "right" ]; then
      "$BIN" next >/dev/null 2>&1
    else
      "$BIN" togglePlayPause >/dev/null 2>&1
    fi
    ;;
  esac
  sleep 0.2
  NAME="$base" do_sync
}

case "$SENDER" in
mouse.clicked)
  # Fire and forget; the next routine/change event converges the bar,
  # so no output parsing here.
  handle_click
  ;;
routine | forced | "")
  # Periodic tick, post-reload convergence, or initial run (empty $SENDER):
  # always poll and push label + scroll state, showing the placeholder on
  # idle instead of hiding. Only the main item polls; siblings just re-render
  # off the trigger this sends.
  case "$NAME" in
  *.sep | *.prev | *.toggle | *.next) : ;;
  *) do_sync ;;
  esac
  ;;
*)
  # The subscribed now_playing_change event, fired by do_sync above.
  handle_event
  ;;
esac

#!/bin/sh
# space.sh: per-space selected styling (runs on $SELECTED change + --update).
# Active space gets a solid sun-gold chip with dark text (theme accent);
# inactive spaces are plain gray numbers. The number is never covered,
# so it can't disappear like it did under the old sliding dot.
# Env from SketchyBar: $NAME (item), $SELECTED ("true"/"false").

if [ "$SELECTED" = "true" ]; then
  sketchybar --set "$NAME" background.drawing=on \
                           background.color=0xFF5e81ac \
                           icon.color=0xFF2e3440
else
  sketchybar --set "$NAME" background.drawing=off \
                           icon.color=0xFF81a1c1
fi

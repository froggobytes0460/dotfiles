TITLE=$(yabai -m query --windows --window 2>/dev/null)
if [ -z "$TITLE" ]; then
    exit 0
fi

LABEL="$(echo "$TITLE" | jq -r '.title // empty')"
if [ -z "$LABEL" ]; then
    exit 0
fi

if [ "$(sketchybar --query title | jq -r '.label.value')" != "$LABEL" ]; then
    sketchybar --set title y_offset=70            \
                --set title y_offset=7            \
             --set title y_offset=0 && sketchybar --set title label="$LABEL"
fi
#!/bin/bash

OUTPUT_FILE="${1:-~/sway-profiles/saved-$(date +%Y%m%d-%H%M%S).sh}"

echo "#!/bin/bash" > "$OUTPUT_FILE"

swaymsg -t get_outputs | jq -r '.[] |
  "swaymsg output \(.name) " +
  (if .active then "enable" else "disable" end) +
  (if .active then
    " position \(.rect.x),\(.rect.y) resolution \(.current_mode.width)x\(.current_mode.height) scale \(.scale)"
  else "" end)' >> "$OUTPUT_FILE"

chmod +x "$OUTPUT_FILE"
echo "Profile saved to: $OUTPUT_FILE"

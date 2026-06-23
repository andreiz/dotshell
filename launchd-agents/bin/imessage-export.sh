#!/bin/bash
#
# Monthly iMessage export. Run by org.zmievski.imessage-export via launchd,
# routed through AgentRunnerFDA.app so it inherits Full Disk Access (needed to
# read ~/Library/Messages/chat.db).
#
# Exports the previous calendar month for a fixed set of threads to HTML with
# cloned attachments, downsizes images, and pings Home Assistant with a summary.

set -uo pipefail

export PATH="/opt/homebrew/bin:$PATH"

HA_URL="https://hass.local.zmievski.org"
# HA long-lived token lives in the Keychain (not in this file):
#   security add-generic-password -s ha-imessage-export -a "$USER" -w
HA_TOKEN="$(security find-generic-password -s ha-imessage-export -w 2>/dev/null)"

EXPORT_BASE="$HOME/imessage-export"
EXPORT_DIR="$EXPORT_BASE/monthly/$(date +%Y-%m)"
LOG="$EXPORT_BASE/export.log"
START_DATE=$(date -v-1m +%Y-%m-01)
END_DATE=$(date +%Y-%m-01)

THREADS="sean@seancoates.com,+15144026950,tanyazmi@yandex.ru,boneill428@gmail.com,+16282229174,goryn4@yahoo.com,zmey2024@vk.com,+79002476225,+19782391611"

ha_notify() {
  [ -n "$HA_TOKEN" ] || return 0
  curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"message\": \"$1\", \"title\": \"iMessage Export\"}" \
    "$HA_URL/api/services/notify/mobile_app_az_phone" >/dev/null
}

mkdir -p "$EXPORT_DIR"

if [ -z "$HA_TOKEN" ]; then
  echo "$(date): WARNING — no HA token in Keychain (service ha-imessage-export); notifications disabled" >> "$LOG"
fi

imessage-exporter -f html -c clone -t "$THREADS" \
  -s "$START_DATE" -e "$END_DATE" \
  -o "$EXPORT_DIR"

if [ $? -ne 0 ]; then
  echo "$(date): imessage-exporter failed" >> "$LOG"
  ha_notify "Export failed — check stderr log"
  rm -rf "$EXPORT_DIR"
  exit 1
fi

# Downsize attachment images in place.
find "$EXPORT_DIR" -path '*/attachments/*' \
  \( -iname '*.jpeg' -o -iname '*.jpg' -o -iname '*.png' -o -iname '*.heic' \) \
  -exec sips --resampleHeightWidthMax 1200 {} \;

# Remove orphaned conversation file.
rm -f "$EXPORT_DIR/orphaned.html"

# Nothing exported this month -> clean up and report.
if [ -z "$(find "$EXPORT_DIR" -name '*.html' -print -quit)" ]; then
  rm -rf "$EXPORT_DIR"
  echo "$(date): No messages to export, cleaned up $EXPORT_DIR" >> "$LOG"
  ha_notify "No messages to export this month"
  exit 0
fi

# Count videos to review.
VIDEO_COUNT=$(find "$EXPORT_DIR" -path '*/attachments/*' \
  \( -iname '*.mov' -o -iname '*.mp4' -o -iname '*.m4v' \) | wc -l | tr -d ' ')

if [ "$VIDEO_COUNT" -gt 0 ]; then
  VIDEO_SIZE=$(find "$EXPORT_DIR" -path '*/attachments/*' \
    \( -iname '*.mov' -o -iname '*.mp4' -o -iname '*.m4v' \) \
    -exec stat -f '%z' {} + | awk '{s+=$1} END {printf "%.0f", s/1048576}')
  ha_notify "Export complete — $VIDEO_COUNT videos (${VIDEO_SIZE}MB) to review"
else
  ha_notify "Export complete — no videos to review"
fi

echo "$(date): Export complete — $EXPORT_DIR" >> "$LOG"

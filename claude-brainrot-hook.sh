#!/bin/bash
# =============================================================================
# Claude Code Brainrot Killer Hook
# =============================================================================
# Triggered by Claude Code's idle_prompt notification (after 60s idle).
# Pauses media, warns user, then kills distracting apps after 60 more seconds.
#
# HOOK CONFIG: Notification[idle_prompt]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KILL_MARKER="/tmp/claude-brainrot-kill"

# DEBUG LOGGING
LOG="/tmp/claude-brainrot-debug.log"
echo "=== $(date) ===" >> "$LOG"
JSON_INPUT=$(cat)
echo "JSON_INPUT: $JSON_INPUT" >> "$LOG"
echo "SCRIPT_DIR: $SCRIPT_DIR" >> "$LOG"

if [[ -f "$SCRIPT_DIR/.notifications-disabled" ]]; then
    echo "Notifications disabled, exiting" >> "$LOG"
    exit 0
fi

echo "Proceeding with brainrot hook" >> "$LOG"

# -----------------------------------------------------------------------------
# MUTE SYSTEM AUDIO
# -----------------------------------------------------------------------------

echo "Muting system audio..." >> "$LOG"
osascript -e 'set volume output muted true' 2>/dev/null

# -----------------------------------------------------------------------------
# SEND WARNING NOTIFICATION
# -----------------------------------------------------------------------------

echo "Sending notification..." >> "$LOG"
"$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier" \
  -title "Claude Code" \
  -message "One minute to respond before brainrot killed"

# -----------------------------------------------------------------------------
# START KILL TIMER (60 seconds)
# -----------------------------------------------------------------------------

echo "Starting 60s kill timer" >> "$LOG"
MY_TIMESTAMP=$(date +%s)
echo "$MY_TIMESTAMP" > "$KILL_MARKER"

(
  sleep 60

  if [[ -f "$KILL_MARKER" ]]; then
    CURRENT_TIMESTAMP=$(cat "$KILL_MARKER" 2>/dev/null)

    # Only proceed if we're still the latest idle event
    # (newer events would have overwritten the marker with a different timestamp)
    if [[ "$MY_TIMESTAMP" == "$CURRENT_TIMESTAMP" ]]; then
      rm -f "$KILL_MARKER" 2>/dev/null

      # Force kill distracting apps
      pkill -9 -x Safari
      pkill -9 -x Spotify
      pkill -9 -x VLC
      pkill -9 -x Podcasts

      # Unmute after kill (brainrot sources are dead)
      osascript -e 'set volume output muted false' 2>/dev/null
      echo "$(date): Apps killed, audio unmuted" >> "$LOG"
    else
      echo "$(date): Kill skipped (newer idle event exists: $CURRENT_TIMESTAMP vs $MY_TIMESTAMP)" >> "$LOG"
    fi
  else
    echo "$(date): Kill cancelled (marker removed)" >> "$LOG"
  fi
) &

echo "Hook complete, background timer started" >> "$LOG"
exit 0

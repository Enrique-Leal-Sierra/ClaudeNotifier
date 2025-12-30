#!/bin/bash
# =============================================================================
# Claude Code Brainrot Killer Hook
# =============================================================================
# Triggered by Claude Code's idle_prompt notification (after 60s idle).
# Pauses media, warns user, then kills ALL apps after 5 more minutes.
# MAXIMUM PENALTY MODE: Kills EVERYTHING. No mercy.
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
  -message "5 minutes to respond before ALL APPS KILLED"

# -----------------------------------------------------------------------------
# START KILL TIMER (5 minutes)
# -----------------------------------------------------------------------------

echo "Starting 5min kill timer" >> "$LOG"
MY_TIMESTAMP=$(date +%s)
echo "$MY_TIMESTAMP" > "$KILL_MARKER"

(
  sleep 300

  if [[ -f "$KILL_MARKER" ]]; then
    CURRENT_TIMESTAMP=$(cat "$KILL_MARKER" 2>/dev/null)

    # Only proceed if we're still the latest idle event
    # (newer events would have overwritten the marker with a different timestamp)
    if [[ "$MY_TIMESTAMP" == "$CURRENT_TIMESTAMP" ]]; then
      rm -f "$KILL_MARKER" 2>/dev/null

      # MAXIMUM PENALTY: Kill ALL apps. No exceptions. No mercy.
      osascript <<'APPLESCRIPT' 2>/dev/null
tell application "System Events"
    set appList to name of every application process whose background only is false
    repeat with appName in appList
        try
            do shell script "pkill -9 -x " & quoted form of (appName as text)
        end try
    end repeat
end tell
APPLESCRIPT
      # Kill Finder too (it will auto-restart but closes all windows)
      pkill -9 -x Finder

      # Unmute after kill
      osascript -e 'set volume output muted false' 2>/dev/null
      echo "$(date): ALL APPS KILLED (maximum penalty), audio unmuted" >> "$LOG"
    else
      echo "$(date): Kill skipped (newer idle event exists: $CURRENT_TIMESTAMP vs $MY_TIMESTAMP)" >> "$LOG"
    fi
  else
    echo "$(date): Kill cancelled (marker removed)" >> "$LOG"
  fi
) &

echo "Hook complete, background timer started" >> "$LOG"
exit 0

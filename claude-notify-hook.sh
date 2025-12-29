#!/bin/bash
# =============================================================================
# Claude Code Notification Hook
# =============================================================================
# Sends macOS notifications when Claude finishes responding.
#
# DEFENSIVE PATTERNS USED:
# ------------------------
# - Stdin is piped from wrapper (already validated), but we still check
# - All external commands (osascript, jq, afplay) have error suppression
# - Background processes are spawned for delayed notifications
# - Always exits 0 to not block Claude Code
#
# CALLED BY: claude-stop-wrapper.sh (not directly by Claude Code)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELAYED_MARKER="/tmp/claude-notify-pending"
DELAY_SECONDS=60

# -----------------------------------------------------------------------------
# PARSE INPUT
# -----------------------------------------------------------------------------
# Note: When called via wrapper, stdin is already validated JSON.
# When called directly, stdin might be empty - handle gracefully.

JSON_INPUT=$(cat)

# Early exit if no input (defensive - wrapper should prevent this)
if [[ -z "$JSON_INPUT" ]]; then
    exit 0
fi

# Check if notifications are disabled
if [[ -f "$SCRIPT_DIR/.notifications-disabled" ]]; then
    exit 0
fi
# Extract fields with defaults (jq's // provides fallback for null/missing)
HOOK_EVENT=$(echo "$JSON_INPUT" | jq -r '.hook_event_name // "unknown"')
TRANSCRIPT_PATH=$(echo "$JSON_INPUT" | jq -r '.transcript_path // ""')
SESSION_ID=$(echo "$JSON_INPUT" | jq -r '.session_id // ""')

# -----------------------------------------------------------------------------
# BUILD NOTIFICATION MESSAGE
# -----------------------------------------------------------------------------
case "$HOOK_EVENT" in
  "Stop")
    TITLE="Claude Code"
    # Extract last assistant message from transcript
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
      MSG=$(tail -5 "$TRANSCRIPT_PATH" | jq -rs '[.[] | select(.type=="assistant")] | last | .message.content[0].text // "Response complete"' 2>/dev/null | head -c 100)
    fi
    MESSAGE="${MSG:-Response complete}"
    ;;
  "Notification")
    TITLE="Claude Code"
    MESSAGE=$(echo "$JSON_INPUT" | jq -r '.message // "Needs attention"')
    ;;
  *)
    TITLE="Claude Code"
    MESSAGE="Needs attention"
    ;;
esac

# -----------------------------------------------------------------------------
# FOCUS AWARENESS
# -----------------------------------------------------------------------------
# If user is focused on a terminal/IDE, delay notification by 60 seconds.
#
# WARNING: osascript can occasionally hang. The 2>/dev/null suppresses errors,
# but if it blocks, the wrapper's 5-second watchdog will kill this process.
# This is acceptable - missing one notification is better than blocking Claude.

FRONTMOST=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)

send_notification() {
    "$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier" \
      -title "$1" \
      -message "$2"
}

# -----------------------------------------------------------------------------
# MUSIC MODE
# -----------------------------------------------------------------------------
# Special mode: Always delay notification and play audio when Claude finishes.
# The background subshell sleeps for 60 seconds before checking if Claude is
# still idle. This is spawned with & so it doesn't block the hook.
#
# NOTE: Background processes survive after this script exits. They handle their
# own cleanup and race condition prevention via the marker file.

MUSIC_FLAG="$SCRIPT_DIR/.music-mode-enabled"
if [[ -f "$MUSIC_FLAG" ]]; then
    # Music mode: Always start 60-second timer, regardless of focus
    TRANSCRIPT_MTIME=""
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
      TRANSCRIPT_MTIME=$(stat -f %m "$TRANSCRIPT_PATH" 2>/dev/null)
    fi
    # Store start time for duration-based logic
    START_TIME=$(date +%s)
    echo "${SESSION_ID}:${TRANSCRIPT_PATH}:${TRANSCRIPT_MTIME}:${START_TIME}" > "$DELAYED_MARKER"

    (
      sleep "$DELAY_SECONDS"

      # Re-check if notifications were disabled while we slept
      if [[ -f "$SCRIPT_DIR/.notifications-disabled" ]]; then
        exit 0
      fi

      if [[ -f "$DELAYED_MARKER" ]]; then
        SAVED=$(cat "$DELAYED_MARKER" 2>/dev/null)
        SAVED_MTIME=$(echo "$SAVED" | cut -d: -f3)
        SAVED_PATH=$(echo "$SAVED" | cut -d: -f2)
        SAVED_START=$(echo "$SAVED" | cut -d: -f4)

        CURRENT_MTIME=""
        if [[ -n "$SAVED_PATH" && -f "$SAVED_PATH" ]]; then
          CURRENT_MTIME=$(stat -f %m "$SAVED_PATH" 2>/dev/null)
        fi

        if [[ "$SAVED_MTIME" == "$CURRENT_MTIME" ]]; then
          # Atomically claim the marker - delete it first to prevent race conditions
          # If another process deleted it between our check and now, we skip
          if ! rm -f "$DELAYED_MARKER" 2>/dev/null || [[ -f "$DELAYED_MARKER" ]]; then
            exit 0
          fi

          # Calculate how long we've been waiting
          CURRENT_TIME=$(date +%s)
          WAIT_SECONDS=$((CURRENT_TIME - SAVED_START))

          # Kill any existing afplay to prevent overlap
          pkill -f "afplay" 2>/dev/null || true

          # Check which apps are currently playing (before pausing)
          WAS_PLAYING=$(osascript 2>/dev/null <<'APPLESCRIPT' || true
set wasPlaying to {}
tell application "System Events"
    set runningApps to name of every application process
end tell
if runningApps contains "Spotify" then
    tell application "Spotify"
        if player state is playing then
            set end of wasPlaying to "Spotify"
            pause
        end if
    end tell
end if
if runningApps contains "Music" then
    tell application "Music"
        if player state is playing then
            set end of wasPlaying to "Music"
            pause
        end if
    end tell
end if
if runningApps contains "VLC" then
    tell application "VLC"
        if playing then
            set end of wasPlaying to "VLC"
            play -- VLC toggles play/pause
        end if
    end tell
end if
if runningApps contains "QuickTime Player" then
    tell application "QuickTime Player"
        try
            if playing of document 1 then
                set end of wasPlaying to "QuickTime"
                pause document 1
            end if
        end try
    end tell
end if
return wasPlaying as text
APPLESCRIPT
)

          # Pick random audio file
          AUDIO_DIR="$HOME/Documents/Jarvis/Audio"
          ALL_FILES=$(find "$AUDIO_DIR" -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.mp4" -o -name "*.webm" \) 2>/dev/null)

          ALL_FILES_ARRAY=()
          while IFS= read -r file; do
            [[ -n "$file" ]] || continue
            ALL_FILES_ARRAY+=("$file")
          done <<< "$ALL_FILES"

          RANDOM_FILE=""
          # Filter by duration if waiting < 5 minutes (300 seconds)
          if [[ "$WAIT_SECONDS" -lt 300 ]]; then
            # Only pick files <= 60 seconds duration
            ELIGIBLE_FILES=()
            for file in "${ALL_FILES_ARRAY[@]}"; do
              DURATION=$(afinfo "$file" 2>/dev/null | grep "duration:" | awk '{print int($2)}')
              if [[ -n "$DURATION" && "$DURATION" -le 60 ]]; then
                ELIGIBLE_FILES+=("$file")
              fi
            done
            if (( ${#ELIGIBLE_FILES[@]} > 0 )); then
              RANDOM_FILE="${ELIGIBLE_FILES[$(( RANDOM % ${#ELIGIBLE_FILES[@]} ))]}"
            fi
          else
            # After 5+ minutes, any file is eligible
            if (( ${#ALL_FILES_ARRAY[@]} > 0 )); then
              RANDOM_FILE="${ALL_FILES_ARRAY[$(( RANDOM % ${#ALL_FILES_ARRAY[@]} ))]}"
            fi
          fi

          if [[ -n "$RANDOM_FILE" ]]; then
            FILENAME=$(basename "$RANDOM_FILE")
            TRUNCATED="${FILENAME:0:50}"
            [[ ${#FILENAME} -gt 50 ]] && TRUNCATED="${TRUNCATED}..."

            # Send notification with filename
            "$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier" \
              -title "Claude Code" \
              -message "$TRUNCATED"

            # Play audio and wait for it to finish
            afplay "$RANDOM_FILE"

            # Resume apps that were playing before
            if [[ -n "$WAS_PLAYING" ]]; then
              osascript 2>/dev/null <<APPLESCRIPT || true
tell application "System Events"
    set runningApps to name of every application process
end tell
if "${WAS_PLAYING}" contains "Spotify" and runningApps contains "Spotify" then
    tell application "Spotify" to play
end if
if "${WAS_PLAYING}" contains "Music" and runningApps contains "Music" then
    tell application "Music" to play
end if
if "${WAS_PLAYING}" contains "VLC" and runningApps contains "VLC" then
    tell application "VLC" to play
end if
if "${WAS_PLAYING}" contains "QuickTime" and runningApps contains "QuickTime Player" then
    tell application "QuickTime Player"
        try
            play document 1
        end try
    end tell
end if
APPLESCRIPT
            fi
          fi
        fi
      fi
    ) &

    exit 0  # Exit early - music mode handles everything
fi

case "$FRONTMOST" in
  Terminal|iTerm2|iTerm|Warp|kitty|Alacritty|WezTerm|ghostty|Ghostty|Hyper|Code|"Code - Insiders"|Cursor|Windsurf|Zed|zed)
    # User is on terminal/IDE - delay notification
    # Save marker with session info and transcript mod time
    TRANSCRIPT_MTIME=""
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
      TRANSCRIPT_MTIME=$(stat -f %m "$TRANSCRIPT_PATH" 2>/dev/null)
    fi
    echo "${SESSION_ID}:${TRANSCRIPT_PATH}:${TRANSCRIPT_MTIME}" > "$DELAYED_MARKER"

    # Spawn background process to send delayed notification
    (
      sleep "$DELAY_SECONDS"

      # Re-check if notifications were disabled while we slept
      if [[ -f "$SCRIPT_DIR/.notifications-disabled" ]]; then
        exit 0
      fi

      # Check if marker still exists and matches (no new activity)
      if [[ -f "$DELAYED_MARKER" ]]; then
        SAVED=$(cat "$DELAYED_MARKER" 2>/dev/null)
        SAVED_SESSION=$(echo "$SAVED" | cut -d: -f1)
        SAVED_PATH=$(echo "$SAVED" | cut -d: -f2)
        SAVED_MTIME=$(echo "$SAVED" | cut -d: -f3)

        # Check if transcript hasn't been modified (Claude still waiting)
        CURRENT_MTIME=""
        if [[ -n "$SAVED_PATH" && -f "$SAVED_PATH" ]]; then
          CURRENT_MTIME=$(stat -f %m "$SAVED_PATH" 2>/dev/null)
        fi

        if [[ "$SAVED_MTIME" == "$CURRENT_MTIME" ]]; then
          # No activity for 60 seconds - send reminder
          "$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier" \
            -title "Claude Code" \
            -message "Waiting for input"
          rm -f "$DELAYED_MARKER"
        fi
      fi
    ) &

    exit 0
    ;;
esac

# -----------------------------------------------------------------------------
# IMMEDIATE NOTIFICATION
# -----------------------------------------------------------------------------
# User is NOT on terminal/IDE - send notification immediately
send_notification "$TITLE" "$MESSAGE"

# -----------------------------------------------------------------------------
# CURATE INTEGRATION
# -----------------------------------------------------------------------------
# Auto-pause website blocking when Claude finishes (if timer is running)
CURATE_PATH="/usr/local/bin/curate"
if [[ -x "$CURATE_PATH" ]]; then
    CURATE_PID_FILE="/tmp/curate-relock.pid"
    if [[ -f "$CURATE_PID_FILE" ]]; then
        CURATE_PID=$(cat "$CURATE_PID_FILE" 2>/dev/null)
        if [[ -n "$CURATE_PID" ]] && kill -0 "$CURATE_PID" 2>/dev/null; then
            "$CURATE_PATH" --pause
        fi
    fi
fi

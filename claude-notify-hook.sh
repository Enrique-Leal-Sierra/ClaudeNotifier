#!/bin/bash
# Claude Code hook -> macOS notification via ClaudeNotifier

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELAYED_MARKER="/tmp/claude-notify-pending"
DELAY_SECONDS=30

# MARK: - Parse Input (must happen before focus check since stdin is consumed)
JSON_INPUT=$(cat)
HOOK_EVENT=$(echo "$JSON_INPUT" | jq -r '.hook_event_name // "unknown"')
TRANSCRIPT_PATH=$(echo "$JSON_INPUT" | jq -r '.transcript_path // ""')
SESSION_ID=$(echo "$JSON_INPUT" | jq -r '.session_id // ""')

# Build contextual message based on event type
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

# MARK: - Focus Awareness
# If user is focused on a terminal, delay notification by 30 seconds
FRONTMOST=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)

send_notification() {
    "$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier" \
      -title "$1" \
      -message "$2"
}

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
          # No activity for 30 seconds - send reminder
          "$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier" \
            -title "Claude Code" \
            -message "Still waiting for input..."
          rm -f "$DELAYED_MARKER"
        fi
      fi
    ) &

    exit 0
    ;;
esac

# User is NOT on terminal - send notification immediately
send_notification "$TITLE" "$MESSAGE"

# MARK: - Curate Integration
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

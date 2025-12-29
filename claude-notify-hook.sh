#!/bin/bash
# Claude Code hook -> macOS notification via ClaudeNotifier

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# MARK: - Focus Awareness
# Skip notification if user is focused on a terminal (they're already watching)
FRONTMOST=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)

case "$FRONTMOST" in
  Terminal|iTerm2|iTerm|Warp|kitty|Alacritty|WezTerm|ghostty|Ghostty|Hyper)
    exit 0
    ;;
  Code|"Code - Insiders"|Cursor|Windsurf|Zed|zed)
    # IDE with integrated terminal - assume user is watching
    exit 0
    ;;
esac

# MARK: - Parse Input
JSON_INPUT=$(cat)
HOOK_EVENT=$(echo "$JSON_INPUT" | jq -r '.hook_event_name // "unknown"')
TRANSCRIPT_PATH=$(echo "$JSON_INPUT" | jq -r '.transcript_path // ""')

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

# Send notification
"$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier" \
  -title "$TITLE" \
  -message "$MESSAGE"

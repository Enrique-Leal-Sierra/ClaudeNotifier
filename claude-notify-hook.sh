#!/bin/bash
# =============================================================================
# Claude Code Notification Hook
# =============================================================================
# Sends macOS notifications when Claude finishes responding.
# Just immediate notification - brainrot killer handled by separate hook.
#
# CALLED BY: claude-stop-wrapper.sh (not directly by Claude Code)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JSON_INPUT=$(cat)

if [[ -z "$JSON_INPUT" ]]; then
    exit 0
fi

if [[ -f "$SCRIPT_DIR/.notifications-disabled" ]]; then
    exit 0
fi

HOOK_EVENT=$(echo "$JSON_INPUT" | jq -r '.hook_event_name // "unknown"')
TRANSCRIPT_PATH=$(echo "$JSON_INPUT" | jq -r '.transcript_path // ""')

case "$HOOK_EVENT" in
  "Stop")
    TITLE="Claude Code"
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
      MSG=$(tail -5 "$TRANSCRIPT_PATH" | jq -rs '[.[] | select(.type=="assistant")] | last | .message.content[0].text // "Response complete"' 2>/dev/null | head -c 100)
    fi
    MESSAGE="${MSG:-Response complete}"
    ;;
  *)
    TITLE="Claude Code"
    MESSAGE="Needs attention"
    ;;
esac

"$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier" \
  -title "$TITLE" \
  -message "$MESSAGE"

exit 0

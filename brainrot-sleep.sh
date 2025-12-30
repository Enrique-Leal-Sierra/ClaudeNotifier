#!/bin/bash
# =============================================================================
# Brainrot Sleep - One-time daily snooze for the brainrot killer
# =============================================================================
# Cancels the pending kill timer and clears notifications.
# Can only be used ONCE per day. No exceptions.
# =============================================================================

# Resolve symlink to get actual script directory
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

KILL_MARKER="/tmp/claude-brainrot-kill"
SLEEP_USED_FILE="$SCRIPT_DIR/.brainrot-sleep-used"
TODAY=$(date +%Y-%m-%d)

# Check if already used today
if [[ -f "$SLEEP_USED_FILE" ]]; then
    LAST_USED=$(cat "$SLEEP_USED_FILE" 2>/dev/null)
    if [[ "$LAST_USED" == "$TODAY" ]]; then
        echo "brainrot-sleep: Already used today. No exceptions."
        exit 1
    fi
fi

# Check if there's actually a pending kill
if [[ ! -f "$KILL_MARKER" ]]; then
    echo "brainrot-sleep: No pending kill to cancel."
    exit 1
fi

# Mark as used today
echo "$TODAY" > "$SLEEP_USED_FILE"

# Cancel the kill timer
rm -f "$KILL_MARKER"

# Clear notifications (remove all from Claude Code group)
osascript -e 'tell application "System Events" to tell process "NotificationCenter" to click button 1 of every window' 2>/dev/null || true

# Unmute audio
osascript -e 'set volume output muted false' 2>/dev/null

echo "brainrot-sleep: Kill cancelled. You won't get another chance today."

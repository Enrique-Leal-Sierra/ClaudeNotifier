#!/bin/bash
# Toggle Claude notifications on/off

# Resolve symlink to get actual script directory
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
DISABLED_FLAG="$SCRIPT_DIR/.notifications-disabled"
NOTIFIER="$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier"

if [[ -f "$DISABLED_FLAG" ]]; then
    # Currently disabled -> enable
    rm -f "$DISABLED_FLAG"
    "$NOTIFIER" -title "Claude Notifications" -message "Enabled"
    echo "Claude notifications: enabled"
else
    # Currently enabled -> disable
    touch "$DISABLED_FLAG"
    "$NOTIFIER" -title "Claude Notifications" -message "Disabled"
    echo "Claude notifications: disabled"
fi

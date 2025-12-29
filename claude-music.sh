#!/bin/bash
# Toggle claude-music mode on/off

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
MUSIC_FLAG="$SCRIPT_DIR/.music-mode-enabled"
NOTIFIER="$SCRIPT_DIR/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier"

if [[ -f "$MUSIC_FLAG" ]]; then
    rm -f "$MUSIC_FLAG"
    "$NOTIFIER" -title "Claude Music" -message "Disabled"
    echo "Claude music mode: disabled"
else
    touch "$MUSIC_FLAG"
    "$NOTIFIER" -title "Claude Music" -message "Enabled"
    echo "Claude music mode: enabled"
fi

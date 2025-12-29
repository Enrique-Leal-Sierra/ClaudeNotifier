#!/bin/bash
# Wrapper that feeds stdin to both focusbase AND ClaudeNotifier

JSON_INPUT=$(cat)

# Run focusbase hook
echo "$JSON_INPUT" | /Users/enriqueleal-sierra/.focusbase/bin/focusbase-claude-stop.sh

# Run ClaudeNotifier hook
echo "$JSON_INPUT" | "$(dirname "$0")/claude-notify-hook.sh"

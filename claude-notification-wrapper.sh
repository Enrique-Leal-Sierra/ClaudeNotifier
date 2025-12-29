#!/bin/bash
# Wrapper that feeds stdin to both focusbase AND ClaudeNotifier

JSON_INPUT=$(cat)

# Run focusbase hook
echo "$JSON_INPUT" | /Users/enriqueleal-sierra/.focusbase/bin/focusbase-claude-notification.sh

# Run ClaudeNotifier hook
echo "$JSON_INPUT" | /Users/enriqueleal-sierra/Documents/ClaudeNotifier/claude-notify-hook.sh

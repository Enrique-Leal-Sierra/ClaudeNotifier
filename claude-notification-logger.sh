#!/bin/bash
# Logs ALL notifications to debug what Claude Code actually sends
LOG="/tmp/claude-notification-all.log"
echo "=== $(date) ===" >> "$LOG"
cat >> "$LOG"
echo "" >> "$LOG"
exit 0

#!/bin/bash
# =============================================================================
# Claude Code Cancel Kill Hook
# =============================================================================
# Triggered by UserPromptSubmit - cancels pending brainrot kill and unmutes.
#
# HOOK CONFIG: UserPromptSubmit
# =============================================================================

if [[ -f /tmp/claude-brainrot-kill ]]; then
    rm -f /tmp/claude-brainrot-kill 2>/dev/null
    # Unmute since user is back
    osascript -e 'set volume output muted false' 2>/dev/null
fi
exit 0

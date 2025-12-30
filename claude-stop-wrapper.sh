#!/bin/bash
# =============================================================================
# Claude Code Stop Hook Wrapper
# =============================================================================
# Feeds stdin to multiple downstream hooks (focusbase + ClaudeNotifier)
#
# HOOK BEST PRACTICES (learn from past bugs):
# -------------------------------------------
# 1. NEVER trust stdin - /clear and escape may provide no input, causing
#    `cat` to block forever. Always use timeouts.
#
# 2. ALWAYS validate JSON - Interrupted sessions may send empty or malformed
#    JSON. Validate before processing, exit 0 on invalid input.
#
# 3. ALWAYS exit 0 - Non-zero exits block Claude Code. Even on errors, exit 0
#    and log the error elsewhere if needed.
#
# 4. RUN SUB-HOOKS IN BACKGROUND - If one hook hangs, it shouldn't block others.
#    Use watchdog processes to kill stragglers.
#
# 5. CLEAN UP RESOURCES - Use `trap` to remove temp files and kill child
#    processes on exit.
#
# 6. FAIL FAST - Hooks are in the critical path. Prefer quick failure over
#    hanging. A 2-5 second timeout is reasonable.
#
# DEBUGGING:
# ----------
# Uncomment the following line to log all hook invocations:
# exec >> /tmp/claude-stop-hook.log 2>&1; set -x
# =============================================================================

set -o pipefail

# Suppress output to prevent interference with Claude Code's terminal
exec 1>/dev/null 2>/dev/null

# -----------------------------------------------------------------------------
# STDIN READ WITH TIMEOUT
# -----------------------------------------------------------------------------
# Use read -t for atomic stdin capture with timeout (no race conditions)
# The || [[ -n "$line" ]] handles input without trailing newline

JSON_INPUT=""
while IFS= read -r -t 2 line || [[ -n "$line" ]]; do
  JSON_INPUT+="$line"
done

# -----------------------------------------------------------------------------
# INPUT VALIDATION
# -----------------------------------------------------------------------------
# Problem: Malformed JSON causes jq errors and unexpected behavior downstream
# Solution: Validate JSON structure before passing to sub-hooks

if [[ -z "$JSON_INPUT" ]]; then
    # Empty input - likely /clear or interrupted session (escape)
    exit 0
fi

if ! echo "$JSON_INPUT" | jq -e . >/dev/null 2>&1; then
    # Malformed JSON - exit gracefully
    exit 0
fi

# -----------------------------------------------------------------------------
# PARALLEL HOOK EXECUTION WITH WATCHDOG
# -----------------------------------------------------------------------------
# Problem: Sequential hooks mean one hanging blocks everything
# Solution: Run each hook in background, use watchdog to kill after timeout
#
# Why 5 seconds: Long enough for normal operations, short enough to not block
# the user noticeably. Adjust based on your hooks' typical runtime.

(echo "$JSON_INPUT" | /Users/enriqueleal-sierra/.focusbase/bin/focusbase-claude-stop.sh) &
PID1=$!

(echo "$JSON_INPUT" | "$(dirname "$0")/claude-notify-hook.sh") &
PID2=$!

# Watchdog: Kill any hooks still running after 5 seconds
(
    sleep 5
    kill $PID1 $PID2 2>/dev/null
) &
WATCHDOG=$!

# Wait for hooks to complete (or be killed by watchdog)
wait $PID1 $PID2 2>/dev/null

# Clean up watchdog if hooks finished early
kill $WATCHDOG 2>/dev/null

# -----------------------------------------------------------------------------
# ALWAYS EXIT 0
# -----------------------------------------------------------------------------
# Non-zero exit codes block Claude Code from continuing. Even if something
# failed above, we exit 0 to not disrupt the user's workflow.
exit 0

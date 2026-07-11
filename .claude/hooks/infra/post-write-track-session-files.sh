#!/bin/bash
# post-write-track-session-files.sh - Record files written/edited in the current session.
# Paired with session-end-auto-commit.sh to commit only session-touched files.
#
# State lives in /tmp/claude-session-files/<session_id>.txt (one path per line).

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')

[[ -z "$SESSION_ID" || -z "$FILE_PATH" ]] && exit 0

STATE_DIR="/tmp/claude-session-files"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/${SESSION_ID}.txt"

echo "$FILE_PATH" >> "$STATE_FILE"

# Per-TURN marker: files written SINCE the last Stop. stop-codex-review.sh consumes and truncates this
# each turn, so it reviews only what THIS session wrote THIS turn — never another session's edit to a
# file both sessions happen to have touched. The cumulative STATE_FILE above still drives the commit.
echo "$FILE_PATH" >> "$STATE_DIR/${SESSION_ID}.pending.txt"
exit 0

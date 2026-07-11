#!/bin/bash
# pre-write-snapshot-baseline.sh - Snapshot a file's PRE-write content the first time this session
# touches it, so stop-codex-review.sh can build a review diff WITHOUT consulting git.
#
# Why this exists: the codex review Stop hook must decide "what did THIS session change?" from its own
# records, never from `git diff HEAD` (which is global, shared, cross-session working-tree state — a
# file another session or a subagent keeps dirtying then shows as "changed" forever, re-firing an
# xhigh review on every turn, even a chat-only one). The Stop hook already scopes to this session's
# writes via post-write-track-session-files.sh; this PreToolUse sibling captures the missing half — the
# baseline content to diff against. Together they are the git-free equivalent of "diff vs HEAD", but
# per-session and immune to what any other session does.
#
# Fires BEFORE Write/Edit/MultiEdit, so the file on disk is still the pre-edit version. We snapshot it
# ONLY on the FIRST touch of each path this session (if <key>.base already exists we leave it), so the
# baseline stays pinned to the session-start content and the Stop hook always sees the FULL session
# change, not just the delta since the last edit. A file the session creates from scratch has an EMPTY
# baseline (the file doesn't exist yet) — correct: the whole new file is the change.
#
# Store: /tmp/claude-session-files/<session_id>.snap/<key>.base  (key = sha1 of the canonical path).
# The Stop hook reuses the same dir for its <key>.reviewed / <key>.clean content-hash markers.
# Passive recorder: NEVER blocks a write — always exits 0.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$SESSION_ID" || -z "$FILE_PATH" ]] && exit 0

# Canonicalize the SAME way the Stop hook does (realpath -m: resolves ".." without requiring the file
# to exist), so both hooks derive an identical key for the same path.
RF=$(realpath -m "$FILE_PATH" 2>/dev/null) || exit 0
[[ -z "$RF" ]] && exit 0

# Only repo-contained, reviewable files are snapshotted. The baseline exists solely so the codex
# Stop gate can diff this session's code changes — a file outside the repo, or one review will
# never diff (.env, credentials, scratch output), has no consumer here, and snapshotting it would
# only copy potentially sensitive content into hook state.
REPO_ROOT=$(realpath -m "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}" 2>/dev/null)
[[ -z "$REPO_ROOT" ]] && exit 0
case "$RF" in
    "$REPO_ROOT"/*) ;;
    *) exit 0 ;;
esac
# Kept in lockstep with CODE_EXT_RE in stop/stop-codex-review.sh, plus the dispositions ledger
# (force-included in review scope despite its extension). Case-INSENSITIVE like _in_review_scope: a
# file named .PS1 / .YAML on Windows must still get a baseline, or the Stop hook would treat it as
# out-of-scope auto-committable non-code.
printf '%s\n' "$RF" | grep -qiE '\.(ps1|psm1|psd1|ps1xml|md|sh|yml|yaml)$|/codex-review-dispositions\.jsonl$' || exit 0

KEY=$(printf '%s' "$RF" | sha1sum 2>/dev/null | cut -d' ' -f1)
[[ -z "$KEY" ]] && exit 0

SNAP_DIR="/tmp/claude-session-files/${SESSION_ID}.snap"
BASE="$SNAP_DIR/${KEY}.base"

# First touch only — never overwrite an existing baseline (keeps it at session-start content).
[[ -e "$BASE" ]] && exit 0

# NO age-based cleanup of /tmp/claude-session-files here. stop-codex-review.sh REPLAYS open findings and
# per-turn review scope from these markers, and age can NEVER prove a parallel session ended — an idle-
# but-alive session writes nothing between turns, so deleting its markers by age would drop an open block
# or corrupt its review scope (the exact failure the Stop hook's snapshot-store note calls out). Session
# state is removed ONLY by its own SessionEnd (session-end-auto-commit.sh); a crashed session leaves a
# tiny bounded store until /tmp itself is cleared — the deliberate tradeoff, preferred over ever
# corrupting a live session's gating.

mkdir -p "$SNAP_DIR" 2>/dev/null || exit 0
chmod 700 "$SNAP_DIR" 2>/dev/null

# Snapshot the pre-write content. A file that doesn't exist yet (Write creating it) gets an empty
# baseline. Write to a temp then atomically move, and mark 0600 (the review diff is derived from it).
# When the file is ABSENT at first touch, ALSO drop a <key>.baseabsent marker: an empty <key>.base alone
# cannot tell "created this session" from "existed but was empty at session start", and the Stop hook
# needs that distinction to decide whether a later DELETION reverts to the baseline (created-then-deleted
# -> reap the block) or is a real change (existed-empty-then-deleted -> keep blocking until a CLEAN review).
TMP=$(mktemp "${SNAP_DIR}/.base.XXXXXXXX" 2>/dev/null) || exit 0
if [[ -f "$RF" ]]; then
    cat "$RF" > "$TMP" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; exit 0; }
else
    ( umask 077; : > "$SNAP_DIR/${KEY}.baseabsent" ) 2>/dev/null
fi
chmod 600 "$TMP" 2>/dev/null
mv -f "$TMP" "$BASE" 2>/dev/null || rm -f "$TMP" 2>/dev/null
exit 0

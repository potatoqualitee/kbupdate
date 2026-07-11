#!/bin/bash
# pre-write-snapshot-baseline.sh - Snapshot a file's PRE-write content the first time this session
# touches it, so stop-codex-review.sh can build a review diff WITHOUT consulting git; and record, at
# that same first touch, whether the file was already dirty vs HEAD (so the commit gate never treats a
# sibling session's pre-existing hunks as this session's reviewed work).
#
# Why this exists: the codex review Stop hook must decide "what did THIS session change?" from its own
# records, never from `git diff HEAD` (which is global, shared, cross-session working-tree state — a
# file another session or a subagent keeps dirtying then shows as "changed" forever, re-firing an
# xhigh review on every turn, even a chat-only one). The Stop hook already scopes to this session's
# writes via post-write-track-session-files.sh; this PreToolUse sibling captures the missing half — the
# baseline content to diff against. Together they are the git-free equivalent of "diff vs HEAD", but
# per-session and immune to what any other session does.
#
# Fires BEFORE Write/Edit/MultiEdit, so the file on disk is still the pre-edit version. Baseline and the
# pre-existing-dirty check are BOTH recorded on the FIRST touch of each path this session, so they stay
# pinned to the session-start content. A file the session creates from scratch has an EMPTY baseline plus
# a <key>.baseabsent marker.
#
# Store: /tmp/claude-session-files/<session_id>.snap/<key>  (key = sha1 of the canonical path):
#   <key>.base / <key>.baseabsent  - baseline for the codex diff (reviewable files only).
#   <key>.predirty                 - the file already differed from HEAD at first touch (ANY touched path).
#   <key>.firsttouch               - "predirty already evaluated" sentinel (ANY touched path).
# The Stop hook reuses the same dir for its <key>.reviewed / <key>.clean markers.
# Passive recorder: NEVER blocks a write — always exits 0.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$SESSION_ID" || -z "$FILE_PATH" ]] && exit 0

# Canonicalize the SAME way the Stop hook does (realpath -m: resolves ".." without requiring the file
# to exist), so both hooks derive an identical key for the same path.
RF=$(realpath -m "$FILE_PATH" 2>/dev/null) || exit 0
[[ -z "$RF" ]] && exit 0

# Repo-contained files only — a path outside the repo has no consumer here.
REPO_ROOT=$(realpath -m "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}" 2>/dev/null)
[[ -z "$REPO_ROOT" ]] && exit 0
case "$RF" in
    "$REPO_ROOT"/*) ;;
    *) exit 0 ;;
esac

# Sensitive files (secrets/credentials/inventories/host+lab lists — by name, extension, OR directory) are
# excluded from EVERY automated channel: no baseline to /tmp, no review, no auto-commit. Checked BEFORE
# anything is recorded, so their content never lands in hook state at all.
source "$(dirname "$0")/../lib/lib-sensitive-path.sh"
_is_sensitive_path "$RF" && exit 0

KEY=$(printf '%s' "$RF" | sha1sum 2>/dev/null | cut -d' ' -f1)
[[ -z "$KEY" ]] && exit 0
SNAP_DIR="/tmp/claude-session-files/${SESSION_ID}.snap"

# NO age-based cleanup of /tmp/claude-session-files here. stop-codex-review.sh REPLAYS open findings and
# per-turn review scope from these markers, and age can NEVER prove a parallel session ended — an idle-
# but-alive session writes nothing between turns, so deleting its markers by age would drop an open block
# or corrupt its review scope. Session state is removed ONLY by its own SessionEnd (session-end-auto-
# commit.sh); a crashed session leaves a tiny bounded store until /tmp itself is cleared.

mkdir -p "$SNAP_DIR" 2>/dev/null || exit 0
chmod 700 "$SNAP_DIR" 2>/dev/null

# Record pre-existing dirtiness at FIRST touch (PreToolUse: the file still holds its session-start bytes).
# This covers EVERY touched path — reviewable code AND non-code (settings.json, data files) — because both
# are auto-committable, and a file already dirty vs HEAD (a sibling session's uncommitted hunks, or pre-
# existing untracked content) carries hunks the codex review never covers while `git add` would stage the
# whole HEAD->current diff. build_commit_allowlist withholds a .predirty path from the approved per-turn
# commit (it can still ride the SessionEnd UNREVIEWED sweep). The .firsttouch sentinel gates this so a
# LATER touch — by then dirtied by THIS session's own reviewed edit — never mis-records predirty.
FIRST="$SNAP_DIR/${KEY}.firsttouch"
if [[ ! -e "$FIRST" ]]; then
    REL="${RF#$REPO_ROOT/}"
    if [[ -f "$RF" && -n "$(git -C "$REPO_ROOT" status --porcelain -- "$REL" 2>/dev/null)" ]]; then
        ( umask 077; : > "$SNAP_DIR/${KEY}.predirty" ) 2>/dev/null
    fi
    ( umask 077; : > "$FIRST" ) 2>/dev/null
fi

# Baseline snapshot is for REVIEWABLE files only (the codex diff needs it; non-code does not). Kept in
# lockstep with CODE_EXT_RE in stop/stop-codex-review.sh, plus the dispositions ledger. Case-INSENSITIVE
# like _in_review_scope. A non-reviewable file has its predirty recorded above and needs nothing more.
printf '%s\n' "$RF" | grep -qiE '\.(ps1|psm1|psd1|ps1xml|md|sh|yml|yaml)$|/codex-review-dispositions\.jsonl$' || exit 0

BASE="$SNAP_DIR/${KEY}.base"
# First touch only — never overwrite an existing baseline (keeps it at session-start content).
[[ -e "$BASE" ]] && exit 0

# Snapshot the pre-write content. A file that doesn't exist yet (Write creating it) gets an empty baseline
# and a <key>.baseabsent marker (so a later DELETION can be told from an existed-empty file). Write to a
# temp then atomically move, 0600 (the review diff is derived from it).
TMP=$(mktemp "${SNAP_DIR}/.base.XXXXXXXX" 2>/dev/null) || exit 0
if [[ -f "$RF" ]]; then
    cat "$RF" > "$TMP" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; exit 0; }
else
    ( umask 077; : > "$SNAP_DIR/${KEY}.baseabsent" ) 2>/dev/null
fi
chmod 600 "$TMP" 2>/dev/null
mv -f "$TMP" "$BASE" 2>/dev/null || rm -f "$TMP" 2>/dev/null
exit 0

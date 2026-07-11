#!/bin/bash
# session-end-auto-commit.sh - Auto-commit of session-modified files (SessionEnd event).
# Commits ONLY files Claude touched THIS session (lib-session-commit.sh uses the per-session
# tracker + literal pathspecs, so a sibling session's or otherwise-uncommitted files can never be
# swept in). Never pushes.
#
# Two modes, keyed off the codex review gate:
#   review OFF    -> plain session auto-commit (original commit-at-session-end behavior).
#   review ACTIVE -> orphan sweep. During the session, stop-codex-review.sh owns committing
#     (only on CLEAN / outage) and WITHHOLDS commits for blocked or budget-bypassed rounds. If the
#     session ends in that state its files would stay uncommitted forever: the next session gets a
#     new session id, so no future review or commit would ever cover them (they'd just pollute
#     git status and bait later sessions into off-task "fixing" — observed 2026-07-06). So at
#     SessionEnd we commit whatever the gate withheld, with the subject and body explicitly marked
#     UNREVIEWED: the work is preserved and attributable, but never mistakable for codex-approved.
#     If the last round went CLEAN, the gate already committed everything and this no-ops.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

source "$(dirname "$0")/../lib/lib-session-commit.sh"

if [[ "${CLAUDE_CODEX_REVIEW,,}" == "off" ]]; then
    commit_session_files "$SESSION_ID"
else
    commit_session_files "$SESSION_ID" \
        "chore(session): UNREVIEWED auto-commit at session end" \
        "UNREVIEWED: the codex review gate withheld these files (blocked findings or bypassed strike budget) and the session ended before a CLEAN verdict. Committed so the work is not orphaned; review before building on it."
fi

# The session's git-free review markers (baseline/reviewed/clean snapshot store + the per-turn write
# marker) are dead once its files are committed — remove them so they never linger (stop-codex-review.sh
# also reaps stale ones).
if [[ -n "$SESSION_ID" ]]; then
    rm -rf "/tmp/claude-session-files/${SESSION_ID}.snap" 2>/dev/null
    rm -f "/tmp/claude-session-files/${SESSION_ID}.pending.txt" 2>/dev/null
fi
exit 0

#!/bin/bash
# stop-codex-review.sh - Automated codex code-review gate at the end of each turn.
#
# Uses codex as an external reviewer: it pipes a review prompt + the working diff into `codex exec`
# (read-only) and converges to "green" before allowing work to finish. That is implemented as a
# blocking Stop hook:
#
#   1. If code files CHANGED CONTENT since this hook last reviewed them AND `codex` is installed,
#      build a diff of this session's own change (baseline snapshot -> current, NEVER `git diff`) and
#      hand it to codex with a reviewer prompt. "Changed since last review" is judged from the hook's
#      OWN per-file content hashes (the snapshot store below), so a chat-only ("hello") turn reviews
#      nothing — no wasted codex call.
#   2. codex returns findings and a final-line verdict (CLEAN | CHANGES_REQUESTED).
#   3. CHANGES_REQUESTED -> BLOCK the turn (decision:"block") so Claude must address
#      the findings; re-review next turn. CLEAN -> allow.
#
# Single Stop hook = review THEN commit, serially (Claude Code runs Stop hooks in PARALLEL, so two
# separate hooks could not be ordered). This hook owns the gated auto-commit of the session's files:
# it commits on CLEAN (and on codex outage, per policy), and WITHHOLDS the commit when codex found
# unresolved findings or the strike budget was bypassed. Withheld files are not orphaned: at
# SessionEnd, session-end-auto-commit.sh sweeps them into an explicitly-marked UNREVIEWED commit
# (still scoped to this session's tracker only). When review is disabled (CLAUDE_CODEX_REVIEW=off)
# that same hook does the plain session-end commit. Commit logic is shared via lib-session-commit.sh.
#
# Convergence / cost control:
#   - A per-session "clean" cache (keyed by diff hash) skips re-reviewing a diff codex
#     already approved — no wasted codex call, no spurious block.
#   - stop_guard_emit (lib-stop-guard.sh) bounds forced rounds via STOP_GUARD_MAX_BLOCKS
#     (default 3); after the budget it downgrades to an advisory so the agent is never
#     trapped in a Stop->work->Stop loop.
#
# Safety:
#   - codex runs --sandbox read-only: the reviewer MUST NOT mutate the tree.
#   - Fails OPEN on any infra problem (codex absent, timeout, error, empty output):
#     a review the tool couldn't perform never blocks the turn.
#   - Audit output lives only under /tmp (never the repo) so a review artifact can't
#     itself become a "changed file" and re-trigger the gate forever.
#
# Scope (deliberate): reviews ONLY files THIS session wrote via Write/Edit/MultiEdit (tracked by
# infra/post-write-track-session-files.sh). This is the explicit design — parallel sessions must not
# review each other's edits. Known limitation: code changed purely via Bash (sed -i, generators)
# is not tracked and thus not auto-reviewed; run /code-review by hand for those.
# Change detection is git-FREE: "did this file change since I last reviewed it?" is answered from the
# hook's OWN per-file content hashes plus a pre-write baseline snapshot (infra/pre-write-snapshot-
# baseline.sh), NEVER `git diff HEAD`. `git diff HEAD` is global cross-session working-tree state, so a
# file another session or subagent keeps dirtying would otherwise re-fire a high-effort review every turn,
# including chat-only turns. Deriving change from the session's OWN record fixes that and keeps
# parallel sessions from reviewing each other's edits. git is used ONLY to COMMIT approved work.
# Markdown is IN scope (docs are deliverables — reviewed for accuracy, not code style). Files that are
# not a reviewable extension (see CODE_EXT_RE) never gate the turn but are still auto-committed.
#
# Review memory (lib-codex-review-memory.sh) — keeps rounds from re-litigating settled points:
#   * .claude/codex-review-dispositions.jsonl — maintainer-audited ledger of findings ruled FALSE
#     POSITIVE; matching findings are suppressed in every future review. The block message teaches
#     Claude to append a ruling (with the governing rule cited) instead of looping in dispute.
#     The ledger itself is force-included in review scope: a suppression edit is judged by codex
#     before it can be auto-committed, so the ledger can't become an unreviewed bypass channel.
#   * prior-round findings — each blocked round's review text is replayed to codex next round so it
#     verifies fixes against the CURRENT diff rather than re-reviewing blind. Cleared on any commit.
#
# Env knobs:
#   CLAUDE_CODEX_REVIEW=off       - disable for the session.
#   CLAUDE_CODEX_REVIEW_TIMEOUT   - codex wall-clock seconds (default 600).
#   CLAUDE_CODEX_REVIEW_MODEL     - codex model (default: codex's own default; unset means don't pass --model).
#   CLAUDE_CODEX_REVIEW_EFFORT    - codex model_reasoning_effort (default high).
#   CLAUDE_CODEX_REVIEW_MAXBYTES  - max diff bytes sent to codex (default 200000); a larger diff is
#                                   marked truncated and fails safe toward CHANGES_REQUESTED.
#   CLAUDE_CODEX_REVIEW_REASONING_RETRIES - retry count for suspicious fixed reasoning counts
#                                           (default 1).
#   CLAUDE_CODEX_REVIEW_SUSPICIOUS_REASONING_TOKENS - space-separated counts (default
#                                                     "516 1034 1552").
#   STOP_GUARD_MAX_BLOCKS         - ceiling on forced rounds (default 3; lib-stop-guard).
#
# Live view: codex's transcript streams to a fixed $HOME/.codex-review.live.log (mode 0600, truncated
# each round) so you can WATCH this Stop hook run with `tail -f ~/.codex-review.live.log` -- Claude
# Code never streams Stop-hook output to its UI. The path is intentionally NOT configurable (see the
# security note at step 6: a private $HOME parent is what keeps a predictable name safe).

# Blocking gate: source the guard (reads stdin, sets _TRANSCRIPT_HASH/_MARKER_DIR/_HOOK_NAME,
# provides stop_guard_emit). Do NOT early-exit on STOP_GUARD_SKIP — this enforces every turn.
source "$(dirname "$0")/../lib/lib-stop-guard.sh"
# Gated commit lives here too (parallel Stop hooks can't be ordered) — provides commit_session_files.
source "$(dirname "$0")/../lib/lib-session-commit.sh"
# Memory (rejections ledger + prior-round replay), prompt build, exec helpers — sibling libs.
source "$(dirname "$0")/../lib/lib-codex-review-memory.sh"
source "$(dirname "$0")/../lib/lib-codex-review-prompt.sh"
source "$(dirname "$0")/../lib/lib-codex-review-exec.sh"
# git-FREE change detection + commit gating (content-snapshot store, scope predicate, payload build) —
# split out to keep this file within the 400-line limit. Provides collect_session_files /
# build_session_payload / advance_reviewed / mark_clean / build_commit_allowlist / _in_review_scope.
source "$(dirname "$0")/../lib/lib-codex-review-snapshot.sh"

# Extensions worth reviewing for kbupdate: PowerShell module code, tests and manifests, the module's
# own shell + CI/config files, plus markdown — docs are deliverables here and are reviewed for accuracy.
# Kept in lockstep with the case list in infra/pre-write-snapshot-baseline.sh.
CODE_EXT_RE='\.(ps1|psm1|psd1|ps1xml|md|sh|yml|yaml)$'

# Session id drives BOTH the review scope and the gated commit; read it up front.
SESSION_ID=$(echo "$_STOP_HOOK_INPUT" | jq -r '.session_id // empty')

# 1. Opt-out: review disabled -> do nothing here; session-end-auto-commit.sh commits at SessionEnd.
if [[ "${CLAUDE_CODEX_REVIEW,,}" == "off" ]]; then
    exit 0
fi

# codex missing is an outage, but it is handled LATER (just before the codex run), AFTER the snapshot
# state is loaded — so it goes through finalize_and_exit and commits only the codex-approved allowlist
# while PRESERVING and re-blocking any open findings. Committing the whole session here (before the
# snapshot state exists) would let code an earlier turn blocked with CHANGES_REQUESTED enter git as a
# normal commit.

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo /workspace)
# Canonicalize with the SAME realpath -m the session paths get (collect_session_files, build_commit_
# allowlist, lib-session-commit). git may report a symlinked, relative, or Windows-format root; if the
# raw form diverged from the realpath'd session paths, the "$rf" == "$REPO_ROOT/"* containment checks in
# _in_review_scope / build_commit_allowlist would silently drop in-scope files and SKIP the gate (fail
# open). Canonicalizing both sides the same way keeps containment sound.
REPO_ROOT=$(realpath -m "$REPO_ROOT" 2>/dev/null || printf '%s' "$REPO_ROOT")

# NOTE: no top-level index-lock guard. The review is now git-FREE (content snapshots, not `git diff`),
# so a concurrent git op cannot race it. Only the COMMIT touches git, and commit_session_files
# (lib-session-commit.sh) already reaps a stale lock and defers on a live one — so a held lock delays
# the commit without ever skipping the review.

# 2. Scope to THIS session's writes only — never review files a concurrent session touched.
#    infra/post-write-track-session-files.sh records every Write/Edit path to
#    /tmp/claude-session-files/<session_id>.txt; we review only those (intersected with the
#    real diff below). This is what keeps parallel sessions from reviewing each other's work.
SESSION_STATE="/tmp/claude-session-files/${SESSION_ID}.txt"
if [[ -z "$SESSION_ID" || ! -f "$SESSION_STATE" ]]; then
    stop_guard_emit ""    # nothing tracked for this session -> nothing to review or commit
    exit 0
fi

# Git-free content-snapshot store for THIS session (see the scope note above). Keyed by sha1 of the
# canonical path:
#   <key>.base     - pre-write content, written on FIRST touch by infra/pre-write-snapshot-baseline.sh
#   <key>.reviewed - sha256 of the content codex last reviewed (advances every terminal review path)
#   <key>.clean    - sha256 of the content codex APPROVED (gates the per-turn auto-commit)
# These, NOT git, decide what to review and what may be auto-committed.
SNAP_DIR="/tmp/claude-session-files/${SESSION_ID}.snap"
# NO periodic age-based reap of other sessions' stores. Age can NEVER prove a parallel session ENDED — an
# idle-but-alive session writes nothing between turns — and deleting its state by age is unsafe in BOTH
# directions: dropping its .snap loses an open block (findings are REPLAYED from these markers, not re-run) or
# folds its diff baseline into already-changed content; and dropping its per-turn .pending.txt flips the
# resumed session to CUMULATIVE review scope, letting it review/commit ANOTHER session's edits to a shared
# file. A session's review state is therefore removed ONLY by its OWN SessionEnd — the one EXPLICIT "ended"
# signal we have (session-end-auto-commit.sh commits any withheld work UNREVIEWED, then deletes .snap +
# .pending.txt). A CRASHED session (no SessionEnd) leaves a tiny store until /tmp itself is cleared — a bounded
# leak deliberately preferred over ever corrupting a live parallel session's blocks or review scope.

# Per-turn write marker: files THIS session wrote SINCE the last Stop (infra/post-write-track-session-
# files.sh appends here; we consume + truncate it now). PRESENT => this-turn scoping: a file another
# session changed but THIS session did not touch this turn is NOT reviewed — the cross-session isolation
# the whole rewrite is for. ABSENT (fresh session before its first write, or the deploy in which this
# marker did not yet exist) => fall back to the cumulative tracker below. Claude is paused during Stop
# hooks, so truncating now cannot drop a concurrent write; the next turn's writes repopulate it.
PENDING_STATE="/tmp/claude-session-files/${SESSION_ID}.pending.txt"
declare -A PENDING_SET=()
PENDING_PRESENT=0
if [[ -f "$PENDING_STATE" ]]; then
    PENDING_PRESENT=1
    while IFS= read -r _pf; do
        [[ -z "$_pf" ]] && continue
        _pr=$(realpath -m "$_pf" 2>/dev/null) || continue
        PENDING_SET["$_pr"]=1
    done < <(sort -u "$PENDING_STATE")
    : > "$PENDING_STATE"
fi

# The single terminal decision, shared by every non-error exit. finalize_and_exit commits codex-approved
# files, then BLOCKS iff ANY session file still has unresolved findings — evaluated PER FILE via
# collect_open_findings, independent of which files were reviewed THIS turn. So an unrelated file's CLEAN
# can never drop another file's open block, and an unchanged blocked file keeps blocking (its saved
# findings are REPLAYED, no codex re-run) until it CHANGES (re-reviewed) or receives CLEAN. stop_guard_emit
# bounds the replay to STOP_GUARD_MAX_BLOCKS rounds, then downgrades to an advisory so the agent is never
# trapped. DISPUTE_HOWTO (the false-positive ledger protocol) rides in both the block message here and the
# fresh CHANGES_REQUESTED block below.
DISPUTE_HOWTO='If a finding is a FALSE POSITIVE (it contradicts CLAUDE.md or a documented project ruling), do not ignore it and do not burn rounds arguing: append ONE JSON line to .claude/codex-review-dispositions.jsonl -- {"date":"YYYY-MM-DD","file":"<repo-relative path>","finding":"<short summary>","ruling":"rejected","reason":"<why it is wrong, citing the governing rule>"} -- then fix everything else. Use ruling:"rejected" ONLY when the finding is genuinely wrong: a rejected row is SUPPRESSED as a standing false positive from then on. For a finding that is a REAL defect you cannot fix this turn (must be tracked/deferred, not dismissed), use ruling:"acknowledged" with the reason stating exactly where it is tracked and why it is deferred -- an "acknowledged" row is an audit record only and is NOT suppressed, so codex keeps surfacing it until it is actually fixed. Never file a real defect as "rejected". The ledger edit is itself reviewed next round (an illegitimate ruling is a finding); the reviewer is shown this round of findings on the next run so it verifies fixes instead of re-litigating.'
finalize_and_exit() {
    local note="${1:-}"   # optional advisory (e.g. codex was unavailable this turn)
    build_commit_allowlist
    commit_session_files "$SESSION_ID" "" "" "$ALLOW_FILE"
    [[ -n "${ALLOW_FILE:-}" && "$ALLOW_FILE" != /dev/null ]] && rm -f "$ALLOW_FILE" 2>/dev/null
    collect_open_findings
    if (( OPEN_COUNT > 0 )); then
        local reason
        reason=$(printf 'CODEX AUTO-REVIEW -- %s file(s) still have unresolved findings; fix or change them (unchanged files are NOT re-reviewed, so their findings are replayed here, not re-run):\n\n%s%s%s\n\n(Reviewer: %s, effort %s. Disable for this session with CLAUDE_CODEX_REVIEW=off.)' \
            "$OPEN_COUNT" "$OPEN_FINDINGS" "$DISPUTE_HOWTO" "${note:+$'\n\n'$note}" "${CLAUDE_CODEX_REVIEW_MODEL:-codex default}" "${CLAUDE_CODEX_REVIEW_EFFORT:-high}")
        stop_guard_emit "$(jq -n --arg reason "$reason" '{decision:"block",reason:$reason}')"
    else
        codex_memory_clear_prev          # no open findings -> reset the prompt-context slate
        [[ -n "$note" ]] && jq -n --arg m "$note" '{systemMessage: $m}'   # advisory (non-blocking)
        stop_guard_emit ""               # allow
    fi
    exit 0
}

# rearm_pending — re-add the just-reviewed files to this turn's (already-consumed) pending marker so the
# NEXT turn RE-REVIEWS them even without a new write. Used for RETRY-REQUIRED outcomes: a truncated diff
# (needs a higher CLAUDE_CODEX_REVIEW_MAXBYTES) or a TOCTOU block (whose new on-disk bytes were never
# reviewed). Without this, the pending marker was truncated at turn start, so on the next no-change turn
# the pending gate skips the file and its unreviewed bytes are never re-examined. No-op unless per-turn
# pending scoping is active (in cumulative-fallback mode the file is re-reviewed by the content trigger).
rearm_pending() {
    (( PENDING_PRESENT )) || return 0
    local rel
    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        printf '%s\n' "$REPO_ROOT/$rel" >> "$PENDING_STATE"
    done <<< "$CODE_FILES"
}

# Scope this session's tracked files to what the review gate should judge. collect_session_files
# (lib-codex-review-snapshot.sh) canonicalizes each path FIRST, then applies containment via
# _in_review_scope: reviewable extensions plus the force-included dispositions ledger. Canonicalize-
# first closes a traversal bypass (e.g. sub/../other/x.ps1 masquerading under a different prefix).
# Non-reviewable files are still auto-committed (commit_session_files reads the raw session-state
# file), they just never gate a turn.
collect_session_files
if [[ ${#SESSION_FILES[@]} -eq 0 ]]; then
    finalize_and_exit   # no in-scope code this session -> commit non-code; no open findings possible -> allow
fi

# 3. Build the changed-file list + a bounded diff payload, limited to this session's files (git-free
#    content-snapshot detection + commit gating live in lib-codex-review-snapshot.sh).
build_session_payload
if [[ -z "$PAYLOAD" ]]; then
    # Nothing CHANGED since the last review (the "hello"/no-op turn): no codex run. finalize_and_exit
    # still blocks if a file remains open from an earlier turn (its saved findings are replayed, not
    # re-run), so an unresolved finding never silently disappears just because nothing changed this turn.
    finalize_and_exit
fi

# Budget/convergence hash is taken from the FULL diff, BEFORE any truncation: two different
# oversized diffs that share their first PAYLOAD_MAX bytes must NOT hash alike, or the per-diff
# budget reset and clean cache could be bypassed by edits living past the cap.
# sha256, not md5: this hash authorizes the CLEAN cache and per-diff budget, so a chosen-prefix
# collision must not let one approved diff vouch for a different one.
PAYLOAD_HASH=$(printf '%s' "$PAYLOAD" | sha256sum | cut -d' ' -f1)

# Bound the prompt, but NEVER silently: if the diff is too large to send whole, truncating it and
# trusting a CLEAN verdict would bless unseen hunks. Mark truncation so codex (and the verdict
# guard in step 8) fail safe toward CHANGES_REQUESTED instead.
PAYLOAD_MAX=${CLAUDE_CODEX_REVIEW_MAXBYTES:-200000}
TRUNCATED=""
if (( ${#PAYLOAD} > PAYLOAD_MAX )); then
    OMITTED=$(( ${#PAYLOAD} - PAYLOAD_MAX ))
    PAYLOAD=$(printf '%s' "$PAYLOAD" | head -c "$PAYLOAD_MAX")
    TRUNCATED=$'\n\n[... DIFF TRUNCATED: '"$OMITTED"$' more bytes not shown. Unseen changes may contain defects -- do NOT return CLEAN; return CHANGES_REQUESTED and ask for a smaller change set. ...]'
fi

# 4. Convergence + cost guards (need transcript context for keyed marker files).
CLEAN_FILE=""
if [[ -n "${_MARKER_DIR:-}" && -n "${_TRANSCRIPT_HASH:-}" ]]; then
    CLEAN_FILE="${_MARKER_DIR}/${_TRANSCRIPT_HASH}_codex-review.clean"
    COUNT_FILE="${_MARKER_DIR}/${_TRANSCRIPT_HASH}_${_HOOK_NAME}.count"

    # Already approved this exact diff? Don't re-spend a codex call or re-block — record clean+reviewed,
    # clear these files' open findings, and finalize (commits them; still blocks if OTHER files are open).
    if [[ -f "$CLEAN_FILE" && "$(cat "$CLEAN_FILE" 2>/dev/null)" == "$PAYLOAD_HASH" ]]; then
        mark_clean; advance_reviewed; clear_reviewed_findings
        finalize_and_exit
    fi

    # Reset the block streak when this content is NEW (Claude made progress: a changed diff hashes
    # differently), so freshly-changed code gets a fresh budget rather than inheriting an old streak.
    # An UNCHANGED blocked file never reaches here — it takes the empty-payload -> finalize replay path,
    # where stop_guard_emit accumulates the streak and downgrades to advisory after STOP_GUARD_MAX_BLOCKS.
    LASTHASH_FILE="${_MARKER_DIR}/${_TRANSCRIPT_HASH}_codex-review.lasthash"
    if [[ ! -f "$LASTHASH_FILE" || "$(cat "$LASTHASH_FILE" 2>/dev/null)" != "$PAYLOAD_HASH" ]]; then
        rm -f "$COUNT_FILE" 2>/dev/null
        printf '%s' "$PAYLOAD_HASH" > "$LASTHASH_FILE" 2>/dev/null
    fi
fi

# 4b. Review memory: standing rejections from the repo ledger + the prior blocked round's findings
#     for this transcript. Loaded BEFORE the nonce so the nonce uniqueness scan can cover both.
codex_memory_load_dispositions "$REPO_ROOT"
codex_memory_load_prev

# 5. Reviewer prompt (the "codex half" — Claude triages by fixing during the blocked turn). Built by
#    lib-codex-review-prompt.sh: one-time-nonce fences around the diff, filenames, and memory
#    sections; standing exemptions; strict final-line verdict contract. Sets NONCE + PROMPT.
codex_review_build_prompt

# 6. Run codex read-only. The exec loop (codex_review_run) lives in lib-codex-review-exec.sh — it keeps
#    REVIEW race-free via per-run mktemp captures (a stale/shared/refused/hostile file can never decide
#    the verdict), mirrors to the best-effort live VIEW (private-$HOME hardening in the same lib), and
#    applies the reasoning-guard retry. It sets REVIEW, RC, and CODEX_REASONING_GUARD_BLOCK.
# codex not installed = an outage. Handle it HERE (snapshot state is loaded) via finalize_and_exit, so
# we commit ONLY the codex-approved allowlist and PRESERVE/re-block open findings — never sweep a
# CHANGES_REQUESTED-blocked file into a normal commit. Files changed this turn but unreviewable ride to
# the SessionEnd UNREVIEWED sweep (not orphaned), never committed as approved during the outage.
# rearm_pending FIRST: this turn's pending marker was already consumed and .reviewed is NOT advanced on
# an outage, so without re-arming, a later no-change turn's pending gate would skip these unreviewed
# files forever — even once codex is back. Re-arming makes the next turn re-review them.
if ! command -v codex >/dev/null 2>&1; then
    rearm_pending
    finalize_and_exit "codex auto-review unavailable this turn (codex not installed) -- proceeding without it; already-open findings still block. Set CLAUDE_CODEX_REVIEW=off to silence."
fi

codex_review_setup_livelog
codex_review_run

# 7a. Reasoning guard blocks take precedence over the fail-open policy. If we detected suspicious
#     reasoning and a retry didn't give us a clean answer, we MUST block -- fail-open only applies
#     to first-attempt infra failures where we never saw suspicious behavior.
if [[ -n "$CODEX_REASONING_GUARD_BLOCK" ]]; then
    advance_reviewed                           # don't re-run codex on this unchanged content
    save_findings "$CODEX_REASONING_GUARD_BLOCK"   # DURABLE open block: keeps blocking until the file changes/CLEAN
    finalize_and_exit                          # (fixes: a guard block used to vanish on the next no-change turn)
fi

# 7b. Fail OPEN on an infra failure (codex error/timeout, empty output) — never block a turn because codex
#     could not run. But go through finalize_and_exit: commit ONLY the codex-approved allowlist and do NOT
#     clear open findings — a live-codex block from an earlier turn must survive a transient outage and
#     must not be committed. Unreviewable changed files ride to the SessionEnd UNREVIEWED sweep. rearm_pending
#     first (same reason as the codex-missing path): .reviewed is un-advanced on an outage, so re-arm the
#     consumed pending marker or a later no-change turn skips these unreviewed files even after codex returns.
if [[ $RC -ne 0 || -z "$REVIEW" ]]; then
    rearm_pending
    finalize_and_exit "codex auto-review unavailable this turn (codex error or timeout) -- proceeding without it; already-open findings still block. Set CLAUDE_CODEX_REVIEW=off to silence."
fi

# 8. Parse the verdict from the FINAL non-empty line only — a "VERDICT: CLEAN" buried mid-review
#    (e.g. quoted in a finding) must not flip the result. Anything else fails closed (blocks).
LAST_LINE=$(printf '%s\n' "$REVIEW" | grep -vE '^[[:space:]]*$' | tail -1)
if [[ "$LAST_LINE" =~ ^VERDICT:[[:space:]]*CLEAN[[:space:]]*$ ]]; then
    VERDICT="CLEAN"
elif [[ "$LAST_LINE" =~ ^VERDICT:[[:space:]]*CHANGES_REQUESTED[[:space:]]*$ ]]; then
    VERDICT="CHANGES_REQUESTED"
else
    VERDICT=""    # missing/garbled final line -> treated as CHANGES_REQUESTED below
fi

# A CLEAN verdict on a truncated diff is not trustworthy — unseen hunks were never reviewed.
if [[ "$VERDICT" == "CLEAN" && -n "$TRUNCATED" ]]; then
    VERDICT="CHANGES_REQUESTED"
    REVIEW="$REVIEW"$'\n\n(Auto-review note: the diff exceeded the review size limit and was truncated; split the change set or set CLAUDE_CODEX_REVIEW_MAXBYTES higher to review it whole.)'
fi

if [[ "$VERDICT" == "CLEAN" ]]; then
    codex_memory_save_prev "$REVIEW"   # keep prompt context; finalize clears it when nothing stays open
    # TOCTOU guard: re-derive the diff now and treat CLEAN as approval ONLY if the reviewed code is
    # byte-for-byte unchanged since codex saw it — the long high-effort run is a window in which the bytes on
    # disk could differ. We advance .reviewed / .clean AFTER this rebuild, not before: advancing first
    # would make this very rebuild treat the file as "already reviewed", empty the payload, and defeat the
    # check. On a MISMATCH we do NOT approve — we save a durable open finding so the turn BLOCKS and leave
    # .reviewed un-advanced so the new bytes are re-reviewed next turn (they must never reach SessionEnd
    # as an approval on stale bytes).
    build_session_payload
    if [[ "$(printf '%s' "$PAYLOAD" | sha256sum | cut -d' ' -f1)" == "$PAYLOAD_HASH" ]]; then
        mark_clean
        advance_reviewed
        clear_reviewed_findings                                   # approved -> this file's block is resolved
        [[ -n "$CLEAN_FILE" ]] && printf '%s' "$PAYLOAD_HASH" > "$CLEAN_FILE" 2>/dev/null
    else
        save_findings "CODEX AUTO-REVIEW -- this file was modified on disk DURING the review, so codex's CLEAN verdict does not cover the current bytes. The changed bytes are UNREVIEWED; they will be re-reviewed next turn. Do not finish on the stale approval."
        rearm_pending    # re-review the new bytes next turn even if untouched (pending was consumed this turn)
    fi
    finalize_and_exit    # commits the approved files; blocks if the TOCTOU mismatch (or any other file) is open
fi

# 9. CHANGES_REQUESTED, or a missing/garbled verdict -> block (fail safe for production-impacting code). Save a
#    DURABLE per-file open finding (finalize blocks on it and on any other open file). Advance .reviewed
#    so this exact content is not re-sent to codex on a later no-change turn — the block fires once per
#    content and the file keeps blocking (findings replayed) until it changes or receives CLEAN. EXCEPT on
#    a TRUNCATED diff: the bytes were NOT fully reviewed, so we leave .reviewed un-advanced — otherwise the
#    remediation ("raise CLAUDE_CODEX_REVIEW_MAXBYTES / split the change") could never re-review the same
#    bytes. Save the prompt-context prev so the NEXT round's reviewer verifies fixes against it.
[[ -z "$TRUNCATED" ]] && advance_reviewed
[[ -n "$TRUNCATED" ]] && rearm_pending   # truncated: re-review next turn (e.g. after raising MAXBYTES) even if untouched
save_findings "$REVIEW"
codex_memory_save_prev "$REVIEW"
finalize_and_exit

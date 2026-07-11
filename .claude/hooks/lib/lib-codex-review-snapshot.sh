#!/bin/bash
# lib-codex-review-snapshot.sh - The git-FREE change-detection + commit-gating core for
# stop-codex-review.sh. Split out to keep the Stop hook under the 400-line project limit and to keep
# all "decide what to review / what to commit, from the session's OWN records not git" logic in one place.
#
# Operates on globals the Stop hook sets before calling these: REPO_ROOT, CODE_EXT_RE, SNAP_DIR,
# SESSION_STATE, SESSION_FILES, PENDING_SET, PENDING_PRESENT. It reads/writes the per-session snapshot
# store under $SNAP_DIR, keyed by sha1 of the CANONICAL path:
#   <key>.base     - pre-write content (infra/pre-write-snapshot-baseline.sh); the diff baseline.
#   <key>.reviewed - sha256 of the content codex last reviewed; an unchanged file is skipped (no codex).
#   <key>.clean    - sha256 of the content codex APPROVED; gates the per-turn auto-commit.
# git is used ONLY to commit (lib-session-commit.sh), never to detect change.

if [[ -n "${_LIB_CODEX_REVIEW_SNAPSHOT_LOADED:-}" ]]; then
    return 0
fi
_LIB_CODEX_REVIEW_SNAPSHOT_LOADED=1

# _is_sensitive_path — a secret/inventory/host/lab file is excluded from review scope (never diffed,
# never sent to codex, never mirrored to the live log) and from the commit allowlist. Shared with the
# commit + baseline hooks so all three stages agree on what must stay out of every automated channel.
source "$(dirname "${BASH_SOURCE[0]}")/lib-sensitive-path.sh"

_snap_key() { printf '%s' "$1" | sha1sum 2>/dev/null | cut -d' ' -f1; }
# _content_hash <path> — a per-content fingerprint. An ABSENT (deleted) file returns a distinct sentinel
# ("absent"), NOT the empty-file hash: otherwise deleting a file that was approved while empty would
# collide with its own .clean/.reviewed and slip the deletion past review as "unchanged".
_content_hash() {
    if [[ -f "$1" ]]; then sha256sum "$1" 2>/dev/null | cut -d' ' -f1
    else printf 'absent'; fi
}

# _in_review_scope <CANONICAL abs path> — true iff the path is a file the review gate should judge.
# MUST be called on a canonicalized path (realpath -m): applying the check to a raw path would let a
# traversal like "$REPO_ROOT/sub/../other/x.ps1" slip a file past review under a masqueraded prefix.
#   * in-repo AND a reviewable extension (or the dispositions ledger, force-included so a suppression
#     edit can never be auto-committed unreviewed). Case-INSENSITIVE: on this Windows/PowerShell repo a
#     file may be named .PS1 / .PSD1 / .YAML, and a case-sensitive miss would skip the gate AND let the
#     file be mis-classified as auto-committable non-code.
#   * EXCLUDED even when the extension is reviewable: a sensitive file (credentials.ps1, secrets.md,
#     hosts.yml, lab-computers.yaml). Its content must never be diffed into the codex payload or the
#     live log, so it is never in scope — and _is_sensitive_path keeps it out of the commit allowlist too.
_in_review_scope() {
    local p="$1"
    [[ "$p" == "$REPO_ROOT/"* ]] || return 1
    _is_sensitive_path "$p" && return 1
    printf '%s\n' "$p" | grep -qiE "$CODE_EXT_RE|/\.claude/codex-review-dispositions\.jsonl$" || return 1
    return 0
}

# collect_session_files — populate SESSION_FILES with this session's in-review-scope files, CANONICAL
# and containment/exclusion-checked (canonicalize FIRST, then classify — see _in_review_scope).
collect_session_files() {
    SESSION_FILES=()
    local sf cf
    while IFS= read -r sf; do
        [[ -z "$sf" ]] && continue
        cf=$(realpath -m "$sf" 2>/dev/null) || continue
        _in_review_scope "$cf" && SESSION_FILES+=("$cf")
    done < <(sort -u "$SESSION_STATE")
}

# _append_review_diff <canonical-path> <key> — append this file's baseline->current diff (POSIX diff,
# never git; repo-relative a/ b/ labels so codex never sees a /tmp snapshot path) to the review arrays if
# there is a net change. Returns 0 if appended, 1 if nothing to review (identical to baseline), or 2 if it
# is a DELETION with no captured baseline (the removed content is unknown, so it can never be safely
# reviewed/approved and the caller MUST hard-block it).
_append_review_diff() {
    local f="$1" key="$2" rel base d
    rel="${f#$REPO_ROOT/}"
    base="$SNAP_DIR/${key}.base"
    # A PRESENT file with no captured baseline is diffed against /dev/null: its ENTIRE current content is
    # shown to codex and fully reviewed, so a CLEAN verdict validates the current bytes. We deliberately do
    # NOT hard-block that case. Baselines can be legitimately absent — a compaction / SessionEnd between
    # turns wipes the .snap store while the session tracker persists — and hard-blocking would mislabel
    # every such PRESENT file as "deleted" and wedge the gate on false blocks (observed 2026-07-11; see the
    # rejected disposition in .claude/codex-review-dispositions.jsonl).
    [[ -e "$base" ]] || base=/dev/null
    if [[ -f "$f" ]]; then
        d=$(diff -u --label "a/$rel" --label "b/$rel" "$base" "$f" 2>/dev/null)
    else
        d=$(diff -u --label "a/$rel" --label "b/$rel" "$base" /dev/null 2>/dev/null)   # deletion
    fi
    if [[ -z "$d" ]]; then
        # No TEXTUAL diff, but an EXISTENCE change (empty file added, or an existing / unknown-baseline file
        # deleted) is still a real change that MUST be reviewed — otherwise it slips past the gate as
        # "unchanged" and can only land via the SessionEnd UNREVIEWED sweep. Read the baseline state from the
        # markers pre-write-snapshot-baseline.sh records, treating a MISSING baseline as UNKNOWN, never as
        # "absent": <key>.baseabsent => file was absent at the baseline; a present <key>.base => it existed;
        # NEITHER => no capture (unknown). FAIL CLOSED — skip (return 1) ONLY when we are CERTAIN nothing
        # changed: the file is present and its content matched a CAPTURED, non-absent baseline (revert /
        # existed-empty-still-empty), or the file is absent and the baseline was EXPLICITLY absent (created
        # then deleted -> back to nothing). Other empty-diff existence changes are synthesized so codex reviews
        # them — EXCEPT a deletion with NO captured baseline, whose REMOVED content is unknown: it returns 2 so
        # the caller HARD-BLOCKS it (a CLEAN verdict could never vouch for content the reviewer was never shown).
        local base_marked_absent=0 base_captured=0
        [[ -f "$SNAP_DIR/${key}.baseabsent" ]] && base_marked_absent=1
        [[ -e "$SNAP_DIR/${key}.base" ]] && base_captured=1
        if [[ -f "$f" ]]; then
            (( base_captured && ! base_marked_absent )) && return 1    # present + captured existing baseline => content matched it (no-op)
            d="--- /dev/null"$'\n'"+++ b/$rel"$'\n'"@@ empty file added @@"$'\n'"# existence change: an EMPTY file is present at $rel (added, or no captured baseline) — review the add"
        else
            (( base_marked_absent )) && return 1                       # absent + baseline was EXPLICITLY absent => created then deleted (no-op)
            # Deletion with NO captured baseline: we cannot show codex WHAT was removed, so a CLEAN could
            # auto-commit an unreviewed removal. Hard-block it (return 2) — do NOT synthesize a CLEAN-able payload.
            (( base_captured )) || return 2
            # base is CAPTURED and empty (a non-empty base would have produced a textual diff above): the file
            # existed EMPTY and was deleted, so nothing of substance was removed — a CLEAN here IS trustworthy.
            d="--- a/$rel"$'\n'"+++ /dev/null"$'\n'"@@ empty file deleted @@"$'\n'"# existence change: $rel (empty at baseline) was deleted — review the delete"
        fi
    fi
    CODE_FILES+="${rel}"$'\n'
    PAYLOAD+="$d"$'\n'
    REVIEWED_KEYS+=("$key")
    REVIEWED_HASHES+=("$(_content_hash "$f")")
    return 0
}

# _include_open_files — add every currently-OPEN file (one with a .findings marker) not already in the
# payload. Called ONLY when something changed this turn, so codex re-reviews the whole blocked set AS A
# UNIT. This is what lets a file that shared a multi-file blocked payload but has no finding of its own
# get CLEARED once the actually-bad file is fixed: the set re-reviews CLEAN together and clear_reviewed_
# findings drops all of them. On a pure no-change turn it is NOT called (PAYLOAD stays empty -> the
# findings are replayed, codex is not re-invoked).
#
# CROSS-SESSION GUARD: this bypasses the per-turn pending gate, so it must only re-include an open file whose
# CURRENT bytes are THIS session's — the file is pending this turn, OR its content is unchanged since we last
# reviewed it (curhash == .reviewed). If an open file changed but is NOT in our pending set, ANOTHER live
# session edited it; re-reviewing it here would let a CLEAN verdict clear its block and auto-commit that other
# session's bytes. Such a file is skipped -> its .findings stays and the block simply REPLAYS
# (collect_open_findings), never cleared on someone else's edit.
_include_open_files() {
    local f rf key k already curhash reviewed
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        rf=$(realpath -m "$f" 2>/dev/null) || continue
        _in_review_scope "$rf" || continue
        key=$(_snap_key "$rf")
        [[ -f "$SNAP_DIR/${key}.findings" ]] || continue
        already=0
        for k in "${REVIEWED_KEYS[@]}"; do [[ "$k" == "$key" ]] && { already=1; break; }; done
        (( already )) && continue
        if [[ -z "${PENDING_SET[$rf]:-}" ]]; then                     # not pending this session ->
            curhash=$(_content_hash "$rf")
            reviewed=""
            [[ -f "$SNAP_DIR/${key}.reviewed" ]] && reviewed=$(cat "$SNAP_DIR/${key}.reviewed" 2>/dev/null)
            [[ "$curhash" == "$reviewed" ]] || continue               # ...changed since we reviewed it => another session's edit; keep the block
        fi
        _append_review_diff "$rf" "$key"
    done < <(sort -u "$SESSION_STATE")
}

# build_session_payload — CODE_FILES + PAYLOAD from this session's in-scope files, git-FREE. Re-callable:
# the commit path calls it again to re-derive the diff and confirm nothing changed during the (minutes-
# long) codex run before committing what was reviewed (TOCTOU guard). Also sets REVIEWED_KEYS /
# REVIEWED_HASHES — snapshot keys + current content hashes for exactly the files included in this review,
# so the terminal paths can advance/save <key>.reviewed / <key>.clean / <key>.findings for them.
build_session_payload() {
    CODE_FILES=""
    PAYLOAD=""
    REVIEWED_KEYS=()
    REVIEWED_HASHES=()
    local f key curhash reviewed _arc
    for f in "${SESSION_FILES[@]}"; do
        # SESSION_FILES is already canonical + in-scope (collect_session_files); a defensive containment
        # re-check keeps this safe even if a caller repopulates the array by other means.
        [[ "$f" == "$REPO_ROOT/"* ]] || continue
        # Per-turn gate: when we have this turn's write marker, review ONLY files this session wrote this
        # turn — a shared tracked file another session changed (but we did not touch) is skipped. Absent
        # marker -> no gate (cumulative fallback).
        if (( PENDING_PRESENT )) && [[ -z "${PENDING_SET[$f]:-}" ]]; then
            continue
        fi
        key=$(_snap_key "$f")
        curhash=$(_content_hash "$f")
        reviewed=""
        [[ -f "$SNAP_DIR/${key}.reviewed" ]] && reviewed=$(cat "$SNAP_DIR/${key}.reviewed" 2>/dev/null)
        # TRIGGER (git-free): content unchanged since this hook last reviewed it -> skip. This is the
        # "hello"/no-op turn: nothing this session wrote changed, so codex is never invoked.
        [[ "$curhash" == "$reviewed" ]] && continue
        _append_review_diff "$f" "$key"; _arc=$?
        if (( _arc == 2 )); then
            # Deletion with NO captured baseline (see _append_review_diff): the removed content is unknown, so a
            # CLEAN verdict must never vouch for it. Save a DURABLE block and DO NOT add it to the payload — the
            # CLEAN path only clears files in REVIEWED_KEYS, so this stays blocked and rides to the SessionEnd
            # UNREVIEWED sweep (the deletion is preserved, never committed as codex-approved).
            mkdir -p "$SNAP_DIR" 2>/dev/null && chmod 700 "$SNAP_DIR" 2>/dev/null
            printf '%s' "CODEX AUTO-REVIEW -- ${f#$REPO_ROOT/} was deleted but no session baseline was captured, so its removed content could not be shown to the reviewer. A deletion of unreviewed content cannot be codex-approved; it will be committed UNREVIEWED at SessionEnd." > "$SNAP_DIR/${key}.findings" 2>/dev/null
        elif (( _arc == 1 )); then
            # Content differs from the last-reviewed hash but produces NO baseline->current diff: a genuine
            # revert to the session baseline —
            #   * a PRESENT file byte-identical to its baseline (fix-by-revert, finding D), or
            #   * a DELETION of a file that was ABSENT at baseline (created this session, then removed).
            # An existing file (even an EMPTY one) that was DELETED is a real change -> leave its block so it
            # is never silently cleared without a CLEAN review. Empty <key>.base can't tell absent from
            # empty; the <key>.baseabsent marker can.
            # On a genuine revert, mark the content BOTH reviewed AND clean for the current hash (not only
            # when an open finding exists): the file is back to a known baseline state, nothing is left to
            # review. Without the .clean mark, build_commit_allowlist would withhold the reverted file and
            # the SessionEnd sweep would mislabel it UNREVIEWED.
            if [[ -f "$f" ]] || [[ -f "$SNAP_DIR/${key}.baseabsent" ]]; then
                mkdir -p "$SNAP_DIR" 2>/dev/null && chmod 700 "$SNAP_DIR" 2>/dev/null
                rm -f "$SNAP_DIR/${key}.findings" 2>/dev/null
                printf '%s' "$curhash" > "$SNAP_DIR/${key}.reviewed" 2>/dev/null
                printf '%s' "$curhash" > "$SNAP_DIR/${key}.clean" 2>/dev/null
            fi
        fi
    done
    # If anything changed, pull in the currently-open files so the whole blocked set re-reviews together.
    [[ -n "$PAYLOAD" ]] && _include_open_files
}

# advance_reviewed — record <key>.reviewed for every file in the CURRENT review, so a later no-change
# turn re-derives an empty payload and never re-invokes codex. Called on every terminal path that
# consulted codex (CLEAN, block, strike-bypass, reasoning-guard) — NOT on a transient outage, where a
# retry next turn is wanted.
advance_reviewed() {
    mkdir -p "$SNAP_DIR" 2>/dev/null && chmod 700 "$SNAP_DIR" 2>/dev/null
    local i
    for i in "${!REVIEWED_KEYS[@]}"; do
        printf '%s' "${REVIEWED_HASHES[$i]}" > "$SNAP_DIR/${REVIEWED_KEYS[$i]}.reviewed" 2>/dev/null
    done
}

# mark_clean — record <key>.clean (codex APPROVED this content). Only a file whose on-disk content still
# matches its .clean marker is allowed into the per-turn auto-commit.
mark_clean() {
    mkdir -p "$SNAP_DIR" 2>/dev/null && chmod 700 "$SNAP_DIR" 2>/dev/null
    local i
    for i in "${!REVIEWED_KEYS[@]}"; do
        printf '%s' "${REVIEWED_HASHES[$i]}" > "$SNAP_DIR/${REVIEWED_KEYS[$i]}.clean" 2>/dev/null
    done
}

# save_findings <text> — record <key>.findings for every file in the CURRENT review. A file with a
# .findings marker is OPEN (unresolved codex block at its last-reviewed content). This makes the block
# decision PER-FILE and independent of which files were reviewed this turn: an unrelated file going CLEAN
# can never drop another file's open block, and a reasoning-guard / TOCTOU block leaves a durable record
# so the turn keeps blocking until the file CHANGES (re-reviewed) or receives CLEAN.
save_findings() {
    mkdir -p "$SNAP_DIR" 2>/dev/null && chmod 700 "$SNAP_DIR" 2>/dev/null
    local i
    for i in "${!REVIEWED_KEYS[@]}"; do
        printf '%s' "$1" > "$SNAP_DIR/${REVIEWED_KEYS[$i]}.findings" 2>/dev/null
    done
}

# clear_reviewed_findings — drop <key>.findings for every file in the CURRENT review (codex returned
# CLEAN for this content, so its block is resolved).
clear_reviewed_findings() {
    local i
    for i in "${!REVIEWED_KEYS[@]}"; do
        rm -f "$SNAP_DIR/${REVIEWED_KEYS[$i]}.findings" 2>/dev/null
    done
}

# collect_open_findings — scan this session's in-scope files (canonicalize-first) for OPEN blocks; set
# OPEN_COUNT (how many files are open) + OPEN_FINDINGS (their DEDUPED findings text; files blocked in the
# same codex round share one text). A file currently approved (.clean matches disk) OR reverted to its
# baseline is not open — a stale marker there is reaped. This drives the block decision independently of
# the per-turn/pending review scope, so an unchanged blocked file keeps blocking without re-invoking codex.
collect_open_findings() {
    OPEN_COUNT=0
    OPEN_FINDINGS=""
    local f rf key ff ch h
    declare -A _open_seen=()
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        rf=$(realpath -m "$f" 2>/dev/null) || continue
        _in_review_scope "$rf" || continue
        key=$(_snap_key "$rf")
        ff="$SNAP_DIR/${key}.findings"
        [[ -f "$ff" ]] || continue
        if [[ -f "$SNAP_DIR/${key}.clean" ]]; then
            ch=$(_content_hash "$rf")
            [[ "$ch" == "$(cat "$SNAP_DIR/${key}.clean" 2>/dev/null)" ]] && { rm -f "$ff" 2>/dev/null; continue; }
        fi
        # Reverted to the session baseline (no baseline->current diff) -> the bad change is gone, so this
        # is no longer an open block -> reap the marker (defensive; build_session_payload also clears it
        # when the revert is a tracked write this turn — finding D).
        if [[ -f "$rf" ]]; then
            # Reverted to baseline only if a CAPTURED, non-absent baseline exists AND current content matches
            # it. Fail CLOSED otherwise: a file with no captured <key>.base (UNKNOWN baseline) or one marked
            # ABSENT (<key>.baseabsent — now present, so an ADD) must NOT have its block reaped on a bare
            # content match (against /dev/null / the empty base); its existence change is reviewable, not a
            # silent revert.
            [[ -e "$SNAP_DIR/${key}.base" && ! -f "$SNAP_DIR/${key}.baseabsent" ]] \
                && diff -q "$SNAP_DIR/${key}.base" "$rf" >/dev/null 2>&1 && { rm -f "$ff" 2>/dev/null; continue; }
        else
            # A DELETION reverts to the baseline ONLY if the file was EXPLICITLY absent at first touch
            # (<key>.baseabsent — created this session, then removed -> back to nothing). A file that EXISTED
            # at baseline (even an empty <key>.base) OR one with no captured baseline (UNKNOWN) is a REAL
            # deletion whose block must NOT be reaped without a CLEAN review (fail closed).
            [[ -f "$SNAP_DIR/${key}.baseabsent" ]] && { rm -f "$ff" 2>/dev/null; continue; }
        fi
        OPEN_COUNT=$((OPEN_COUNT + 1))
        h=$(sha256sum "$ff" 2>/dev/null | cut -d' ' -f1)
        [[ -n "${_open_seen[$h]:-}" ]] && continue
        _open_seen[$h]=1
        OPEN_FINDINGS+="$(cat "$ff" 2>/dev/null)"$'\n\n'
    done < <(sort -u "$SESSION_STATE")
}

# build_commit_allowlist — set $ALLOW_FILE to the repo-relative paths SAFE to auto-commit now: a
# review-scope code file ONLY if its current content is codex-approved (.clean matches disk), plus any
# session file OUTSIDE review scope (non-code files, e.g. .json/.txt/binaries) which was never gated. A blocked or
# not-yet-approved code file is deliberately omitted, so it is never committed as if clean; it waits for
# a CLEAN verdict or the SessionEnd UNREVIEWED sweep. Uses the SAME canonical-first scope predicate as
# the review side, so a traversal path cannot flip an in-scope code file to "out of scope, commit freely".
build_commit_allowlist() {
    # Fail CLOSED on mktemp failure: point ALLOW_FILE at /dev/null (an always-present EMPTY file) so the
    # commit gate matches nothing and commits NOTHING, rather than "" which commit_session_files would
    # read as "no allowlist -> commit everything" and sweep in blocked/unreviewed code.
    ALLOW_FILE=$(mktemp "${TMPDIR:-/tmp}/codex-commit-allow.XXXXXXXX" 2>/dev/null) || { ALLOW_FILE=/dev/null; return 0; }
    local f rf rel key curhash clean
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        rf=$(realpath -m "$f" 2>/dev/null) || continue
        [[ "$rf" == "$REPO_ROOT/"* ]] || continue
        rel="${rf#$REPO_ROOT/}"
        # Never allowlist a secret/credential/private-key/inventory/lab-host file for auto-commit, in or
        # out of review scope (kbupdate policy — AGENTS.md). commit_session_files enforces the same at the
        # SessionEnd sweep; this keeps the per-turn allowlist from even listing such a path.
        _is_sensitive_path "$rf" && continue
        if _in_review_scope "$rf"; then
            key=$(_snap_key "$rf")
            [[ -f "$SNAP_DIR/${key}.clean" ]] || continue          # in scope but never approved -> hold
            curhash=$(_content_hash "$rf")
            clean=$(cat "$SNAP_DIR/${key}.clean" 2>/dev/null)
            [[ "$curhash" == "$clean" ]] || continue               # approved content != disk -> hold
            # Withhold a file that was already dirty vs HEAD at first touch (pre-write recorded .predirty):
            # codex reviewed only baseline->current, but `git add` stages HEAD->current, so its pre-existing
            # hunks are UNREVIEWED. Never auto-commit it as approved; the SessionEnd UNREVIEWED sweep may take it.
            [[ -f "$SNAP_DIR/${key}.predirty" ]] && continue
            # Carry the approved hash: commit_session_files revalidates it immediately before staging, so a
            # concurrent edit in the window between here and `git add` cannot land UNREVIEWED bytes as clean.
            printf '%s\t%s\n' "$rel" "$curhash" >> "$ALLOW_FILE"
        else
            # Non-code, non-sensitive (settings.json, docs data, etc.). It is not codex-reviewed, but it is
            # still subject to the SAME two commit-safety checks as code: withhold if it was already dirty vs
            # HEAD at first touch (pre-write records .predirty for every touched path now, not just code), and
            # carry its current hash so commit_session_files revalidates it before staging (a concurrent
            # sibling-session edit in the window cannot be swept in wholesale as this session's work).
            key=$(_snap_key "$rf")
            [[ -f "$SNAP_DIR/${key}.predirty" ]] && continue
            printf '%s\t%s\n' "$rel" "$(_content_hash "$rf")" >> "$ALLOW_FILE"
        fi
    done < <(sort -u "$SESSION_STATE")
}

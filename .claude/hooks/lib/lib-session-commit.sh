#!/bin/bash
# lib-session-commit.sh - Shared "commit only THIS session's touched files" routine.
#
# One implementation, sourced by both stop-codex-review.sh (gated per-turn commit, after the codex
# review passes) and session-end-auto-commit.sh (ungated fallback at SessionEnd when review is off).
# Keeping it here means the two never drift.
#
#   commit_session_files <session_id> [subject] [note] [allow_file]
#     Stages + commits the files recorded in /tmp/claude-session-files/<sid>.txt that actually have
#     git changes (modified / staged / untracked). Commits ONLY those files — never a sibling
#     session's work. The state file is NOT deleted: already-committed files have no further changes
#     so they are naturally skipped on later turns, while new writes keep accumulating. Safe no-ops
#     on: empty session id, missing state file, a LIVE index.lock held, not in a repo, nothing to
#     commit. An ORPHANED index.lock (from a killed commit/push) is reaped, not skipped, on both
#     entry and exit — via lib-git-lock.sh — so a dead lock never lingers. Never pushes.
#     [subject] overrides the commit subject line (default: the plain session auto-commit).
#     [note] is prepended to the commit body — used by the SessionEnd sweep to mark commits of
#     files the codex review gate withheld (UNREVIEWED), so they are never mistaken for approved.
#     [allow_file] is an optional path to a file of newline-separated repo-relative paths — when set,
#     ONLY those paths are committed (still intersected with what actually changed). stop-codex-review.sh
#     passes it for the per-turn commit so a code file that codex has NOT approved (blocked/unreviewed)
#     is never auto-committed as if clean; an EMPTY allow_file commits nothing. Omit it (the SessionEnd
#     sweep does) to commit every changed session file — the ungated behavior.

if [[ -n "${_LIB_SESSION_COMMIT_LOADED:-}" ]]; then
    return 0
fi
_LIB_SESSION_COMMIT_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib-git-lock.sh"
# _is_sensitive_path — auto-commit (per-turn gate AND SessionEnd sweep) NEVER stages a secret/
# credential/private-key/inventory/host/lab-target file (shared with the review + baseline hooks).
source "$(dirname "${BASH_SOURCE[0]}")/lib-sensitive-path.sh"

# _commit_content_hash <path> — same fingerprint scheme as lib-codex-review-snapshot.sh _content_hash
# (sha256 of a present file, the "absent" sentinel for a missing one), so the allowlist's expected .clean
# hash can be revalidated here immediately before staging (TOCTOU guard).
_commit_content_hash() {
    if [[ -f "$1" ]]; then sha256sum "$1" 2>/dev/null | cut -d' ' -f1
    else printf 'absent'; fi
}

commit_session_files() {
    local session_id="$1"
    local subject="${2:-chore(session): auto-commit session changes}"
    local note="${3:-}"
    local allow_file="${4:-}"
    [[ -z "$session_id" ]] && return 0

    local state_file="/tmp/claude-session-files/${session_id}.txt"
    [[ -f "$state_file" ]] || return 0

    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
    # Canonicalize the repo root the SAME way the review side does (realpath -m). The session tracker
    # stores tool_input.file_path VERBATIM, which on Windows can arrive backslash-form (C:\a\b) while
    # git reports forward-slash (C:/a/b); a raw prefix match would then never contain the file and the
    # auto-commit would silently commit nothing. Canonicalizing both sides makes containment robust.
    repo_root=$(realpath -m "$repo_root" 2>/dev/null) || return 0

    # Reap an orphaned lock left by a killed commit/push, then skip if a LIVE git process still
    # holds it — avoids corrupting a concurrent commit while no longer jamming on a dead lock.
    clear_stale_index_lock "$repo_root"
    [[ -f "$repo_root/.git/index.lock" ]] && return 0

    # Collect session paths inside the repo that have ANY change. Use LITERAL, repo-relative
    # pathspecs (`:(literal)`): git pathspecs are globs by default, so a tracked file literally named
    # e.g. `*.ps1` would otherwise match unrelated files and sweep them past the per-session gate.
    # `git status --porcelain -- <spec>` reports modifications, staged content, untracked files AND
    # deletions/renames in one shot — so it does not skip a deleted path the way `-f` would.
    # Load the optional allowlist into a map: repo-relative path -> expected sha256 (or "-" for a
    # non-code file committed without a review hash). Lines are "<rel>\t<hash>". A NON-EMPTY allow_file
    # means the gate is active (even /dev/null -> empty map -> nothing committed, fail-closed); an EMPTY
    # allow_file (the SessionEnd sweep) leaves the gate off so all non-sensitive changes are swept.
    declare -A _allow_hash=()
    local _have_allow=0
    if [[ -n "$allow_file" ]]; then
        _have_allow=1
        if [[ -r "$allow_file" ]]; then
            local _ap _ah
            while IFS=$'\t' read -r _ap _ah; do
                [[ -z "$_ap" ]] && continue
                _allow_hash["$_ap"]="${_ah:--}"
            done < "$allow_file"
        fi
    fi

    local -a specs=()
    local filepath cfilepath rel exp_hash cur_hash
    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue
        # Canonicalize each tracked path (backslash->forward-slash, resolve ..) before containment so
        # the repo-relative pathspec below matches what git and the codex allowlist use.
        cfilepath=$(realpath -m "$filepath" 2>/dev/null) || continue
        case "$cfilepath" in
            "$repo_root"/*) ;;
            *) continue ;;
        esac
        rel="${cfilepath#$repo_root/}"
        # Never auto-commit a secret/credential/private-key/inventory/lab-host file — this is the single
        # choke point, so it also blocks the SessionEnd UNREVIEWED sweep (which passes no allowlist).
        _is_sensitive_path "$cfilepath" && continue
        # Per-file allowlist gate: a path NOT in the allowlist is skipped, and a path WITH an expected
        # review hash is revalidated NOW — if the on-disk bytes changed since the allowlist was built (a
        # concurrent edit in the TOCTOU window), do NOT commit them as codex-approved; skip and let the
        # next review round judge the new content. A "-" hash (non-code, no review) skips the recheck.
        if (( _have_allow )); then
            [[ -n "${_allow_hash[$rel]+x}" ]] || continue
            exp_hash="${_allow_hash[$rel]}"
            if [[ "$exp_hash" != "-" ]]; then
                cur_hash=$(_commit_content_hash "$cfilepath")
                [[ "$cur_hash" == "$exp_hash" ]] || continue
            fi
        fi
        if [[ -n "$(git -C "$repo_root" status --porcelain -- ":(literal)$rel" 2>/dev/null)" ]]; then
            specs+=(":(literal)$rel")
        fi
    done < <(sort -u "$state_file")

    [[ ${#specs[@]} -eq 0 ]] && return 0

    # Stage exactly these paths — `-A` records adds, modifications AND deletions. Then commit with an
    # explicit literal pathspec so ONLY these paths are committed: any unrelated content already
    # staged in the index (e.g. by a sibling session) is left untouched, not swept into this commit.
    # Suppress stdout/stderr — a calling Stop hook must emit only its own JSON, never git's summary.
    git -C "$repo_root" add -A -- "${specs[@]}" >/dev/null 2>&1

    local file_list body
    file_list=$(printf '%s\n' "${specs[@]}" | sed 's/^:(literal)/- /')
    body=$(printf 'Files modified during Claude session:\n\n%s' "$file_list")
    [[ -n "$note" ]] && body=$(printf '%s\n\n%s' "$note" "$body")

    # -m options MUST precede the `--` pathspec terminator, else they are parsed as path arguments.
    local rc
    git -C "$repo_root" commit --only \
        -m "$subject" \
        -m "$body" \
        -- "${specs[@]}" >/dev/null 2>&1
    rc=$?

    # Clean up our own litter. git removes its own lock on success AND on pre-commit rejection, so a
    # lock still present after a NON-ZERO commit is our own leftover from a crashed/torn-down git —
    # reap it now so it never sits there jamming the developer's next git command. On success (rc 0)
    # any lock is a sibling session's live commit, so we must NOT touch it.
    (( rc != 0 )) && reap_own_index_lock "$repo_root"

    return 0
}

#!/bin/bash
# lib-git-lock.sh - Reap an ORPHANED .git/index.lock so session hooks (and the developer) stop
# jamming on a lock nobody holds.
#
# Background: git takes .git/index.lock for the duration of any index-modifying operation
# (add / commit / reset / checkout / merge / stash) and removes it when the operation finishes —
# INCLUDING when a commit is rejected by a pre-commit hook. If the process is KILLED mid-operation
# (SIGKILL, a torn-down Stop/SessionEnd hook, or a VSCode auto-commit/push that is interrupted) the
# lock file is left behind. Every git command after that — the developer's included — then fails with
# "Unable to create '.git/index.lock': File exists" until someone deletes it by hand.
#
# The session-commit / changed-files helpers deliberately SKIP when the lock is present, to avoid
# corrupting a concurrent commit. That is correct for a live lock but leaves a dead lock to linger
# forever. This lib closes the gap with two calls:
#
#   clear_stale_index_lock <repo_root>   -- call on ENTRY, before the existing `[[ -f lock ]]` skip
#     guard. Reaps a lock only once it is STALE by age, so a genuinely in-flight commit is never
#     touched and the caller's own guard still skips on a live lock.
#
#     Why age, not liveness: git does NOT keep the lock's file descriptor open across a commit (it
#     closes the fd before running pre-commit hooks), so /proc-fd and fuser/lsof checks report a
#     busy commit as "not held" and would wrongly reap it. Age is the only reliable signal. A normal
#     commit here holds the lock ~1-2s (the .githooks/pre-commit scanner); orphaned locks age without
#     bound. Threshold picks between two ages using a system-wide `git` presence check ONLY as a
#     safety brake (it cannot tell WHICH repo a git process is working in, so it is never trusted to
#     reap, only to wait longer):
#       - no git process anywhere  -> the lock is orphaned          -> reap at _STALE_LOCK_IDLE_SECS
#       - some git process running -> a slow/interactive commit may still hold it -> reap only at the
#         much larger _STALE_LOCK_BUSY_SECS (last-resort recovery from a wedged git).
#
#   reap_own_index_lock <repo_root>   -- call on EXIT, ONLY after this hook's OWN `git commit`
#     returned NON-ZERO. git removes its own lock on both success and hook-rejection, so a lock still
#     present after our failed commit is unambiguously OUR litter (a crash that still returned control
#     to the shell). No other session could hold it: our leftover lock is exactly what blocks anyone
#     else from acquiring one. So it is reaped immediately, with no age wait — this is the hook
#     "cleaning up after itself" the instant it makes a mess.
#
# Both resolve the correct lock path for the main worktree AND linked worktrees via
# `git rev-parse --git-path`, and are safe no-ops outside a repo or with no lock present.

if [[ -n "${_LIB_GIT_LOCK_LOADED:-}" ]]; then
    return 0
fi
_LIB_GIT_LOCK_LOADED=1

_STALE_LOCK_IDLE_SECS=20     # no git running: a lock older than this is orphaned litter
_STALE_LOCK_BUSY_SECS=300    # some git running: only reap after 5 min (wedged-process fallback)

# Resolve the absolute path to this repo/worktree's index.lock. Echoes nothing (rc 1) outside a repo.
_index_lock_path() {
    local repo_root="${1:-.}" lock
    lock=$(git -C "$repo_root" rev-parse --git-path index.lock 2>/dev/null) || return 1
    # rev-parse returns a path relative to repo_root for the main worktree; make it absolute.
    [[ "$lock" != /* ]] && lock="$repo_root/$lock"
    printf '%s' "$lock"
}

clear_stale_index_lock() {
    local repo_root="${1:-.}" lock now mtime age threshold
    lock=$(_index_lock_path "$repo_root") || return 0
    [[ -f "$lock" ]] || return 0

    now=$(date +%s 2>/dev/null) || return 0
    mtime=$(stat -c %Y "$lock" 2>/dev/null) || return 0
    age=$(( now - mtime ))

    if command -v pgrep >/dev/null 2>&1 && pgrep -x git >/dev/null 2>&1; then
        threshold=$_STALE_LOCK_BUSY_SECS
    else
        threshold=$_STALE_LOCK_IDLE_SECS
    fi

    (( age >= threshold )) && rm -f "$lock" 2>/dev/null
    return 0
}

reap_own_index_lock() {
    local repo_root="${1:-.}" lock
    lock=$(_index_lock_path "$repo_root") || return 0
    [[ -f "$lock" ]] && rm -f "$lock" 2>/dev/null
    return 0
}

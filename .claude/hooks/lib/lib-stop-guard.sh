#!/bin/bash
# lib-stop-guard.sh - Prevents infinite re-entry of Stop hooks
#
# Uses a file-based marker tied to the transcript path. On first run,
# creates the marker and allows the hook to proceed. On subsequent runs
# (same transcript = same session), detects the marker and signals "skip."
#
# Two usage modes:
#
#   ADVISORY hooks (nudge once per session) — use the skip flag:
#       source "$(dirname "$0")/lib-stop-guard.sh"
#       if [[ "$STOP_GUARD_SKIP" == "true" ]]; then
#           exit 0
#       fi
#
#   BLOCKING hooks (enforce until satisfied) — skip the early-exit and route the
#   block through the budget so it re-fires every turn but never loops forever:
#       source "$(dirname "$0")/lib-stop-guard.sh"
#       BLOCK_JSON=""
#       if [[ <violation> ]]; then BLOCK_JSON=$(jq -n '{decision:"block",reason:...}'); fi
#       stop_guard_emit "${BLOCK_JSON:-}"
#       exit 0
#
# The marker and counter files auto-clean on next session (different transcript path).

if [[ -n "${_LIB_STOP_GUARD_LOADED:-}" ]]; then
    return 0
fi
_LIB_STOP_GUARD_LOADED=1

# stop_guard_emit <block_json_or_empty>
# Bounded re-entry budget for BLOCKING Stop hooks — the alternative to the
# once-per-session STOP_GUARD_SKIP early-exit. A blocking gate evaluates its
# state every turn and calls this with the block JSON it would emit, or "" when
# the bar is met:
#   - empty      -> satisfied this turn; reset the streak counter.
#   - non-empty  -> a violation. Increment a per-hook streak counter and either
#                     n <= STOP_GUARD_MAX_BLOCKS (default 3): emit the block, OR
#                     n >  max: emit a loud advisory instead and let the turn end
#                     (no infinite Stop->work->Stop loop). The counter stays armed
#                     until the violation clears, so a later recurrence re-blocks.
# This makes a gate enforce-until-satisfied instead of nudging once, while the
# strike cap guarantees the agent is never trapped. Defined before the early
# returns below so it exists even when there is no transcript. Counter files are
# keyed per hook per transcript and auto-clean with the markers.
stop_guard_emit() {
    local block_json="${1:-}"
    local trimmed="${block_json//[[:space:]]/}"

    # No transcript context (marker vars unset): cannot budget. Fail toward
    # enforcement — emit the block verbatim, never silently swallow it.
    if [[ -z "${_MARKER_DIR:-}" || -z "${_TRANSCRIPT_HASH:-}" || -z "${_HOOK_NAME:-}" ]]; then
        [[ -n "$trimmed" ]] && printf '%s\n' "$block_json"
        return 0
    fi

    local counter_file="${_MARKER_DIR}/${_TRANSCRIPT_HASH}_${_HOOK_NAME}.count"

    if [[ -z "$trimmed" ]]; then
        rm -f "$counter_file" 2>/dev/null
        return 0
    fi

    local n=0
    if [[ -f "$counter_file" ]]; then
        n=$(cat "$counter_file" 2>/dev/null || echo 0)
        [[ "$n" =~ ^[0-9]+$ ]] || n=0
    fi
    n=$((n + 1))
    printf '%s' "$n" > "$counter_file" 2>/dev/null || true

    local max="${STOP_GUARD_MAX_BLOCKS:-3}"
    if (( n <= max )); then
        printf '%s\n' "$block_json"
        return 0
    fi

    # Budget exhausted — downgrade to advisory so the agent is never trapped.
    local reason
    reason=$(printf '%s' "$block_json" | jq -r '.reason // "Quality gate not satisfied."' 2>/dev/null || echo "Quality gate not satisfied.")
    jq -n --arg n "$max" --arg hook "${_HOOK_NAME}" --arg reason "$reason" \
        '{systemMessage: ("GATE BYPASSED after " + $n + " blocked attempts (" + $hook + "). Allowing this turn to end so you are not stuck in a loop — the issue is NOT resolved. Fix it:\n\n" + $reason)}'
    return 0
}

STOP_GUARD_SKIP="false"

# Read stdin once and expose it
if [[ -z "${_STOP_HOOK_INPUT:-}" ]]; then
    _STOP_HOOK_INPUT=$(cat)
fi

# Extract transcript path for session-scoped marker
_TRANSCRIPT=$(echo "$_STOP_HOOK_INPUT" | jq -r '.transcript_path // empty')

if [[ -z "$_TRANSCRIPT" ]]; then
    # No transcript = can't track, allow but don't mark
    return 0
fi

# Derive a unique marker per hook per session
_HOOK_NAME=$(basename "${BASH_SOURCE[1]}" .sh)
_MARKER_DIR="/tmp/claude-stop-guards"
mkdir -p "$_MARKER_DIR"

# Use transcript path hash + hook name as marker
_TRANSCRIPT_HASH=$(echo "$_TRANSCRIPT" | md5sum | cut -d' ' -f1)
_MARKER_FILE="${_MARKER_DIR}/${_TRANSCRIPT_HASH}_${_HOOK_NAME}"

if [[ -f "$_MARKER_FILE" ]]; then
    STOP_GUARD_SKIP="true"
else
    touch "$_MARKER_FILE"
fi

# Clean up markers older than 1 hour (stale sessions)
find "$_MARKER_DIR" -type f -mmin +60 -delete 2>/dev/null

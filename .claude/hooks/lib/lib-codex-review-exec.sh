#!/bin/bash
# lib-codex-review-exec.sh - codex-exec support for stop-codex-review.sh, split by responsibility
# (400-line limit): the human-tailable live VIEW setup + hardening, the JSONL final-message parser,
# the suspicious-reasoning-token check, and the exec loop itself (codex_review_run + its reasoning-guard
# retry policy — moved out of the hook to keep it under the line limit).

if [[ -n "${_LIB_CODEX_REVIEW_EXEC_LOADED:-}" ]]; then
    return 0
fi
_LIB_CODEX_REVIEW_EXEC_LOADED=1

# codex_review_run — invoke codex (with the reasoning-guard retry policy) and set the outcome GLOBALS
# the gate acts on: REVIEW (codex's final message; empty on infra failure), RC (codex exit code), and
# CODEX_REASONING_GUARD_BLOCK (non-empty when the reasoning guard refused to trust codex -> the hook must
# block). Reads: PROMPT, REPO_ROOT, LIVE_LOG, and the CLAUDE_CODEX_REVIEW_* knobs. Each attempt captures
# codex's -o final message + JSONL stdout to PER-RUN mktemps (unguessable + 0600, so a stale/shared/
# refused/hostile file can never decide the verdict) and mirrors to the best-effort LIVE_LOG. tee is a
# real pipe stage, so RC comes from PIPESTATUS[1] (codex), not tee. On a suspicious fixed reasoning-token
# count it retries once (default) in a fresh ephemeral exec before trusting the result.
codex_review_run() {
    local max=${CLAUDE_CODEX_REVIEW_REASONING_RETRIES:-1}
    [[ "$max" =~ ^[0-9]+$ ]] || max=1
    local saw_suspicious=0 attempt tokens OUT_FILE RUN_LOG _f
    CODEX_REASONING_GUARD_BLOCK=""
    REVIEW=""
    RC=0

    # Model is codex's own default unless explicitly overridden (kbupdate convention: do not hardcode a
    # model -- an unavailable one would make every review fail-open). With --ignore-user-config an unset
    # override falls back to codex's compiled-in default, which is always valid.
    local -a model_args=()
    [[ -n "${CLAUDE_CODEX_REVIEW_MODEL:-}" ]] && model_args=(--model "$CLAUDE_CODEX_REVIEW_MODEL")

    for ((attempt=1; attempt<=max + 1; attempt++)); do
        # Per-run mktemps: fresh + private, so a stale file from an earlier round (which THIS run may not
        # rewrite) can never be re-read as this run's verdict, and concurrent Stop hooks cannot interleave.
        OUT_FILE=$(mktemp "${TMPDIR:-/tmp}/codex-review-out.XXXXXXXX" 2>/dev/null) || OUT_FILE=/dev/null
        RUN_LOG=$(mktemp "${TMPDIR:-/tmp}/codex-review.XXXXXXXX" 2>/dev/null) || RUN_LOG=/dev/null

        [[ "$LIVE_LOG" != /dev/null ]] && printf '===== codex auto-review attempt %s =====\n' "$attempt" >> "$LIVE_LOG" 2>/dev/null
        printf '%s' "$PROMPT" | timeout "${CLAUDE_CODEX_REVIEW_TIMEOUT:-600}" codex exec \
            --json \
            -C "$REPO_ROOT" \
            --sandbox read-only \
            --ignore-user-config \
            --ephemeral \
            --color never \
            "${model_args[@]}" \
            -o "$OUT_FILE" \
            -c model_reasoning_effort="${CLAUDE_CODEX_REVIEW_EFFORT:-high}" \
            - 2>/dev/null | tee -a "$LIVE_LOG" > "$RUN_LOG"
        RC=${PIPESTATUS[1]}                              # codex's exit through the pipe, NOT tee's

        tokens=$(jq -r 'select(.type == "turn.completed" and .usage.reasoning_output_tokens != null) | .usage.reasoning_output_tokens' "$RUN_LOG" 2>/dev/null | tail -1)
        REVIEW=$(codex_jsonl_final_message "$RUN_LOG")   # per-run private JSONL fallback (race-free)
        [[ -s "$OUT_FILE" ]] && REVIEW=$(cat "$OUT_FILE")   # prefer codex's clean final message when present
        for _f in "$RUN_LOG" "$OUT_FILE"; do [[ "$_f" != /dev/null ]] && rm -f "$_f" 2>/dev/null; done

        # Infra failures on the FIRST attempt still follow the hook's fail-open policy. But if we already
        # detected suspicious reasoning and the RETRY fails, we must block (can't trust the initial
        # suspicious result, and the retry didn't give us a clean answer).
        if [[ $RC -ne 0 || -z "$REVIEW" ]]; then
            if (( saw_suspicious > 0 )); then
                CODEX_REASONING_GUARD_BLOCK="CODEX AUTO-REVIEW reasoning guard refused to trust Codex after $attempt attempt(s): initial attempt had suspicious reasoning_output_tokens, and retry failed or produced no output. No files were committed. Re-run the review or inspect ~/.codex-review.live.log."
            fi
            break
        fi

        if codex_reasoning_is_suspicious "$tokens"; then
            saw_suspicious=1
            if (( attempt <= max )); then
                [[ "$LIVE_LOG" != /dev/null ]] && printf '===== reasoning guard: suspicious reasoning_output_tokens=%s; retrying =====\n' "$tokens" >> "$LIVE_LOG" 2>/dev/null
                continue
            fi
            CODEX_REASONING_GUARD_BLOCK="CODEX AUTO-REVIEW reasoning guard refused to trust Codex after $attempt attempt(s): final reasoning_output_tokens=$tokens matched suspicious fixed counts (${CLAUDE_CODEX_REVIEW_SUSPICIOUS_REASONING_TOKENS:-516 1034 1552}). No files were committed. Re-run the review or inspect ~/.codex-review.live.log."
        fi
        break
    done
}

# codex_review_setup_livelog — sets LIVE_LOG to the fixed, human-tailable view path, or /dev/null.
# View security: $HOME is used ONLY when genuinely private (owned by us, not group/world-writable) --
# a shared HOME would give the symlink/FIFO guards below a TOCTOU window. Then, before writing the
# view, refuse a symlink / non-regular file (FIFO/device/dir) / foreign-owned file and force 0600 on
# our own reused file (umask only affects creation, so a stale 0644 would leak). Any failure just
# drops the VIEW to /dev/null; REVIEW is unaffected (it comes from the private per-run captures).
# Consumes (globals): CODE_FILES. Sets: LIVE_LOG.
codex_review_setup_livelog() {
    LIVE_LOG=/dev/null
    local _hp _cand
    if [[ -n "${HOME:-}" && -O "$HOME" && ! -L "$HOME" ]]; then
        _hp=$(stat -c '%a' "$HOME" 2>/dev/null)
        if [[ -n "$_hp" && $(( 8#$_hp & 8#22 )) -eq 0 ]]; then
            _cand="$HOME/.codex-review.live.log"
            # Refuse a symlink / non-regular / foreign-owned entry. For a REUSED file, chmod 0600 must
            # SUCCEED before we write -- umask only sets the mode on creation, so writing into a
            # pre-existing file we couldn't tighten would leak the review; on chmod failure keep /dev/null.
            if [[ ! -L "$_cand" ]] && { [[ ! -e "$_cand" ]] || { [[ -f "$_cand" && -O "$_cand" ]]; }; } \
               && { [[ ! -e "$_cand" ]] || chmod 0600 "$_cand" 2>/dev/null; }; then
                ( umask 077; printf '===== codex auto-review %s | model=%s | effort=%s | %s =====\n' \
                    "$(date '+%H:%M:%S' 2>/dev/null)" "${CLAUDE_CODEX_REVIEW_MODEL:-codex default}" \
                    "${CLAUDE_CODEX_REVIEW_EFFORT:-high}" \
                    "$(printf '%s' "$CODE_FILES" | tr '\n' ' ')" > "$_cand" ) 2>/dev/null && LIVE_LOG="$_cand"
            fi
        fi
    fi
}

# codex_reasoning_is_suspicious <token-count> — true when the count matches a known-bad fixed value
# (see CLAUDE_CODEX_REVIEW_SUSPICIOUS_REASONING_TOKENS; the hook retries once before trusting it).
codex_reasoning_is_suspicious() {
    local token="$1"
    [[ "$token" =~ ^[0-9]+$ ]] || return 1
    local n
    for n in ${CLAUDE_CODEX_REVIEW_SUSPICIOUS_REASONING_TOKENS:-516 1034 1552}; do
        [[ "$token" == "$n" ]] && return 0
    done
    return 1
}

# codex_jsonl_final_message <jsonl-file> — prints codex's last agent message from its --json stream
# (the RUN_LOG fallback used when the -o final-message file is empty). Base64 round-trip keeps
# multi-line message text intact through the line-oriented jq pass.
codex_jsonl_final_message() {
    local jsonl="$1"
    local encoded
    encoded=$(jq -r '
        if .type == "item.completed" and .item.type == "agent_message" then
            (.item.text // .item.message // empty)
        elif .type == "agent_message" then
            (.message // .text // empty)
        else
            empty
        end
        | select(. != null)
        | @base64
    ' "$jsonl" 2>/dev/null | tail -1)
    [[ -n "$encoded" ]] && printf '%s' "$encoded" | base64 -d 2>/dev/null
}

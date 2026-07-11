#!/bin/bash
# lib-sensitive-path.sh - Single source of truth for "must this path's CONTENT be kept out of every
# automated channel — auto-commit, the codex review payload/live log, AND the /tmp baseline snapshot?"
# Sourced by lib-session-commit.sh (commit gate + SessionEnd sweep), lib-codex-review-snapshot.sh
# (review scope + commit allowlist), and infra/pre-write-snapshot-baseline.sh (baseline capture).
# kbupdate policy (AGENTS.md): never commit OR expose credentials, machine inventories, private host
# names, or raw lab addresses. A match is never reviewed, never snapshotted, never auto-committed — it
# is left entirely to the human.

if [[ -n "${_LIB_SENSITIVE_PATH_LOADED:-}" ]]; then
    return 0
fi
_LIB_SENSITIVE_PATH_LOADED=1

# _is_sensitive_path <path> — true if the basename characteristically holds a secret, private key/cert,
# credential/password store, machine inventory, private host list, or lab target. Case-insensitive
# (lowercased basename). Precision matters on this Windows/PowerShell repo:
#   * secret/key/cert/env file TYPES and credential/secret/password STORE names match on ANY extension;
#   * host/computer/inventory/lab tokens match ONLY on a DATA/config extension (.json/.csv/.txt/...),
#     so ordinary source/tests (New-PSWSUSComputerScope.ps1, Lab.ReadOnly.Integration.Tests.ps1,
#     DSC_xEnvironmentResource.psm1) are NEVER withheld — only data files that actually carry a host
#     list / inventory are. The lab token requires a lab-/lab_ separator so "Lab.ReadOnly" is not a hit.
_is_sensitive_path() {
    local base="${1##*/}"; base="${base,,}"
    # 1. Secret / key / cert / env / token file types — sensitive regardless of name.
    case "$base" in
        *.env|*.env.*|.env|.netrc|.pgpass|*.pem|*.key|*.pfx|*.p12|*.pkcs12|*.ppk|*.jks|*.keystore|*.pat) return 0 ;;
        id_rsa|id_rsa.*|id_dsa|id_dsa.*|id_ecdsa|id_ecdsa.*|id_ed25519|id_ed25519.*) return 0 ;;
    esac
    # 2. Credential / secret / password stores — sensitive regardless of extension.
    case "$base" in
        secret|secrets|secret.*|secrets.*|*.secret.*|*.secrets.*) return 0 ;;
        credential|credentials|credential.*|credentials.*|*.credential.*|*.credentials.*) return 0 ;;
        password|passwords|password.*|passwords.*|*.password.*|*.passwords.*) return 0 ;;
    esac
    # 3a. Machine inventories / private host lists / lab targets as DATA/config/office files — these
    #     are inventories regardless of which host/computer/inventory/lab token appears in the name.
    case "$base" in
        *host*|*computer*|*inventory*|*lab-*|*lab_*)
            case "$base" in
                *.json|*.jsonl|*.csv|*.tsv|*.txt|*.xml|*.yml|*.yaml|*.ini|*.cfg|*.conf|*.config|*.list|*.dat|*.xlsx|*.xls|*.xlsm|*.ods|*.psd1|*.pson|*.clixml|*.mof|*.reg|*.parquet) return 0 ;;
            esac ;;
    esac
    # 3b. CODE files (.ps1/.psm1/.sh) are usually source and ARE reviewed (which catches embedded secrets),
    #     so the common host/computer tokens are NOT failed closed for code — they appear in legitimate
    #     cmdlet names (Get-ComputerInfo.ps1, New-PSWSUSComputerScope.ps1). But an inventory / lab-target
    #     name is a strong signal the file is data masquerading as a script -> fail closed for those tokens.
    case "$base" in
        *inventory*|*lab-*|*lab_*)
            case "$base" in
                *.ps1|*.psm1|*.sh) return 0 ;;
            esac ;;
    esac
    return 1
}

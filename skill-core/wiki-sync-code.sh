#!/usr/bin/env bash
# wiki-sync-code — Sync git repos and rebuild Graphify code graph
# Usage: wiki-sync-code [--repo <repo_name>] [--all] [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

REPO_NAME=""
SYNC_ALL=false
FORCE=false

# ── Parse args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)     REPO_NAME="$2"; shift 2 ;;
        --all)      SYNC_ALL=true; shift ;;
        --force)    FORCE=true; shift ;;
        -h|--help)
            echo "Usage: wiki-sync-code [--repo <name>] [--all] [--force]"
            echo ""
            echo "Examples:"
            echo "  wiki-sync-code --repo backend"
            echo "  wiki-sync-code --all"
            echo "  wiki-sync-code --all --force  # Force rebuild regardless of cache"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Pre-checks ─────────────────────────────────────────────────────────────
require_lark_cli
require_git
require_graphify
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)

REPOS_ROOT="${RAW_DIR}/30-development/git-repos"

if [[ ! -d "$REPOS_ROOT" ]]; then
    log_error "No git-repos directory found. Add repos first:"
    echo "  mkdir -p ${REPOS_ROOT}"
    echo "  git clone <url> ${REPOS_ROOT}/<name>"
    exit 1
fi

# ── Determine which repos to sync ──────────────────────────────────────────
REPOS_TO_SYNC=()

if [[ -n "$REPO_NAME" ]]; then
    if [[ ! -d "${REPOS_ROOT}/${REPO_NAME}/.git" ]]; then
        log_error "Repo not found: ${REPOS_ROOT}/${REPO_NAME}"
        exit 1
    fi
    REPOS_TO_SYNC=("$REPO_NAME")
elif [[ "$SYNC_ALL" == true ]]; then
    for repo_dir in "${REPOS_ROOT}"/*/.git; do
        if [[ -d "$repo_dir" ]]; then
            REPOS_TO_SYNC+=("$(basename "$(dirname "$repo_dir")")")
        fi
    done
    if [[ ${#REPOS_TO_SYNC[@]} -eq 0 ]]; then
        log_error "No git repos found in ${REPOS_ROOT}"
        exit 1
    fi
else
    # Default: sync repos with uncommitted changes or stale cache
    log_info "Checking repo status..."
    for repo_dir in "${REPOS_ROOT}"/*/.git; do
        if [[ -d "$repo_dir" ]]; then
            name=$(basename "$(dirname "$repo_dir")")
            if [[ "$FORCE" == true ]] || is_graph_stale "$(dirname "$repo_dir")"; then
                REPOS_TO_SYNC+=("$name")
            fi
        fi
    done
    if [[ ${#REPOS_TO_SYNC[@]} -eq 0 ]]; then
        log_ok "All repos up to date. Use --force to rebuild anyway."
        exit 0
    fi
fi

log_info "Repos to sync: ${REPOS_TO_SYNC[*]}"

# ── Sync each repo ─────────────────────────────────────────────────────────
CHANGES_SUMMARY=""

for name in "${REPOS_TO_SYNC[@]}"; do
    repo_dir="${REPOS_ROOT}/${name}"
    log_info "═══ Syncing: ${name} ═══"

    # Step 1: git pull
    log_info "[${name}] Pulling latest changes..."
    PULL_OUTPUT=$(cd "$repo_dir" && git pull 2>&1) || {
        log_warn "[${name}] Git pull failed or no remote: $PULL_OUTPUT"
        PULL_OUTPUT="(no remote or failed)"
    }
    log_ok "[${name}] Git: $PULL_OUTPUT"

    # Get current HEAD
    HEAD_HASH=$(cd "$repo_dir" && git rev-parse --short HEAD)
    PREV_HASH=$(config_get ".git_repos.\"${name}\".last_sync_hash" "none")

    if [[ "$HEAD_HASH" == "$PREV_HASH" && "$FORCE" != true ]]; then
        log_info "[${name}] No new commits (HEAD: ${HEAD_HASH}). Skipping Graphify."
        continue
    fi

    log_info "[${name}] ${PREV_HASH} → ${HEAD_HASH}"

    # Step 2: Graphify build
    log_info "[${name}] Running Graphify..."
    GRAPHIFY_OUT=$(cd "$repo_dir" && graphify build . --update 2>&1) || {
        log_error "[${name}] Graphify build failed: $GRAPHIFY_OUT"
        continue
    }
    log_ok "[${name}] Graphify build complete"

    # Step 3: Read GRAPH_REPORT
    REPORT_FILE="${repo_dir}/graphify-out/GRAPH_REPORT.md"
    if [[ -f "$REPORT_FILE" ]]; then
        # Extract key insights
        GOD_NODES=$(grep -A5 "God Nodes" "$REPORT_FILE" 2>/dev/null | head -20 || true)
        COMMUNITIES=$(grep -A5 "Community" "$REPORT_FILE" 2>/dev/null | head -20 || true)
        SURPRISE=$(grep -A5 "Surprise" "$REPORT_FILE" 2>/dev/null | head -20 || true)

        CHANGES_SUMMARY="${CHANGES_SUMMARY}\n\n## Repo: ${name}\nHash: ${HEAD_HASH}\n"
        [[ -n "$GOD_NODES" ]] && CHANGES_SUMMARY="${CHANGES_SUMMARY}\n### God Nodes\n${GOD_NODES}\n"
        [[ -n "$COMMUNITIES" ]] && CHANGES_SUMMARY="${CHANGES_SUMMARY}\n### Communities\n${COMMUNITIES}\n"
        [[ -n "$SURPRISE" ]] && CHANGES_SUMMARY="${CHANGES_SUMMARY}\n### Surprise Edges\n${SURPRISE}\n"
    fi

    # Step 4: Update cache hash
    config_set ".git_repos.\"${name}\".last_sync_hash" "$HEAD_HASH"
    config_set ".git_repos.\"${name}\".last_sync_time" "$(now)"
    log_ok "[${name}] Cache updated"
done

# ── Write summary to Feishu wiki ───────────────────────────────────────────
if [[ -n "$CHANGES_SUMMARY" ]]; then
    log_info "Writing sync summary to wiki..."

    SUMMARY_DOC="# Code Sync Summary — $(today)\n\n**Repos synced**: ${#REPOS_TO_SYNC[@]}\n**Triggered by**: ${FORCE:+force rebuild}${FORCE:-auto (stale cache)}\n\n---\n${CHANGES_SUMMARY}\n\n---\n\n## Action Items for LLM\n1. Update affected CodeModule entity pages\n2. Check for new God Nodes — may indicate architectural hotspots\n3. Review Surprise Edges — unexpected cross-module dependencies\n4. Update index with new/changed entities\n"

    DOC_TITLE="Code-Sync-$(today)"
    DOC_OUT=$(echo "$SUMMARY_DOC" | lark-cli docs +create \
        --title "$DOC_TITLE" \
        --folder-token "$WIKI_FOLDER_TOKEN" \
        --markdown "$SUMMARY_DOC" 2>&1) || {
        log_warn "Failed to create summary doc: $DOC_OUT"
    }
    DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
    [[ -n "$DOC_TOKEN" ]] && log_ok "Summary doc: ${DOC_TOKEN}"

    # Update log
    LOG_TOKEN=$(config_get '.feishu_drive.log_doc_token' '')
    if [[ -n "$LOG_TOKEN" ]]; then
        LOG_ENTRY="\n## [$(today)] sync-code | ${#REPOS_TO_SYNC[@]} repos\n- Repos: ${REPOS_TO_SYNC[*]}\n- Summary: ${DOC_TOKEN:-inline}\n"
        lark-cli docs +update "$LOG_TOKEN" \
            --content "$(echo "$LOG_ENTRY" | sed 's/"/\\"/g')" 2>/dev/null || true
    fi
fi

echo ""
log_ok "Code sync complete. ${#REPOS_TO_SYNC[@]} repo(s) processed."

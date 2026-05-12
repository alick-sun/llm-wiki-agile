#!/usr/bin/env bash
# wiki-sync-code — Sync git repos and rebuild Graphify code graph
# Usage: wiki-sync-code [--repo <name>] [--all] [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/wiki-config.json"
RAW_DIR="${PROJECT_ROOT}/raw"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

config_get() {
    local key="$1" default="${2:-}"
    if [[ -f "$CONFIG_FILE" ]]; then
        local val; val=$(jq -r "$key // empty" "$CONFIG_FILE" 2>/dev/null || true)
        [[ -n "$val" && "$val" != "null" ]] && { echo "$val"; return; }
    fi
    echo "$default"
}
config_set() {
    local key="$1" val="$2"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    [[ ! -f "$CONFIG_FILE" ]] && echo '{}' > "$CONFIG_FILE"
    local tmp; tmp=$(mktemp)
    jq "$key = \"$val\"" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
}
get_wiki_folder_token() {
    local token; token=$(config_get '.feishu_drive.wiki_folder_token' '')
    [[ -z "$token" ]] && { log_error "Not initialized. Run wiki-init."; exit 1; }
    echo "$token"
}
extract_doc_token() { echo "$1" | grep -oE 'doxcn[A-Za-z0-9]+' | head -1; }
is_graph_stale() {
    local repo_dir="$1"
    local cache_file="${repo_dir}/.graphify/cache.json"
    [[ ! -f "$cache_file" ]] && return 0
    local current_hash; current_hash=$(cd "$repo_dir" && git rev-parse HEAD 2>/dev/null || echo "")
    local cached_hash; cached_hash=$(jq -r '.last_commit_hash // empty' "$cache_file" 2>/dev/null || true)
    [[ "$current_hash" != "$cached_hash" ]]
}
today() { date +"%Y-%m-%d"; }
now() { date +"%Y-%m-%d %H:%M"; }

# ── Args ──
REPO_NAME=""; SYNC_ALL=false; FORCE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)  REPO_NAME="$2"; shift 2 ;;
        --all)   SYNC_ALL=true; shift ;;
        --force) FORCE=true; shift ;;
        -h|--help) echo "Usage: wiki-sync-code [--repo <name>] [--all] [--force]"; exit 0 ;;
        *) log_error "Unknown: $1"; exit 1 ;;
    esac
done

# ── Pre-checks ──
for cmd in lark-cli git graphify; do
    command -v "$cmd" &>/dev/null || { log_error "${cmd} not found"; exit 1; }
done
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)
REPOS_ROOT="${RAW_DIR}/30-development/git-repos"
[[ ! -d "$REPOS_ROOT" ]] && { log_error "No git-repos. Clone first."; exit 1; }

# ── Determine repos ──
REPOS_TO_SYNC=()
if [[ -n "$REPO_NAME" ]]; then
    [[ ! -d "${REPOS_ROOT}/${REPO_NAME}/.git" ]] && { log_error "Repo not found: ${REPO_NAME}"; exit 1; }
    REPOS_TO_SYNC=("$REPO_NAME")
elif [[ "$SYNC_ALL" == true ]]; then
    for d in "${REPOS_ROOT}"/*/.git; do
        [[ -d "$d" ]] && REPOS_TO_SYNC+=("$(basename "$(dirname "$d")")")
    done
else
    for d in "${REPOS_ROOT}"/*/.git; do
        [[ -d "$d" ]] || continue
        name=$(basename "$(dirname "$d")")
        [[ "$FORCE" == true ]] || is_graph_stale "$(dirname "$d")" && REPOS_TO_SYNC+=("$name")
    done
    [[ ${#REPOS_TO_SYNC[@]} -eq 0 ]] && { log_ok "All repos up to date"; exit 0; }
fi

log_info "Syncing: ${REPOS_TO_SYNC[*]}"
CHANGES=""

for name in "${REPOS_TO_SYNC[@]}"; do
    repo_dir="${REPOS_ROOT}/${name}"
    log_info "═══ ${name} ═══"

    # Git pull
    PULL_OUT=$(cd "$repo_dir" && git pull 2>&1) || { log_warn "Pull failed: $PULL_OUT"; PULL_OUT="(no remote)"; }
    log_ok "Git: $PULL_OUT"

    HEAD_HASH=$(cd "$repo_dir" && git rev-parse --short HEAD)
    PREV_HASH=$(config_get ".git_repos.\"${name}\".last_sync_hash" "none")
    [[ "$HEAD_HASH" == "$PREV_HASH" && "$FORCE" != true ]] && { log_info "No changes"; continue; }
    log_info "${PREV_HASH} → ${HEAD_HASH}"

    # Graphify build
    GRAPHIFY_OUT=$(cd "$repo_dir" && graphify build . --update 2>&1) || {
        log_error "Graphify failed: $GRAPHIFY_OUT"; continue
    }
    log_ok "Graphify done"

    # Extract insights
    REPORT="${repo_dir}/graphify-out/GRAPH_REPORT.md"
    if [[ -f "$REPORT" ]]; then
        GOD=$(grep -A5 "God Nodes" "$REPORT" 2>/dev/null | head -15 || true)
        COMM=$(grep -A5 "Community" "$REPORT" 2>/dev/null | head -15 || true)
        SURP=$(grep -A5 "Surprise" "$REPORT" 2>/dev/null | head -15 || true)
        CHANGES="${CHANGES}\n\n## ${name}\nHash: ${HEAD_HASH}\n"
        [[ -n "$GOD" ]] && CHANGES="${CHANGES}\n### God Nodes\n${GOD}\n"
        [[ -n "$COMM" ]] && CHANGES="${CHANGES}\n### Communities\n${COMM}\n"
        [[ -n "$SURP" ]] && CHANGES="${CHANGES}\n### Surprise Edges\n${SURP}\n"
    fi

    config_set ".git_repos.\"${name}\".last_sync_hash" "$HEAD_HASH"
    config_set ".git_repos.\"${name}\".last_sync_time" "$(now)"
done

# ── Write summary ──
if [[ -n "$CHANGES" ]]; then
    SUMMARY="# Code Sync — $(today)\n\nRepos: ${#REPOS_TO_SYNC[@]}\n${CHANGES}\n\n## Action Items\n1. Update CodeModule entity pages\n2. Check God Nodes for architectural hotspots\n3. Review Surprise Edges\n"
    DOC_OUT=$(echo "$SUMMARY" | lark-cli docs +create --title "Code-Sync-$(today)" --folder-token "$WIKI_FOLDER_TOKEN" --markdown "$SUMMARY" 2>&1) || log_warn "Summary save failed"
    DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
    [[ -n "$DOC_TOKEN" ]] && log_ok "Summary: ${DOC_TOKEN}"

    LOG_TOKEN=$(config_get '.feishu_drive.log_doc_token' '')
    [[ -n "$LOG_TOKEN" ]] && {
        LOG_ENTRY="\n## [$(today)] sync-code | ${#REPOS_TO_SYNC[@]} repos\n- ${REPOS_TO_SYNC[*]}\n"
        lark-cli docs +update "$LOG_TOKEN" --content "$(echo "$LOG_ENTRY" | sed 's/"/\\"/g')" 2>/dev/null || true
    }
fi

log_ok "Done. ${#REPOS_TO_SYNC[@]} repo(s)."

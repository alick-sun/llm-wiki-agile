#!/usr/bin/env bash
# wiki-query — Query the wiki (graph structure + document content)
# Usage: wiki-query "<question>" [--save] [--title <title>]

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

get_wiki_folder_token() {
    local token; token=$(config_get '.feishu_drive.wiki_folder_token' '')
    [[ -z "$token" ]] && { log_error "Not initialized. Run wiki-init first."; exit 1; }
    echo "$token"
}

extract_doc_token() {
    local output="$1"
    echo "$output" | grep -oE 'doxcn[A-Za-z0-9]+' | head -1
}

today() { date +"%Y-%m-%d"; }
now() { date +"%Y-%m-%d %H:%M"; }

# ── Parse args ──
QUESTION=""
SAVE=false
SAVE_TITLE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --save)     SAVE=true; shift ;;
        --title)    SAVE_TITLE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: wiki-query '<question>' [--save] [--title <title>]"; exit 0 ;;
        *)
            [[ -z "$QUESTION" ]] && QUESTION="$1" || QUESTION="$QUESTION $1"
            shift ;;
    esac
done

[[ -z "$QUESTION" ]] && { log_error "No question provided"; exit 1; }

if ! command -v lark-cli &>/dev/null; then
    log_error "lark-cli not found. Install: npm install -g @larksuite/cli"
    exit 1
fi
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)

log_info "Query: ${QUESTION}"

# ── Step 1: Graphify query ──
GRAPHIFY_RESULTS=""
if command -v graphify &>/dev/null; then
    log_info "Querying Graphify..."
    for repo_dir in "${RAW_DIR}/30-development/git-repos/"*/; do
        [[ -d "${repo_dir}/graphify-out" ]] || continue
        REPO_RESULTS=$(cd "$repo_dir" && graphify query "$QUESTION" 2>/dev/null || true)
        [[ -n "$REPO_RESULTS" ]] && GRAPHIFY_RESULTS="${GRAPHIFY_RESULTS}\n## Code Graph ($(basename "$repo_dir"))\n${REPO_RESULTS}"
    done
    [[ -z "$GRAPHIFY_RESULTS" ]] && log_info "No graph results"
else
    log_info "Graphify not available"
fi

# ── Step 2: Search Feishu ──
log_info "Searching Feishu..."
SEARCH_RESULTS=$(lark-cli drive +search "$QUESTION" --folder-token "$WIKI_FOLDER_TOKEN" --doc-types docx 2>/dev/null || true)
[[ -z "$SEARCH_RESULTS" ]] && SEARCH_RESULTS=$(lark-cli drive +search "$QUESTION" 2>/dev/null || true)

# ── Step 3: Fetch top docs ──
FETCHED_DOCS=""
if [[ -n "$SEARCH_RESULTS" ]]; then
    DOC_TOKENS=$(echo "$SEARCH_RESULTS" | grep -oE 'doxcn[A-Za-z0-9]+' | head -5 || true)
    if [[ -n "$DOC_TOKENS" ]]; then
        log_info "Fetching documents..."
        for token in $DOC_TOKENS; do
            DOC_CONTENT=$(lark-cli docs +fetch "$token" 2>/dev/null || true)
            [[ -n "$DOC_CONTENT" ]] && FETCHED_DOCS="${FETCHED_DOCS}\n---\nDoc: ${token}\n${DOC_CONTENT}\n---\n"
        done
    fi
fi

# ── Step 4: Fetch index ──
INDEX_TOKEN=$(config_get '.feishu_drive.index_doc_token' '')
INDEX_CONTENT=""
[[ -n "$INDEX_TOKEN" ]] && INDEX_CONTENT=$(lark-cli docs +fetch "$INDEX_TOKEN" 2>/dev/null || true)

# ── Output context ──
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  QUERY CONTEXT"
echo "═══════════════════════════════════════════════════════════════"

[[ -n "$GRAPHIFY_RESULTS" ]] && { echo ""; echo "## CODE STRUCTURE"; echo "$GRAPHIFY_RESULTS"; }
[[ -n "$INDEX_CONTENT" ]] && { echo ""; echo "## WIKI INDEX"; echo "$INDEX_CONTENT"; }
[[ -n "$FETCHED_DOCS" ]] && { echo ""; echo "## RELEVANT DOCUMENTS"; echo "$FETCHED_DOCS"; }

echo ""
echo "## QUESTION"
echo "$QUESTION"
echo "═══════════════════════════════════════════════════════════════"

# ── Optional: save ──
if [[ "$SAVE" == true ]]; then
    SAVE_TITLE="${SAVE_TITLE:-Q: $(echo "$QUESTION" | cut -c1-50)}"
    TEMPLATE="# ${SAVE_TITLE}\n\n**Q**: ${QUESTION}\n**Queried**: $(now)\n\n> LLM: Provide synthesized answer here.\n"
    DOC_OUT=$(echo "$TEMPLATE" | lark-cli docs +create --title "$SAVE_TITLE" --folder-token "$WIKI_FOLDER_TOKEN" --markdown "$TEMPLATE" 2>&1) || {
        log_error "Save failed: $DOC_OUT"; exit 1
    }
    DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
    [[ -n "$DOC_TOKEN" ]] && log_ok "Saved: ${DOC_TOKEN}"
fi

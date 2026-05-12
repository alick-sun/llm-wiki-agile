#!/usr/bin/env bash
# wiki-query — Query the wiki (graph structure + document content)
# Usage: wiki-query "<natural language question>" [--save] [--title <title>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

QUESTION=""
SAVE=false
SAVE_TITLE=""

# ── Parse args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --save)     SAVE=true; shift ;;
        --title)    SAVE_TITLE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: wiki-query '<question>' [--save] [--title <title>]"
            echo ""
            echo "Examples:"
            echo "  wiki-query 'How does authentication work?'"
            echo "  wiki-query 'Show me the payment flow' --save --title 'Payment Flow Analysis'"
            exit 0
            ;;
        *)
            if [[ -z "$QUESTION" ]]; then
                QUESTION="$1"
                shift
            else
                QUESTION="$QUESTION $1"
                shift
            fi
            ;;
    esac
done

if [[ -z "$QUESTION" ]]; then
    log_error "No question provided. Use: wiki-query '<question>'"
    exit 1
fi

# ── Pre-checks ─────────────────────────────────────────────────────────────
require_lark_cli
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)

log_info "Query: ${QUESTION}"

# ── Step 1: Query Graphify (if available) ──────────────────────────────────
GRAPHIFY_RESULTS=""
if command -v graphify &>/dev/null; then
    log_info "Querying Graphify knowledge graph..."
    for repo_dir in "${RAW_DIR}/30-development/git-repos/"*/; do
        if [[ -d "${repo_dir}/graphify-out" ]]; then
            REPO_RESULTS=$(graphify query "$QUESTION" "${repo_dir}" 2>/dev/null || true)
            if [[ -n "$REPO_RESULTS" ]]; then
                GRAPHIFY_RESULTS="${GRAPHIFY_RESULTS}\n## Code Graph Results (${repo_dir})\n${REPO_RESULTS}"
            fi
        fi
    done
    if [[ -z "$GRAPHIFY_RESULTS" ]]; then
        log_info "No graph results (repos may not be indexed yet)"
    fi
else
    log_info "Graphify not available, skipping graph query"
fi

# ── Step 2: Search Feishu wiki documents ───────────────────────────────────
log_info "Searching Feishu wiki..."

# Use drive +search
SEARCH_RESULTS=$(lark-cli drive +search "$QUESTION" \
    --folder-token "$WIKI_FOLDER_TOKEN" \
    --doc-types docx 2>/dev/null || true)

if [[ -z "$SEARCH_RESULTS" ]]; then
    log_warn "No direct search results, trying broader search..."
    SEARCH_RESULTS=$(lark-cli drive +search "$QUESTION" 2>/dev/null || true)
fi

# ── Step 3: Fetch top documents ────────────────────────────────────────────
FETCHED_DOCS=""
if [[ -n "$SEARCH_RESULTS" ]]; then
    # Extract doc tokens from search results
    DOC_TOKENS=$(echo "$SEARCH_RESULTS" | grep -oE 'doxcn[A-Za-z0-9]+' | head -5 || true)

    if [[ -n "$DOC_TOKENS" ]]; then
        log_info "Fetching top documents..."
        for token in $DOC_TOKENS; do
            DOC_CONTENT=$(lark-cli docs +fetch "$token" 2>/dev/null || true)
            if [[ -n "$DOC_CONTENT" ]]; then
                FETCHED_DOCS="${FETCHED_DOCS}\n---\nDocument: ${token}\n${DOC_CONTENT}\n---\n"
            fi
        done
    fi
fi

# ── Step 4: Fetch index ────────────────────────────────────────────────────
INDEX_TOKEN=$(config_get '.feishu_drive.index_doc_token' '')
INDEX_CONTENT=""
if [[ -n "$INDEX_TOKEN" ]]; then
    INDEX_CONTENT=$(lark-cli docs +fetch "$INDEX_TOKEN" 2>/dev/null || true)
fi

# ── Step 5: Compile context for LLM ────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  QUERY CONTEXT (provide this to your LLM)"
echo "═══════════════════════════════════════════════════════════════"

if [[ -n "$GRAPHIFY_RESULTS" ]]; then
    echo ""
    echo "## CODE STRUCTURE INSIGHTS"
    echo "$GRAPHIFY_RESULTS"
fi

if [[ -n "$INDEX_CONTENT" ]]; then
    echo ""
    echo "## WIKI INDEX"
    echo "$INDEX_CONTENT"
fi

if [[ -n "$FETCHED_DOCS" ]]; then
    echo ""
    echo "## RELEVANT DOCUMENTS"
    echo "$FETCHED_DOCS"
else
    echo ""
    echo "## NOTE"
    echo "No matching documents found in wiki. The knowledge base may be empty or the question is outside current scope."
fi

echo ""
echo "## USER QUESTION"
echo "$QUESTION"
echo ""
echo "═══════════════════════════════════════════════════════════════"

# ── Step 6: Optional — save back to wiki ───────────────────────────────────
if [[ "$SAVE" == true ]]; then
    log_info "Saving answer to wiki..."

    SAVE_TITLE="${SAVE_TITLE:-Q: $(echo "$QUESTION" | cut -c1-50)}"

    ANSWER_TEMPLATE="# ${SAVE_TITLE}\n\n**Question**: ${QUESTION}\n**Queried**: $(now)\n**Sources**: Auto-search + graph query\n\n> LLM: Please provide your synthesized answer here.\n> This document will be saved to the wiki as a new synthesis page.\n"

    DOC_OUT=$(echo "$ANSWER_TEMPLATE" | lark-cli docs +create \
        --title "$SAVE_TITLE" \
        --folder-token "$WIKI_FOLDER_TOKEN" \
        --markdown "$ANSWER_TEMPLATE" 2>&1) || {
        log_error "Failed to save answer doc: $DOC_OUT"
        exit 1
    }

    DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
    if [[ -n "$DOC_TOKEN" ]]; then
        log_ok "Answer doc created: ${DOC_TOKEN}"
        echo ""
        echo "Provide your answer to the LLM, then ask it to update doc ${DOC_TOKEN}"
    fi
fi

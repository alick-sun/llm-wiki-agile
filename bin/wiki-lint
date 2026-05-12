#!/usr/bin/env bash
# wiki-lint — Health check the wiki
# Usage: wiki-lint [--fix] [--focus all|structure|graph|content]

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
    [[ -z "$token" ]] && { log_error "Not initialized. Run wiki-init."; exit 1; }
    echo "$token"
}
extract_doc_token() { echo "$1" | grep -oE 'doxcn[A-Za-z0-9]+' | head -1; }
extract_entity_type() {
    local file="$1"
    grep -m1 '^type:' "$file" 2>/dev/null | sed 's/type: *//' | tr -d ' "' || true
}
today() { date +"%Y-%m-%d"; }

# ── Args ──
FIX=false; FOCUS="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)   FIX=true; shift ;;
        --focus) FOCUS="$2"; shift 2 ;;
        -h|--help) echo "Usage: wiki-lint [--fix] [--focus <area>]"; exit 0 ;;
        *) log_error "Unknown: $1"; exit 1 ;;
    esac
done

command -v lark-cli &>/dev/null || { log_error "lark-cli required"; exit 1; }
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)

REPORT="# Lint Report — $(today)\n\n**Focus**: ${FOCUS}\n\n"
ISSUES=0; WARNINGS=0

# ═══ STRUCTURE ═══
if [[ "$FOCUS" == "all" || "$FOCUS" == "structure" ]]; then
    log_info "Checking structure..."
    REPORT="${REPORT}## Structure\n\n"

    DRIVE_FILES=$(lark-cli drive files list --folder-token "$WIKI_FOLDER_TOKEN" 2>/dev/null || true)
    FILE_COUNT=$(echo "$DRIVE_FILES" | grep -c 'name' || echo 0)
    REPORT="${REPORT}- Drive files: ${FILE_COUNT}\n"

    # Orphan check
    INDEX_TOKEN=$(config_get '.feishu_drive.index_doc_token' '')
    if [[ -n "$INDEX_TOKEN" ]]; then
        INDEX_CONTENT=$(lark-cli docs +fetch "$INDEX_TOKEN" 2>/dev/null || true)
        if [[ -n "$INDEX_CONTENT" ]]; then
            INDEXED=$(echo "$INDEX_CONTENT" | grep -oE 'doxcn[A-Za-z0-9]+' | sort -u || true)
            FOLDER_TOKENS=$(echo "$DRIVE_FILES" | grep -oE 'doxcn[A-Za-z0-9]+' | sort -u || true)
            ORPHANS=""
            for t in $FOLDER_TOKENS; do
                [[ "$t" == "$INDEX_TOKEN" ]] && continue
                LOG_T=$(config_get '.feishu_drive.log_doc_token' '')
                [[ "$t" == "$LOG_T" ]] && continue
                echo "$INDEXED" | grep -q "$t" || { ORPHANS="${ORPHANS}- ${t}\n"; ((ISSUES++)); }
            done
            [[ -n "$ORPHANS" ]] && REPORT="${REPORT}- **Orphans** (not in index):\n${ORPHANS}\n" || REPORT="${REPORT}- No orphans ✅\n"
        fi
    fi

    # Raw structure
    if [[ ! -d "$RAW_DIR" ]]; then
        REPORT="${REPORT}- **Missing raw/**\n"; ((WARNINGS++))
    else
        for d in 10-product 20-design 30-development 40-process 50-research; do
            [[ ! -d "${RAW_DIR}/${d}" ]] && { REPORT="${REPORT}- **Missing ${d}/**\n"; ((WARNINGS++)); }
        done
        REPORT="${REPORT}- Raw structure OK ✅\n"
    fi
fi

# ═══ GRAPH ═══
if [[ "$FOCUS" == "all" || "$FOCUS" == "graph" ]]; then
    log_info "Checking graph..."
    REPORT="${REPORT}\n## Graph\n\n"

    REPOS_ROOT="${RAW_DIR}/30-development/git-repos"
    if [[ ! -d "$REPOS_ROOT" ]]; then
        REPORT="${REPORT}- No repos\n"
    else
        for d in "${REPOS_ROOT}"/*/.git; do
            [[ -d "$d" ]] || continue
            name=$(basename "$(dirname "$d")")
            path=$(dirname "$d")
            HEAD=$(cd "$path" && git rev-parse --short HEAD 2>/dev/null || echo "?")
            CACHED=$(config_get ".git_repos.\"${name}\".last_sync_hash" "never")
            [[ "$HEAD" != "$CACHED" ]] && { REPORT="${REPORT}- **${name}**: STALE (${CACHED} → ${HEAD})\n"; ((ISSUES++)); } \
                || REPORT="${REPORT}- ${name}: OK (${HEAD}) ✅\n"
            [[ ! -d "${path}/graphify-out" ]] && { REPORT="${REPORT}- **${name}**: No graphify output\n"; ((WARNINGS++)); }
        done
    fi

    command -v graphify &>/dev/null && REPORT="${REPORT}- Graphify CLI: OK ✅\n" || { REPORT="${REPORT}- **Graphify not installed**\n"; ((WARNINGS++)); }
fi

# ═══ CONTENT ═══
if [[ "$FOCUS" == "all" || "$FOCUS" == "content" ]]; then
    log_info "Checking content..."
    REPORT="${REPORT}\n## Content\n\n"

    UNTYPED=0
    if [[ -d "$RAW_DIR" ]]; then
        while IFS= read -r f; do
            [[ "$f" =~ README\.md$ ]] && continue
            [[ -z "$(extract_entity_type "$f")" ]] && ((UNTYPED++))
        done < <(find "$RAW_DIR" -name "*.md" -type f 2>/dev/null)
    fi
    [[ $UNTYPED -gt 0 ]] && { REPORT="${REPORT}- **${UNTYPED} untyped docs**\n"; ((WARNINGS++)); } || REPORT="${REPORT}- All typed ✅\n"

    LOG_T=$(config_get '.feishu_drive.log_doc_token' '')
    if [[ -n "$LOG_T" ]]; then
        LOG_C=$(lark-cli docs +fetch "$LOG_T" 2>/dev/null || true)
        if [[ -n "$LOG_C" ]]; then
            LAST=$(echo "$LOG_C" | grep -oE '## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' | tail -1 | tr -d '#[]' || true)
            if [[ -n "$LAST" ]]; then
                DAYS=$(( ($(date +%s) - $(date -d "$LAST" +%s 2>/dev/null || echo 0)) / 86400 ))
                [[ $DAYS -gt 7 ]] && { REPORT="${REPORT}- **Stale log**: ${LAST} (${DAYS}d)\n"; ((WARNINGS++)); } \
                    || REPORT="${REPORT}- Log active: ${LAST} ✅\n"
            fi
        fi
    fi

    MISSING=0
    [[ -z "$(config_get '.feishu_drive.wiki_folder_token' '')" ]] && ((MISSING++))
    [[ -z "$(config_get '.feishu_drive.index_doc_token' '')" ]] && ((MISSING++))
    [[ $MISSING -gt 0 ]] && { REPORT="${REPORT}- **${MISSING} missing config**\n"; ((ISSUES++)); } || REPORT="${REPORT}- Config OK ✅\n"
fi

# ═══ SUMMARY ═══
REPORT="${REPORT}\n---\n**Summary**: ${ISSUES} issues, ${WARNINGS} warnings\n"
[[ $ISSUES -eq 0 && $WARNINGS -eq 0 ]] && REPORT="${REPORT}\n✅ All checks passed!\n"
[[ $ISSUES -eq 0 && $WARNINGS -gt 0 ]] && REPORT="${REPORT}\n⚠️ ${WARNINGS} warnings (non-critical)\n"
[[ $ISSUES -gt 0 ]] && REPORT="${REPORT}\n❌ ${ISSUES} issues need attention\n"

# Write to wiki
DOC_OUT=$(echo "$REPORT" | lark-cli docs +create --title "Lint-$(today)" --folder-token "$WIKI_FOLDER_TOKEN" --markdown "$REPORT" 2>&1) || { echo "$REPORT"; exit 0; }
DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
[[ -n "$DOC_TOKEN" ]] && log_ok "Report: ${DOC_TOKEN}"

LOG_T=$(config_get '.feishu_drive.log_doc_token' '')
[[ -n "$LOG_T" ]] && {
    LOG_ENTRY="\n## [$(today)] lint | ${ISSUES} issues, ${WARNINGS} warnings\n"
    lark-cli docs +update "$LOG_T" --content "$(echo "$LOG_ENTRY" | sed 's/"/\\"/g')" 2>/dev/null || true
}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "$REPORT" | tail -5
echo "═══════════════════════════════════════════════════════════════"

exit $(( ISSUES > 0 ? 1 : 0 ))

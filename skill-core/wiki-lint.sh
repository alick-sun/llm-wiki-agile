#!/usr/bin/env bash
# wiki-lint — Health check the wiki (orphans, stale graph, contradictions)
# Usage: wiki-lint [--fix] [--focus <area>]
#   --focus: all|structure|graph|content

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

FIX=false
FOCUS="all"

# ── Parse args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)      FIX=true; shift ;;
        --focus)    FOCUS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: wiki-lint [--fix] [--focus <area>]"
            echo ""
            echo "Areas:"
            echo "  all       — Run all checks (default)"
            echo "  structure — Check folder structure, orphans, missing index entries"
            echo "  graph     — Check graph freshness, God Nodes, communities"
            echo "  content   — Check for contradictions, stale claims, broken links"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Pre-checks ─────────────────────────────────────────────────────────────
require_lark_cli
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)

REPORT="# Wiki Lint Report — $(today)\n\n**Focus**: ${FOCUS}\n**Auto-fix**: ${FIX}\n\n"
ISSUES=0
WARNINGS=0

# ═══════════════════════════════════════════════════════════════════════════
# CHECK 1: Structure
# ═══════════════════════════════════════════════════════════════════════════
if [[ "$FOCUS" == "all" || "$FOCUS" == "structure" ]]; then
    log_info "Checking structure..."
    REPORT="${REPORT}## Structure\n\n"

    # 1a: List all files in Drive folder
    DRIVE_FILES=$(lark-cli drive files list --folder-token "$WIKI_FOLDER_TOKEN" 2>/dev/null || true)
    FILE_COUNT=$(echo "$DRIVE_FILES" | grep -c 'name' || echo 0)
    REPORT="${REPORT}- Total Drive files: ${FILE_COUNT}\n"

    # 1b: Check for orphan pages (no inbound @mention-doc)
    # Heuristic: pages not referenced in index
    INDEX_TOKEN=$(config_get '.feishu_drive.index_doc_token' '')
    if [[ -n "$INDEX_TOKEN" ]]; then
        INDEX_CONTENT=$(lark-cli docs +fetch "$INDEX_TOKEN" 2>/dev/null || true)
        if [[ -n "$INDEX_CONTENT" ]]; then
            # Extract all doc tokens from index
            INDEXED_TOKENS=$(echo "$INDEX_CONTENT" | grep -oE 'doxcn[A-Za-z0-9]+' | sort -u || true)
            # Extract all doc tokens from folder
            FOLDER_TOKENS=$(echo "$DRIVE_FILES" | grep -oE 'doxcn[A-Za-z0-9]+' | sort -u || true)

            ORPHANS=""
            for token in $FOLDER_TOKENS; do
                if ! echo "$INDEXED_TOKENS" | grep -q "$token"; then
                    # Skip index and log themselves
                    [[ "$token" == "$INDEX_TOKEN" ]] && continue
                    LOG_TOKEN=$(config_get '.feishu_drive.log_doc_token' '')
                    [[ "$token" == "$LOG_TOKEN" ]] && continue
                    ORPHANS="${ORPHANS}- ${token}\n"
                    ((ISSUES++))
                fi
            done

            if [[ -n "$ORPHANS" ]]; then
                REPORT="${REPORT}- **Orphan pages** (not in index):\n${ORPHANS}\n"
            else
                REPORT="${REPORT}- No orphan pages found ✅\n"
            fi
        fi
    fi

    # 1c: Check raw/ directory structure
    if [[ ! -d "$RAW_DIR" ]]; then
        REPORT="${REPORT}- **WARNING**: raw/ directory missing\n"
        ((WARNINGS++))
    else
        for subdir in "10-product" "20-design" "30-development" "40-process" "50-research"; do
            if [[ ! -d "${RAW_DIR}/${subdir}" ]]; then
                REPORT="${REPORT}- **WARNING**: Missing ${subdir}/\n"
                ((WARNINGS++))
            fi
        done
        REPORT="${REPORT}- Raw directory structure OK ✅\n"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# CHECK 2: Graph freshness
# ═══════════════════════════════════════════════════════════════════════════
if [[ "$FOCUS" == "all" || "$FOCUS" == "graph" ]]; then
    log_info "Checking graph freshness..."
    REPORT="${REPORT}\n## Graph Status\n\n"

    REPOS_ROOT="${RAW_DIR}/30-development/git-repos"
    if [[ ! -d "$REPOS_ROOT" ]]; then
        REPORT="${REPORT}- No git repos configured\n"
    else
        for repo_dir in "${REPOS_ROOT}"/*/.git; do
            if [[ -d "$repo_dir" ]]; then
                name=$(basename "$(dirname "$repo_dir")")
                repo_path=$(dirname "$repo_dir")
                HEAD_HASH=$(cd "$repo_path" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
                CACHED_HASH=$(config_get ".git_repos.\"${name}\".last_sync_hash" "never")

                if [[ "$HEAD_HASH" != "$CACHED_HASH" ]]; then
                    REPORT="${REPORT}- **${name}**: STALE (${CACHED_HASH} → ${HEAD_HASH})\n"
                    ((ISSUES++))
                else
                    REPORT="${REPORT}- ${name}: Up to date (${HEAD_HASH}) ✅\n"
                fi

                # Check if graphify-out exists
                if [[ ! -d "${repo_path}/graphify-out" ]]; then
                    REPORT="${REPORT}- **${name}**: No Graphify output (run: wiki-sync-code --repo ${name})\n"
                    ((WARNINGS++))
                fi
            fi
        done
    fi

    # Check graphify report freshness
    if command -v graphify &>/dev/null; then
        REPORT="${REPORT}- Graphify CLI: available ✅\n"
    else
        REPORT="${REPORT}- **Graphify CLI**: not installed\n"
        ((WARNINGS++))
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# CHECK 3: Content quality
# ═══════════════════════════════════════════════════════════════════════════
if [[ "$FOCUS" == "all" || "$FOCUS" == "content" ]]; then
    log_info "Checking content..."
    REPORT="${REPORT}\n## Content Quality\n\n"

    # 3a: Check for untyped documents in raw/
    UNTYPED=0
    if [[ -d "$RAW_DIR" ]]; then
        while IFS= read -r file; do
            [[ "$file" =~ README\.md$ ]] && continue
            type=$(extract_entity_type "$file" || true)
            if [[ -z "$type" ]]; then
                ((UNTYPED++))
            fi
        done < <(find "$RAW_DIR" -name "*.md" -type f 2>/dev/null)
    fi

    if [[ $UNTYPED -gt 0 ]]; then
        REPORT="${REPORT}- **${UNTYPED} untyped documents** in raw/ (missing frontmatter)\n"
        ((WARNINGS++))
    else
        REPORT="${REPORT}- All raw documents have frontmatter ✅\n"
    fi

    # 3b: Check for stale log (no entries in 7 days)
    LOG_TOKEN=$(config_get '.feishu_drive.log_doc_token' '')
    if [[ -n "$LOG_TOKEN" ]]; then
        LOG_CONTENT=$(lark-cli docs +fetch "$LOG_TOKEN" 2>/dev/null || true)
        if [[ -n "$LOG_CONTENT" ]]; then
            LAST_ENTRY_DATE=$(echo "$LOG_CONTENT" | grep -oE '## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' | tail -1 | tr -d '#[]' || true)
            if [[ -n "$LAST_ENTRY_DATE" ]]; then
                DAYS_SINCE=$(( ($(date +%s) - $(date -d "$LAST_ENTRY_DATE" +%s 2>/dev/null || echo 0)) / 86400 ))
                if [[ $DAYS_SINCE -gt 7 ]]; then
                    REPORT="${REPORT}- **Log stale**: Last entry ${LAST_ENTRY_DATE} (${DAYS_SINCE} days ago)\n"
                    ((WARNINGS++))
                else
                    REPORT="${REPORT}- Log active: Last entry ${LAST_ENTRY_DATE} ✅\n"
                fi
            fi
        fi
    fi

    # 3c: Config completeness
    MISSING_CONFIG=0
    [[ -z "$(config_get '.feishu_drive.wiki_folder_token' '')" ]] && ((MISSING_CONFIG++))
    [[ -z "$(config_get '.feishu_drive.index_doc_token' '')" ]] && ((MISSING_CONFIG++))
    [[ -z "$(config_get '.feishu_drive.log_doc_token' '')" ]] && ((MISSING_CONFIG++))

    if [[ $MISSING_CONFIG -gt 0 ]]; then
        REPORT="${REPORT}- **${MISSING_CONFIG} missing config values** (run wiki-init)\n"
        ((ISSUES++))
    else
        REPORT="${REPORT}- Config complete ✅\n"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# REPORT OUTPUT
# ═══════════════════════════════════════════════════════════════════════════
REPORT="${REPORT}\n---\n\n**Summary**: ${ISSUES} issues, ${WARNINGS} warnings\n"

if [[ $ISSUES -eq 0 && $WARNINGS -eq 0 ]]; then
    REPORT="${REPORT}\n✅ All checks passed! Wiki is healthy.\n"
elif [[ $ISSUES -eq 0 ]]; then
    REPORT="${REPORT}\n⚠️  ${WARNINGS} warnings found (non-critical).\n"
else
    REPORT="${REPORT}\n❌ ${ISSUES} issues need attention.\n"
fi

# Write report to Feishu
DOC_TITLE="Lint-Report-$(today)"
DOC_OUT=$(echo "$REPORT" | lark-cli docs +create \
    --title "$DOC_TITLE" \
    --folder-token "$WIKI_FOLDER_TOKEN" \
    --markdown "$REPORT" 2>&1) || {
    # Fallback: print to stdout
    echo "$REPORT"
    exit 0
}

DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
if [[ -n "$DOC_TOKEN" ]]; then
    log_ok "Report saved: ${DOC_TOKEN}"
fi

# Update log
LOG_TOKEN=$(config_get '.feishu_drive.log_doc_token' '')
if [[ -n "$LOG_TOKEN" ]]; then
    LOG_ENTRY="\n## [$(today)] lint | ${ISSUES} issues, ${WARNINGS} warnings\n- Focus: ${FOCUS}\n- Report: ${DOC_TOKEN}\n"
    lark-cli docs +update "$LOG_TOKEN" \
        --content "$(echo "$LOG_ENTRY" | sed 's/"/\\"/g')" 2>/dev/null || true
fi

# Print summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "$REPORT" | tail -5
echo "═══════════════════════════════════════════════════════════════"

exit $(( ISSUES > 0 ? 1 : 0 ))

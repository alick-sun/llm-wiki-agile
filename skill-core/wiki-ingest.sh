#!/usr/bin/env bash
# wiki-ingest — Ingest a new source into the wiki
# Usage: wiki-ingest <source> [--type <entity_type>] [--title <title>]
#   source: URL, local file path, or Feishu Drive file token

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

SOURCE=""
ENTITY_TYPE=""
TITLE=""
SOURCE_TYPE="auto"  # auto, url, file, drive

# ── Parse args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)     ENTITY_TYPE="$2"; shift 2 ;;
        --title)    TITLE="$2"; shift 2 ;;
        --source-type) SOURCE_TYPE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: wiki-ingest <source> [--type <type>] [--title <title>]"
            echo ""
            echo "Examples:"
            echo "  wiki-ingest https://example.com/article"
            echo "  wiki-ingest ./meeting-notes-0508.md --type Meeting --title 'Sprint Review'"
            echo "  wiki-ingest fldcnXXXXXX --source-type drive"
            exit 0
            ;;
        *)
            if [[ -z "$SOURCE" ]]; then
                SOURCE="$1"
                shift
            else
                log_error "Unknown option: $1"; exit 1
            fi
            ;;
    esac
done

if [[ -z "$SOURCE" ]]; then
    log_error "No source provided. Use: wiki-ingest <source>"
    exit 1
fi

# ── Pre-checks ─────────────────────────────────────────────────────────────
require_lark_cli
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)

# ── Detect source type ─────────────────────────────────────────────────────
if [[ "$SOURCE_TYPE" == "auto" ]]; then
    if [[ "$SOURCE" =~ ^https?:// ]]; then
        SOURCE_TYPE="url"
    elif [[ -f "$SOURCE" ]]; then
        SOURCE_TYPE="file"
    elif [[ "$SOURCE" =~ ^fldcn ]]; then
        SOURCE_TYPE="drive"
    else
        log_error "Cannot determine source type: $SOURCE"
        exit 1
    fi
fi

log_info "Source type: ${SOURCE_TYPE}"
log_info "Source: ${SOURCE}"

# ── Fetch/process source ───────────────────────────────────────────────────
RAW_FILE=""
case "$SOURCE_TYPE" in
    url)
        require_tool() { command -v curl &>/dev/null || { log_error "curl required"; exit 1; }; }
        require_tool
        log_info "Fetching URL..."
        RAW_FILE="${RAW_DIR}/90-external/$(basename "$SOURCE" | sed 's/[^a-zA-Z0-9._-]/_/g').html"
        curl -sL "$SOURCE" -o "$RAW_FILE" 2>/dev/null || {
            log_error "Failed to fetch URL"
            exit 1
        }
        ;;
    file)
        RAW_FILE="$SOURCE"
        ;;
    drive)
        log_info "Fetching from Feishu Drive..."
        FETCH_OUT=$(lark-cli docs +fetch --folder-token "$SOURCE" 2>&1) || {
            log_error "Failed to fetch Drive file: $FETCH_OUT"
            exit 1
        }
        RAW_FILE="${RAW_DIR}/90-external/feishu-export-$(today).md"
        echo "$FETCH_OUT" > "$RAW_FILE"
        ;;
esac

# ── Determine entity type ──────────────────────────────────────────────────
if [[ -z "$ENTITY_TYPE" && -f "$RAW_FILE" ]]; then
    DETECTED=$(extract_entity_type "$RAW_FILE" || true)
    if [[ -n "$DETECTED" ]]; then
        ENTITY_TYPE="$DETECTED"
        log_info "Auto-detected type: ${ENTITY_TYPE}"
    fi
fi

# ── Ask user for type if still unknown ─────────────────────────────────────
if [[ -z "$ENTITY_TYPE" ]]; then
    echo ""
    echo "Select entity type:"
    echo "  1) ProductRequirement  2) UserStory     3) Epic"
    echo "  4) Task                5) Bug           6) Meeting"
    echo "  7) ArchitectureDecision 8) Sprint       9) Research"
    echo "  0) Skip (no frontmatter)"
    read -rp "> " choice
    case "$choice" in
        1) ENTITY_TYPE="ProductRequirement" ;;
        2) ENTITY_TYPE="UserStory" ;;
        3) ENTITY_TYPE="Epic" ;;
        4) ENTITY_TYPE="Task" ;;
        5) ENTITY_TYPE="Bug" ;;
        6) ENTITY_TYPE="Meeting" ;;
        7) ENTITY_TYPE="ArchitectureDecision" ;;
        8) ENTITY_TYPE="Sprint" ;;
        9) ENTITY_TYPE="ResearchNote" ;;
        0) ENTITY_TYPE="" ;;
    esac
fi

# ── Determine title ────────────────────────────────────────────────────────
if [[ -z "$TITLE" && -f "$RAW_FILE" ]]; then
    TITLE=$(extract_title "$RAW_FILE")
fi
[[ -z "$TITLE" ]] && TITLE="Untitled $(today)"

# ── Copy to raw/ directory with proper naming ──────────────────────────────
if [[ -n "$ENTITY_TYPE" ]]; then
    # Determine destination subfolder
    DEST_SUBDIR=""
    case "$ENTITY_TYPE" in
        ProductRequirement) DEST_SUBDIR="10-product/prd" ;;
        UserStory)          DEST_SUBDIR="10-product/user-stories" ;;
        Epic)               DEST_SUBDIR="10-product/epics" ;;
        Task)               DEST_SUBDIR="10-product/tasks" ;;
        Bug)                DEST_SUBDIR="10-product/bugs" ;;
        Meeting)            DEST_SUBDIR="40-process/meeting-notes" ;;
        ArchitectureDecision) DEST_SUBDIR="40-process/decisions" ;;
        Sprint)             DEST_SUBDIR="40-process/sprints" ;;
        PullRequest)        DEST_SUBDIR="40-process/pull-requests" ;;
        Release)            DEST_SUBDIR="40-process/releases" ;;
        *)                  DEST_SUBDIR="50-research/articles" ;;
    esac

    DEST_DIR="${RAW_DIR}/${DEST_SUBDIR}"
    mkdir -p "$DEST_DIR"

    # Generate filename
    if [[ -f "$RAW_FILE" ]]; then
        DEST_FILE="${DEST_DIR}/$(basename "$RAW_FILE")"
    else
        SAFE_TITLE=$(echo "$TITLE" | sed 's/[^a-zA-Z0-9\u4e00-\u9fff._-]/_/g' | cut -c1-50)
        DEST_FILE="${DEST_DIR}/${SAFE_TITLE}.md"
    fi

    # Copy content
    if [[ "$RAW_FILE" != "$DEST_FILE" ]]; then
        cp "$RAW_FILE" "$DEST_FILE" 2>/dev/null || echo "$RAW_FILE" > "$DEST_FILE"
    fi

    log_ok "Saved to: ${DEST_FILE}"

    # ── Run Graphify if code-related ───────────────────────────────────────
    if [[ "$ENTITY_TYPE" =~ ^(CodeModule|CodeFunction|Task)$ ]]; then
        log_info "Code-related entity detected, running Graphify..."
        require_graphify
        for repo_dir in "${RAW_DIR}/30-development/git-repos/"*/; do
            if [[ -d "$repo_dir/.git" ]]; then
                maybe_graphify_build "$repo_dir"
            fi
        done
    fi
else
    DEST_FILE="$RAW_FILE"
fi

# ── Create wiki document ───────────────────────────────────────────────────
log_info "Creating wiki document..."

# Read content for upload
if [[ -f "$DEST_FILE" ]]; then
    CONTENT=$(cat "$DEST_FILE")
else
    CONTENT="Source: ${SOURCE}\n\nIngested: $(now)"
fi

# Add header
WIKI_CONTENT="# ${TITLE}\n\n**Source**: ${SOURCE}\n**Type**: ${ENTITY_TYPE:-untyped}\n**Ingested**: $(now)\n\n---\n\n${CONTENT}"

# Create in Feishu
DOC_OUT=$(echo "$WIKI_CONTENT" | lark-cli docs +create \
    --title "$TITLE" \
    --folder-token "$WIKI_FOLDER_TOKEN" \
    --markdown "$WIKI_CONTENT" 2>&1) || {
    log_error "Failed to create wiki doc: $DOC_OUT"
    exit 1
}

DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
if [[ -n "$DOC_TOKEN" ]]; then
    log_ok "Wiki doc created: ${DOC_TOKEN}"
else
    log_warn "Could not extract doc token"
    echo "$DOC_OUT"
fi

# ── Update log ─────────────────────────────────────────────────────────────
LOG_TOKEN=$(config_get '.feishu_drive.log_doc_token' '')
if [[ -n "$LOG_TOKEN" ]]; then
    LOG_ENTRY="\n## [$(today)] ingest | ${TITLE}\n- Type: ${ENTITY_TYPE:-untyped}\n- Source: ${SOURCE}\n- Doc: ${DOC_TOKEN:-unknown}\n- Raw: ${DEST_FILE}\n"
    lark-cli docs +update "$LOG_TOKEN" \
        --content "$(echo "$LOG_ENTRY" | sed 's/"/\\"/g')" 2>/dev/null || {
        log_warn "Failed to update log"
    }
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Source ingested: ${TITLE}"
echo "═══════════════════════════════════════════════════════════════"
echo "  Type:    ${ENTITY_TYPE:-untyped}"
echo "  Raw:     ${DEST_FILE}"
[[ -n "$DOC_TOKEN" ]] && echo "  Wiki:    ${DOC_TOKEN}"
echo ""
echo "  LLM should now:"
echo "    1. Read and summarize the source"
echo "    2. Update relevant entity pages"
echo "    3. Update index with @mention-doc links"
echo "═══════════════════════════════════════════════════════════════"

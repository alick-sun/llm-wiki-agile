#!/usr/bin/env bash
# wiki-ingest — Ingest a new source into the wiki
# Usage: wiki-ingest <source> [--type <entity_type>] [--title <title>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/wiki-config.json"
RAW_DIR="${PROJECT_ROOT}/raw"

# Colors
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

extract_entity_type() {
    local file="$1"
    grep -m1 '^type:' "$file" 2>/dev/null | sed 's/type: *//' | tr -d ' "' || true
}

extract_title() {
    local file="$1"
    local title; title=$(grep -m1 '^title:' "$file" 2>/dev/null | sed 's/title: *//' | sed 's/^"//;s/"$//' || true)
    [[ -z "$title" ]] && title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# *//' || true)
    [[ -z "$title" ]] && title=$(basename "$file" .md)
    echo "$title"
}

today() { date +"%Y-%m-%d"; }
now() { date +"%Y-%m-%d %H:%M"; }

# ── Parse args ──
SOURCE=""
ENTITY_TYPE=""
TITLE=""
SOURCE_TYPE="auto"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)      ENTITY_TYPE="$2"; shift 2 ;;
        --title)     TITLE="$2"; shift 2 ;;
        --source-type) SOURCE_TYPE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: wiki-ingest <source> [--type <type>] [--title <title>]"
            exit 0 ;;
        *)
            [[ -z "$SOURCE" ]] && SOURCE="$1" || SOURCE="$SOURCE $1"
            shift ;;
    esac
done

[[ -z "$SOURCE" ]] && { log_error "No source provided"; exit 1; }

# ── Pre-checks ──
if ! command -v lark-cli &>/dev/null; then
    log_error "lark-cli not found. Install: npm install -g @larksuite/cli"
    exit 1
fi
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)

# ── Detect source type ──
if [[ "$SOURCE_TYPE" == "auto" ]]; then
    if [[ "$SOURCE" =~ ^https?:// ]]; then SOURCE_TYPE="url"
    elif [[ -f "$SOURCE" ]]; then SOURCE_TYPE="file"
    elif [[ "$SOURCE" =~ ^fldcn ]]; then SOURCE_TYPE="drive"
    else log_error "Cannot determine source type: $SOURCE"; exit 1; fi
fi

log_info "Source: ${SOURCE_TYPE} → ${SOURCE}"

# ── Fetch source ──
RAW_FILE=""
case "$SOURCE_TYPE" in
    url)
        if ! command -v curl &>/dev/null; then log_error "curl required"; exit 1; fi
        RAW_FILE="${RAW_DIR}/90-external/$(basename "$SOURCE" | sed 's/[^a-zA-Z0-9._-]/_/g').html"
        curl -sL "$SOURCE" -o "$RAW_FILE" || { log_error "Fetch failed"; exit 1; }
        ;;
    file)
        RAW_FILE="$SOURCE"
        ;;
    drive)
        FETCH_OUT=$(lark-cli docs +fetch --folder-token "$SOURCE" 2>&1) || {
            log_error "Fetch failed: $FETCH_OUT"; exit 1
        }
        RAW_FILE="${RAW_DIR}/90-external/feishu-export-$(today).md"
        echo "$FETCH_OUT" > "$RAW_FILE"
        ;;
esac

# ── Determine entity type ──
if [[ -z "$ENTITY_TYPE" && -f "$RAW_FILE" ]]; then
    DETECTED=$(extract_entity_type "$RAW_FILE" || true)
    [[ -n "$DETECTED" ]] && { ENTITY_TYPE="$DETECTED"; log_info "Auto-detected: ${ENTITY_TYPE}"; }
fi

# ── Determine title ──
[[ -z "$TITLE" && -f "$RAW_FILE" ]] && TITLE=$(extract_title "$RAW_FILE")
[[ -z "$TITLE" ]] && TITLE="Untitled $(today)"

# ── Copy to raw/ ──
if [[ -n "$ENTITY_TYPE" ]]; then
    case "$ENTITY_TYPE" in
        ProductRequirement)  DEST_SUBDIR="10-product/prd" ;;
        UserStory)           DEST_SUBDIR="10-product/user-stories" ;;
        Epic)                DEST_SUBDIR="10-product/epics" ;;
        Task)                DEST_SUBDIR="10-product/tasks" ;;
        Bug)                 DEST_SUBDIR="10-product/bugs" ;;
        Meeting)             DEST_SUBDIR="40-process/meeting-notes" ;;
        ArchitectureDecision) DEST_SUBDIR="40-process/decisions" ;;
        Sprint)              DEST_SUBDIR="40-process/sprints" ;;
        PullRequest)         DEST_SUBDIR="40-process/pull-requests" ;;
        Release)             DEST_SUBDIR="40-process/releases" ;;
        *)                   DEST_SUBDIR="50-research/articles" ;;
    esac

    DEST_DIR="${RAW_DIR}/${DEST_SUBDIR}"
    mkdir -p "$DEST_DIR"

    if [[ -f "$RAW_FILE" ]]; then
        SAFE_TITLE=$(echo "$TITLE" | sed 's/[^a-zA-Z0-9\u4e00-\u9fff._-]/_/g' | cut -c1-50)
        DEST_FILE="${DEST_DIR}/${SAFE_TITLE}.md"
        cp "$RAW_FILE" "$DEST_FILE" 2>/dev/null || echo "$RAW_FILE" > "$DEST_FILE"
    else
        DEST_FILE="$RAW_FILE"
    fi
    log_ok "Saved: ${DEST_FILE}"

    # Graphify if code-related
    if [[ "$ENTITY_TYPE" =~ ^(CodeModule|CodeFunction|Task)$ ]]; then
        log_info "Code entity detected, running Graphify..."
        for repo_dir in "${RAW_DIR}/30-development/git-repos/"*/; do
            [[ -d "${repo_dir}/.git" ]] || continue
            if command -v graphify &>/dev/null; then
                (cd "$repo_dir" && graphify build . --update 2>/dev/null) && log_ok "Graphify: $(basename "$repo_dir")"
            fi
        done
    fi
else
    DEST_FILE="$RAW_FILE"
fi

# ── Create wiki doc ──
log_info "Creating wiki document..."
if [[ -f "$DEST_FILE" ]]; then CONTENT=$(cat "$DEST_FILE"); else CONTENT="Source: ${SOURCE}"; fi

WIKI_CONTENT="# ${TITLE}\n\n**Source**: ${SOURCE}\n**Type**: ${ENTITY_TYPE:-untyped}\n**Ingested**: $(now)\n\n---\n\n${CONTENT}"

DOC_OUT=$(echo "$WIKI_CONTENT" | lark-cli docs +create --title "$TITLE" --folder-token "$WIKI_FOLDER_TOKEN" --markdown "$WIKI_CONTENT" 2>&1) || {
    log_error "Create doc failed: $DOC_OUT"; exit 1
}

DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
[[ -n "$DOC_TOKEN" ]] && log_ok "Wiki doc: ${DOC_TOKEN}"

# ── Update log ──
LOG_TOKEN=$(config_get '.feishu_drive.log_doc_token' '')
if [[ -n "$LOG_TOKEN" ]]; then
    LOG_ENTRY="\n## [$(today)] ingest | ${TITLE}\n- Type: ${ENTITY_TYPE:-untyped}\n- Source: ${SOURCE}\n- Doc: ${DOC_TOKEN:-unknown}\n"
    lark-cli docs +update "$LOG_TOKEN" --content "$(echo "$LOG_ENTRY" | sed 's/"/\\"/g')" 2>/dev/null || log_warn "Log update failed"
fi

# ── Summary ──
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Ingested: ${TITLE}"
echo "  Type:     ${ENTITY_TYPE:-untyped}"
echo "  Raw:      ${DEST_FILE}"
[[ -n "$DOC_TOKEN" ]] && echo "  Wiki:     ${DOC_TOKEN}"
echo "═══════════════════════════════════════════════════════════════"

#!/usr/bin/env bash
# wiki-init — Initialize LLM Wiki folder structure in Feishu Drive
# Usage: wiki-init [--name <folder_name>] [--parent <parent_folder_token>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/config"
CONFIG_FILE="${CONFIG_DIR}/wiki-config.json"
RAW_DIR="${PROJECT_ROOT}/raw"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Config helpers
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
    mkdir -p "$CONFIG_DIR"
    [[ ! -f "$CONFIG_FILE" ]] && echo '{}' > "$CONFIG_FILE"
    local tmp; tmp=$(mktemp)
    jq "$key = \"$val\"" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
}

extract_folder_token() {
    local output="$1"
    echo "$output" | grep -oE 'fldcn[A-Za-z0-9]+' | head -1
}

extract_doc_token() {
    local output="$1"
    echo "$output" | grep -oE 'doxcn[A-Za-z0-9]+' | head -1
}

today() { date +"%Y-%m-%d"; }

# ── Parse args ──
FOLDER_NAME="LLM-Wiki"
PARENT_TOKEN=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)     FOLDER_NAME="$2"; shift 2 ;;
        --parent)   PARENT_TOKEN="$2"; shift 2 ;;
        -h|--help)  echo "Usage: wiki-init [--name <name>] [--parent <token>]"; exit 0 ;;
        *) log_error "Unknown: $1"; exit 1 ;;
    esac
done

# ── Pre-checks ──
if ! command -v lark-cli &>/dev/null; then
    log_error "lark-cli not found. Install: npm install -g @larksuite/cli"
    exit 1
fi

if [[ -f "$CONFIG_FILE" ]] && [[ -n "$(config_get '.feishu_drive.wiki_folder_token' '')" ]]; then
    log_warn "Already initialized. Re-initialize? [y/N]"
    read -r ans; [[ "$ans" =~ ^[Yy]$ ]] || exit 0
fi

# ── Create main folder ──
log_info "Creating wiki folder: ${FOLDER_NAME}"
CREATE_CMD="lark-cli drive +create-folder --name \"${FOLDER_NAME}\""
[[ -n "$PARENT_TOKEN" ]] && CREATE_CMD="${CREATE_CMD} --folder-token ${PARENT_TOKEN}"

FOLDER_OUT=$(eval "$CREATE_CMD" 2>&1) || { log_error "Failed: $FOLDER_OUT"; exit 1; }
WIKI_FOLDER_TOKEN=$(extract_folder_token "$FOLDER_OUT")
[[ -z "$WIKI_FOLDER_TOKEN" ]] && { log_error "No folder token"; echo "$FOLDER_OUT"; exit 1; }
log_ok "Folder: ${WIKI_FOLDER_TOKEN}"

# ── Subfolders ──
log_info "Creating subfolders..."
SUBFOLDERS=("10-product" "20-design" "30-development" "40-process" "50-research" "entities" "concepts" "syntheses")
for sub in "${SUBFOLDERS[@]}"; do
    SUB_OUT=$(lark-cli drive +create-folder --name "$sub" --folder-token "$WIKI_FOLDER_TOKEN" 2>&1) || {
        log_warn "Failed '${sub}': $SUB_OUT"; continue
    }
    SUB_TOKEN=$(extract_folder_token "$SUB_OUT")
    [[ -n "$SUB_TOKEN" ]] && { log_ok "  ${sub}: ${SUB_TOKEN}"; config_set ".feishu_drive.subfolders.\"${sub}\"" "$SUB_TOKEN"; }
done

# ── Local raw/ directory ──
log_info "Creating local raw/..."
mkdir -p "${RAW_DIR}/00-meta"
mkdir -p "${RAW_DIR}/10-product/prd"
mkdir -p "${RAW_DIR}/10-product/user-stories"
mkdir -p "${RAW_DIR}/10-product/epics"
mkdir -p "${RAW_DIR}/10-product/tasks"
mkdir -p "${RAW_DIR}/10-product/bugs"
mkdir -p "${RAW_DIR}/20-design/architecture"
mkdir -p "${RAW_DIR}/20-design/api"
mkdir -p "${RAW_DIR}/20-design/ui-ux"
mkdir -p "${RAW_DIR}/30-development/git-repos"
mkdir -p "${RAW_DIR}/30-development/code-snippets"
mkdir -p "${RAW_DIR}/30-development/db-schemas"
mkdir -p "${RAW_DIR}/30-development/db-schemas/sample-data"
mkdir -p "${RAW_DIR}/40-process/meeting-notes"
mkdir -p "${RAW_DIR}/40-process/sprints"
mkdir -p "${RAW_DIR}/40-process/decisions"
mkdir -p "${RAW_DIR}/40-process/pull-requests"
mkdir -p "${RAW_DIR}/40-process/releases"
mkdir -p "${RAW_DIR}/50-research/papers"
mkdir -p "${RAW_DIR}/50-research/articles"
mkdir -p "${RAW_DIR}/50-research/competitors"
mkdir -p "${RAW_DIR}/90-external"

cat > "${RAW_DIR}/README.md" << 'EOF'
# Raw Sources

This directory contains all raw, immutable source documents.
LLM reads from these but never modifies them.

## Structure

- `00-meta/` — Project config, team members, glossary
- `10-product/` — PRDs, user stories, epics, tasks, bugs
- `20-design/` — Architecture decisions, API specs, UI/UX
- `30-development/` — Git repos (submodules), code snippets, DB schemas
- `40-process/` — Meeting notes, sprints, decisions, PRs, releases
- `50-research/` — Papers, articles, competitive analysis
- `90-external/` — Vendor docs, third-party API docs

## Conventions

- Every typed document MUST include YAML frontmatter with `type: <EntityName>`
- Use `id: XXX-NNN` format for identifiers
- Use `related: [ID-001, ID-002]` to link related entities
EOF

log_ok "raw/ created"

# ── Index doc ──
log_info "Creating index..."
INDEX_CONTENT="# LLM Wiki Index\n\nContent catalog. Last updated: $(today)\n\n## Product\n\n## Design\n\n## Development\n\n## Process\n\n## Research\n\n## Entities\n\n## Concepts\n\n## Syntheses\n"
INDEX_OUT=$(echo "$INDEX_CONTENT" | lark-cli docs +create --title "index" --folder-token "$WIKI_FOLDER_TOKEN" --markdown "$INDEX_CONTENT" 2>&1) || {
    log_warn "Index failed: $INDEX_OUT"; INDEX_TOKEN=""
}
INDEX_TOKEN=$(extract_doc_token "$INDEX_OUT" || true)
[[ -n "$INDEX_TOKEN" ]] && log_ok "Index: ${INDEX_TOKEN}"

# ── Log doc ──
log_info "Creating log..."
LOG_CONTENT="# LLM Wiki Log\n\n## [$(today)] init | Wiki initialized\n- Folder: ${FOLDER_NAME}\n- Token: ${WIKI_FOLDER_TOKEN}\n"
LOG_OUT=$(echo "$LOG_CONTENT" | lark-cli docs +create --title "log" --folder-token "$WIKI_FOLDER_TOKEN" --markdown "$LOG_CONTENT" 2>&1) || {
    log_warn "Log failed: $LOG_OUT"; LOG_TOKEN=""
}
LOG_TOKEN=$(extract_doc_token "$LOG_OUT" || true)
[[ -n "$LOG_TOKEN" ]] && log_ok "Log: ${LOG_TOKEN}"

# ── Save config ──
config_set '.feishu_drive.wiki_folder_token' "$WIKI_FOLDER_TOKEN"
config_set '.feishu_drive.wiki_folder_name' "$FOLDER_NAME"
[[ -n "$INDEX_TOKEN" ]] && config_set '.feishu_drive.index_doc_token' "$INDEX_TOKEN"
[[ -n "$LOG_TOKEN" ]] && config_set '.feishu_drive.log_doc_token' "$LOG_TOKEN"
config_set '.initialized_at' "$(today)"

log_ok "Config saved: ${CONFIG_FILE}"

# ── Summary ──
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  LLM Wiki initialized!"
echo "═══════════════════════════════════════════════════════════════"
echo "  Folder:   ${FOLDER_NAME} (${WIKI_FOLDER_TOKEN})"
echo "  Config:   ${CONFIG_FILE}"
echo "  Raw:      ${RAW_DIR}"
echo ""
echo "  Next: edit config/project-config.yaml for team members"
echo "        cd raw/30-development/git-repos && git clone <url>"
echo "        wiki-ingest <source>"
echo "═══════════════════════════════════════════════════════════════"

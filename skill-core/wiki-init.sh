#!/usr/bin/env bash
# wiki-init — Initialize LLM Wiki folder structure in Feishu Drive
# Usage: wiki-init [--name <folder_name>] [--parent <parent_folder_token>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

FOLDER_NAME="LLM-Wiki"
PARENT_TOKEN=""

# ── Parse args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)     FOLDER_NAME="$2"; shift 2 ;;
        --parent)   PARENT_TOKEN="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: wiki-init [--name <name>] [--parent <parent_token>]"
            echo "  Initialize Feishu Drive folder structure for LLM Wiki"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Pre-checks ─────────────────────────────────────────────────────────────
require_lark_cli

if [[ -f "$CONFIG_FILE" ]] && [[ -n "$(config_get '.feishu_drive.wiki_folder_token' '')" ]]; then
    log_warn "Wiki already initialized (token: $(config_get '.feishu_drive.wiki_folder_token') )"
    read -rp "Re-initialize? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 0
fi

# ── Create main wiki folder ────────────────────────────────────────────────
log_info "Creating wiki folder: ${FOLDER_NAME}"

CREATE_CMD="lark-cli drive +create-folder --name \"${FOLDER_NAME}\""
[[ -n "$PARENT_TOKEN" ]] && CREATE_CMD="${CREATE_CMD} --folder-token ${PARENT_TOKEN}"

FOLDER_OUT=$(eval "$CREATE_CMD" 2>&1) || {
    log_error "Failed to create folder: $FOLDER_OUT"
    exit 1
}

WIKI_FOLDER_TOKEN=$(extract_folder_token "$FOLDER_OUT")
if [[ -z "$WIKI_FOLDER_TOKEN" ]]; then
    log_error "Could not extract folder token from output"
    echo "$FOLDER_OUT"
    exit 1
fi

log_ok "Wiki folder created: ${WIKI_FOLDER_TOKEN}"

# ── Create subfolders ──────────────────────────────────────────────────────
log_info "Creating subfolders..."

SUBFOLDERS=("10-product" "20-design" "30-development" "40-process" "50-research" "entities" "concepts" "syntheses")

for sub in "${SUBFOLDERS[@]}"; do
    SUB_OUT=$(lark-cli drive +create-folder --name "$sub" --folder-token "$WIKI_FOLDER_TOKEN" 2>&1) || {
        log_warn "Failed to create subfolder '${sub}': $SUB_OUT"
        continue
    }
    SUB_TOKEN=$(extract_folder_token "$SUB_OUT")
    if [[ -n "$SUB_TOKEN" ]]; then
        log_ok "  ${sub}: ${SUB_TOKEN}"
        # Save subfolder tokens
        config_set ".feishu_drive.subfolders.\"${sub}\"" "$SUB_TOKEN"
    fi
done

# ── Create raw/ directory locally ──────────────────────────────────────────
log_info "Creating local raw/ directory structure..."

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

# Write raw/README.md
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
- Git repos in `git-repos/` are managed as git submodules
- Database schemas are exported via `mysqldump --no-data`
EOF

log_ok "Local raw/ directory created"

# ── Create initial index document ──────────────────────────────────────────
log_info "Creating index document in Feishu..."

INDEX_CONTENT="# LLM Wiki Index\n\nContent-oriented catalog of all wiki pages.\nLast updated: $(today)\n\n## Product\n\n## Design\n\n## Development\n\n## Process\n\n## Research\n\n## Entities\n\n## Concepts\n\n## Syntheses\n"

INDEX_OUT=$(echo "$INDEX_CONTENT" | lark-cli docs +create \
    --title "index" \
    --folder-token "$WIKI_FOLDER_TOKEN" \
    --markdown "$INDEX_CONTENT" 2>&1) || {
    log_warn "Failed to create index doc: $INDEX_OUT"
    INDEX_TOKEN=""
}
INDEX_TOKEN=$(extract_doc_token "$INDEX_OUT" || true)
[[ -n "$INDEX_TOKEN" ]] && log_ok "Index doc: ${INDEX_TOKEN}"

# ── Create initial log document ────────────────────────────────────────────
log_info "Creating log document in Feishu..."

LOG_CONTENT="# LLM Wiki Log\n\nChronological record of all operations.\n\n## [$(today)] init | Wiki initialized\n- Folder: ${FOLDER_NAME}\n- Token: ${WIKI_FOLDER_TOKEN}\n"

LOG_OUT=$(echo "$LOG_CONTENT" | lark-cli docs +create \
    --title "log" \
    --folder-token "$WIKI_FOLDER_TOKEN" \
    --markdown "$LOG_CONTENT" 2>&1) || {
    log_warn "Failed to create log doc: $LOG_OUT"
    LOG_TOKEN=""
}
LOG_TOKEN=$(extract_doc_token "$LOG_OUT" || true)
[[ -n "$LOG_TOKEN" ]] && log_ok "Log doc: ${LOG_TOKEN}"

# ── Save configuration ─────────────────────────────────────────────────────
log_info "Saving configuration..."

config_set '.feishu_drive.wiki_folder_token' "$WIKI_FOLDER_TOKEN"
config_set '.feishu_drive.wiki_folder_name' "$FOLDER_NAME"
[[ -n "$INDEX_TOKEN" ]] && config_set '.feishu_drive.index_doc_token' "$INDEX_TOKEN"
[[ -n "$LOG_TOKEN" ]] && config_set '.feishu_drive.log_doc_token' "$LOG_TOKEN"
config_set '.initialized_at' "$(today)"

log_ok "Configuration saved to: ${CONFIG_FILE}"

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  LLM Wiki initialized successfully!"
echo "═══════════════════════════════════════════════════════════════"
echo "  Wiki folder: ${FOLDER_NAME}"
echo "  Token:       ${WIKI_FOLDER_TOKEN}"
echo "  Config:      ${CONFIG_FILE}"
echo "  Raw dir:     ${RAW_DIR}"
echo ""
echo "  Next steps:"
echo "    1. Edit config/project-config.yaml to add team members"
echo "    2. Add git repos: cd raw/30-development/git-repos && git submodule add <url>"
echo "    3. Start ingesting: wiki-ingest <url-or-file>"
echo "═══════════════════════════════════════════════════════════════"

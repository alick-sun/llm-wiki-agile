#!/usr/bin/env bash
# wiki-sync-db — Export database schema and sync to wiki
# Usage: wiki-sync-db --conn <dsn> --name <db_name> [--type <PostgreSQL|MySQL>]

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
today() { date +"%Y-%m-%d"; }
now() { date +"%Y-%m-%d %H:%M"; }

# ── Args ──
CONN_STR=""; DB_NAME=""; DB_TYPE="PostgreSQL"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --conn)  CONN_STR="$2"; shift 2 ;;
        --name)  DB_NAME="$2"; shift 2 ;;
        --type)  DB_TYPE="$2"; shift 2 ;;
        -h|--help) echo "Usage: wiki-sync-db --conn <dsn> --name <name> [--type <type>]"; exit 0 ;;
        *) log_error "Unknown: $1"; exit 1 ;;
    esac
done

[[ -z "$CONN_STR" ]] && { log_error "No connection string. Use --conn"; exit 1; }
[[ -z "$DB_NAME" ]] && DB_NAME=$(echo "$CONN_STR" | sed 's/.*\///')

for cmd in lark-cli; do command -v "$cmd" &>/dev/null || { log_error "${cmd} required"; exit 1; }; done
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)

DB_SCHEMA_DIR="${RAW_DIR}/30-development/db-schemas"
mkdir -p "$DB_SCHEMA_DIR"

# ── Export schema ──
DDL_FILE="${DB_SCHEMA_DIR}/${DB_NAME}-schema-$(today).sql"
log_info "Exporting ${DB_TYPE} schema..."

case "$DB_TYPE" in
    PostgreSQL)
        command -v pg_dump &>/dev/null || { log_error "pg_dump not found"; exit 1; }
        pg_dump --schema-only "$CONN_STR" > "$DDL_FILE" || { log_error "pg_dump failed"; exit 1; }
        ;;
    MySQL)
        command -v mysqldump &>/dev/null || { log_error "mysqldump not found"; exit 1; }
        HOST=$(echo "$CONN_STR" | sed -n 's/.*@\([^:/]*\).*/\1/p')
        DB=$(echo "$CONN_STR" | sed 's/.*\///')
        USER=$(echo "$CONN_STR" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
        PASS=$(echo "$CONN_STR" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
        mysqldump -h "$HOST" -u "$USER" -p"$PASS" --no-data "$DB" > "$DDL_FILE" || { log_error "mysqldump failed"; exit 1; }
        ;;
    *) log_error "Unsupported: ${DB_TYPE}"; exit 1 ;;
esac

log_ok "Exported: ${DDL_FILE} ($(wc -l < "$DDL_FILE") lines)"

# ── Graphify on DDL ──
if command -v graphify &>/dev/null; then
    log_info "Parsing DDL with Graphify..."
    (cd "$DB_SCHEMA_DIR" && graphify build . --update 2>&1) || log_warn "Graphify on DDL had warnings"
fi

# ── Create wiki doc ──
TABLES_DOC="# DB Schema: ${DB_NAME}\n\n**Type**: ${DB_TYPE}\n**Synced**: $(now)\n\n## Tables\n"
while IFS= read -r line; do
    TABLE_NAME=$(echo "$line" | sed 's/CREATE TABLE //i; s/ (//; s/ //g' 2>/dev/null || true)
    [[ -z "$TABLE_NAME" ]] && continue
    TABLES_DOC="${TABLES_DOC}\n### ${TABLE_NAME}\n\n\`\`\`sql\n${line}\n\`\`\`\n"
done < <(grep -i "CREATE TABLE" "$DDL_FILE" 2>/dev/null | head -50 || true)

DOC_OUT=$(echo "$TABLES_DOC" | lark-cli docs +create --title "DB-${DB_NAME}-$(today)" --folder-token "$WIKI_FOLDER_TOKEN" --markdown "$TABLES_DOC" 2>&1) || {
    log_error "Create doc failed: $DOC_OUT"; exit 1
}
DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
[[ -n "$DOC_TOKEN" ]] && log_ok "Doc: ${DOC_TOKEN}"

LOG_TOKEN=$(config_get '.feishu_drive.log_doc_token' '')
[[ -n "$LOG_TOKEN" ]] && {
    LOG_ENTRY="\n## [$(today)] sync-db | ${DB_NAME}\n- Tables: $(grep -ci 'CREATE TABLE' "$DDL_FILE" || echo 0)\n"
    lark-cli docs +update "$LOG_TOKEN" --content "$(echo "$LOG_ENTRY" | sed 's/"/\\"/g')" 2>/dev/null || true
}

log_ok "Done: ${DB_NAME}"

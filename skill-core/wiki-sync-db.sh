#!/usr/bin/env bash
# wiki-sync-db — Export database schema and sync to wiki
# Usage: wiki-sync-db --conn <connection_string> [--name <db_name>] [--type <db_type>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

CONN_STR=""
DB_NAME=""
DB_TYPE="PostgreSQL"

# ── Parse args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --conn)     CONN_STR="$2"; shift 2 ;;
        --name)     DB_NAME="$2"; shift 2 ;;
        --type)     DB_TYPE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: wiki-sync-db --conn <dsn> [--name <name>] [--type <type>]"
            echo ""
            echo "Examples:"
            echo "  wiki-sync-db --conn 'postgresql://user:pass@localhost:5432/mydb' --name production"
            echo "  wiki-sync-db --conn 'mysql://user:pass@localhost/mydb' --type MySQL"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$CONN_STR" ]]; then
    log_error "No connection string. Use: --conn <dsn>"
    exit 1
fi

[[ -z "$DB_NAME" ]] && DB_NAME=$(echo "$CONN_STR" | sed 's/.*\///')

# ── Pre-checks ─────────────────────────────────────────────────────────────
require_lark_cli
require_graphify
WIKI_FOLDER_TOKEN=$(get_wiki_folder_token)

DB_SCHEMA_DIR="${RAW_DIR}/30-development/db-schemas"
mkdir -p "$DB_SCHEMA_DIR"

# ── Export schema ──────────────────────────────────────────────────────────
DDL_FILE="${DB_SCHEMA_DIR}/${DB_NAME}-schema-$(today).sql"
log_info "Exporting schema from ${DB_TYPE}..."

case "$DB_TYPE" in
    PostgreSQL)
        if ! command -v pg_dump &>/dev/null; then
            log_error "pg_dump not found. Install postgresql-client."
            exit 1
        fi
        pg_dump --schema-only "$CONN_STR" > "$DDL_FILE" 2>/dev/null || {
            log_error "pg_dump failed. Check connection string."
            exit 1
        }
        ;;
    MySQL)
        if ! command -v mysqldump &>/dev/null; then
            log_error "mysqldump not found. Install mysql-client."
            exit 1
        fi
        # Parse connection string
        MYSQL_HOST=$(echo "$CONN_STR" | sed -n 's/.*@\([^:/]*\).*/\1/p')
        MYSQL_DB=$(echo "$CONN_STR" | sed 's/.*\///')
        MYSQL_USER=$(echo "$CONN_STR" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
        MYSQL_PASS=$(echo "$CONN_STR" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
        mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" --no-data "$MYSQL_DB" > "$DDL_FILE" 2>/dev/null || {
            log_error "mysqldump failed. Check credentials."
            exit 1
        }
        ;;
    *)
        log_error "Unsupported DB type: $DB_TYPE"
        exit 1
        ;;
esac

log_ok "Schema exported: ${DDL_FILE}"
wc -l < "$DDL_FILE" | xargs echo "  Lines:"

# ── Run Graphify on DDL ────────────────────────────────────────────────────
log_info "Parsing DDL with Graphify..."

GRAPHIFY_OUT=$(cd "$DB_SCHEMA_DIR" && graphify build . --update 2>&1) || {
    log_warn "Graphify on DDL produced warnings (normal for SQL): $GRAPHIFY_OUT"
}

# ── Extract table info for wiki ────────────────────────────────────────────
log_info "Extracting table metadata..."

TABLES_DOC="# Database Schema: ${DB_NAME}\n\n**Type**: ${DB_TYPE}\n**Synced**: $(now)\n**DDL**: \`${DDL_FILE}\`\n\n## Tables\n"

# Parse tables from DDL (simple regex extraction)
while IFS= read -r table; do
    TABLE_NAME=$(echo "$table" | sed 's/CREATE TABLE //i; s/ (//; s/ //g')
    [[ -z "$TABLE_NAME" ]] && continue
    TABLES_DOC="${TABLE_DOC}\n### ${TABLE_NAME}\n\n\`\`\`sql\n${table}\n\`\`\`\n"
done < <(grep -i "CREATE TABLE" "$DDL_FILE" 2>/dev/null | head -50 || true)

# ── Write to Feishu wiki ───────────────────────────────────────────────────
DOC_TITLE="DB-Schema-${DB_NAME}-$(today)"
DOC_OUT=$(echo "$TABLES_DOC" | lark-cli docs +create \
    --title "$DOC_TITLE" \
    --folder-token "$WIKI_FOLDER_TOKEN" \
    --markdown "$TABLES_DOC" 2>&1) || {
    log_error "Failed to create schema doc: $DOC_OUT"
    exit 1
}

DOC_TOKEN=$(extract_doc_token "$DOC_OUT" || true)
if [[ -n "$DOC_TOKEN" ]]; then
    log_ok "Schema doc: ${DOC_TOKEN}"
fi

# Update log
LOG_TOKEN=$(config_get '.feishu_drive.log_doc_token' '')
if [[ -n "$LOG_TOKEN" ]]; then
    LOG_ENTRY="\n## [$(today)] sync-db | ${DB_NAME}\n- Type: ${DB_TYPE}\n- Tables: $(grep -ci 'CREATE TABLE' "$DDL_FILE" || echo 0)\n- Doc: ${DOC_TOKEN:-unknown}\n"
    lark-cli docs +update "$LOG_TOKEN" \
        --content "$(echo "$LOG_ENTRY" | sed 's/"/\\"/g')" 2>/dev/null || true
fi

log_ok "Database sync complete: ${DB_NAME}"

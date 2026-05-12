#!/usr/bin/env bash
# LLM Wiki — Shared configuration and utilities
# Source this file: source "$(dirname "$0")/lib/config.sh"

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
CONFIG_FILE="${PROJECT_ROOT}/config/wiki-config.json"
STATE_FILE="${PROJECT_ROOT}/.wiki-state.json"
RAW_DIR="${PROJECT_ROOT}/raw"

# ── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Config helpers ─────────────────────────────────────────────────────────

require_lark_cli() {
    if ! command -v lark-cli &>/dev/null; then
        log_error "lark-cli not found. Install: npm install -g @larksuite/cli"
        exit 1
    fi
}

require_graphify() {
    if ! command -v graphify &>/dev/null; then
        log_error "graphify not found. Install: npm install -g @graphify-labs/graphify"
        exit 1
    fi
}

require_git() {
    if ! command -v git &>/dev/null; then
        log_error "git not found."
        exit 1
    fi
}

# Load config value from wiki-config.json
config_get() {
    local key="$1"
    local default="${2:-}"
    if [[ -f "$CONFIG_FILE" ]]; then
        local val
        val=$(jq -r "$key // empty" "$CONFIG_FILE" 2>/dev/null || true)
        if [[ -n "$val" && "$val" != "null" ]]; then
            echo "$val"
            return
        fi
    fi
    echo "$default"
}

# Save config value to wiki-config.json
config_set() {
    local key="$1"
    local val="$2"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo '{}' > "$CONFIG_FILE"
    fi
    local tmp
    tmp=$(mktemp)
    jq "$key = \"$val\"" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
}

# Get wiki folder token (cached)
get_wiki_folder_token() {
    local token
    token=$(config_get '.feishu_drive.wiki_folder_token' '')
    if [[ -z "$token" ]]; then
        log_error "Wiki folder token not configured. Run: wiki-init"
        exit 1
    fi
    echo "$token"
}

# Get raw folder token (cached)
get_raw_folder_token() {
    config_get '.feishu_drive.raw_folder_token' ''
}

# ── Document helpers ───────────────────────────────────────────────────────

# Get doc token from a created document (extract from lark-cli output)
extract_doc_token() {
    local output="$1"
    echo "$output" | grep -oE 'doxcn[A-Za-z0-9]+' | head -1
}

# Get folder token from created folder
extract_folder_token() {
    local output="$1"
    echo "$output" | grep -oE 'fldcn[A-Za-z0-9]+' | head -1
}

# ── Frontmatter helpers ────────────────────────────────────────────────────

# Extract type from frontmatter
extract_entity_type() {
    local file="$1"
    grep -m1 '^type:' "$file" | sed 's/type: *//' | tr -d ' "' || true
}

# Extract id from frontmatter
extract_entity_id() {
    local file="$1"
    # Try common id fields
    for key in us_id prd_id epic_id task_id bug_id adr_id rule_id sprint_id meeting_id; do
        local val
        val=$(grep -m1 "^${key}:" "$file" | sed "s/${key}: *//" | tr -d ' "' || true)
        if [[ -n "$val" ]]; then
            echo "$val"
            return
        fi
    done
    # Fallback: filename without extension
    basename "$file" .md
}

# Extract title from frontmatter or first heading
extract_title() {
    local file="$1"
    local title
    title=$(grep -m1 '^title:' "$file" | sed 's/title: *//' | sed 's/^"//;s/"$//' || true)
    if [[ -z "$title" ]]; then
        title=$(grep -m1 '^# ' "$file" | sed 's/^# *//' || true)
    fi
    if [[ -z "$title" ]]; then
        title=$(basename "$file" .md)
    fi
    echo "$title"
}

# ── Graphify helpers ──────────────────────────────────────────────────────

# Check if graphify cache is stale (returns 0 if stale)
is_graph_stale() {
    local repo_dir="$1"
    local cache_file="${repo_dir}/.graphify/cache.json"
    if [[ ! -f "$cache_file" ]]; then
        return 0  # stale: no cache
    fi
    # Compare current HEAD hash with cached hash
    local current_hash
    current_hash=$(cd "$repo_dir" && git rev-parse HEAD)
    local cached_hash
    cached_hash=$(jq -r '.last_commit_hash // empty' "$cache_file" 2>/dev/null || true)
    if [[ "$current_hash" != "$cached_hash" ]]; then
        return 0  # stale
    fi
    return 1  # not stale
}

# Run graphify build if stale
maybe_graphify_build() {
    local repo_dir="$1"
    if is_graph_stale "$repo_dir"; then
        log_info "Graphify cache stale, rebuilding..."
        (cd "$repo_dir" && graphify build . --update)
        log_ok "Graphify build complete"
    else
        log_info "Graphify cache up to date, skipping build"
    fi
}

# ── Date helper ────────────────────────────────────────────────────────────
now() {
    date +"%Y-%m-%d %H:%M"
}

today() {
    date +"%Y-%m-%d"
}

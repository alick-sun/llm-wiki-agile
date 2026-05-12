#!/usr/bin/env bash
# check-env — Verify all required tools are installed and configured

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Add project bin/ to PATH for local jq
export PATH="${PROJECT_ROOT}/bin:${PATH}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_ok()    { echo -e "${GREEN}[✓]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC}  $*"; }
log_error() { echo -e "${RED}[✗]${NC}  $*"; }
log_info()  { echo -e "${BLUE}[i]${NC}  $*"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  LLM Wiki — Environment Check"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check required tools
TOOLS_OK=0
TOOLS_FAIL=0

check_tool() {
    local tool="$1"
    local install_cmd="$2"
    if command -v "$tool" &>/dev/null; then
        local version
        version=$(eval "$tool --version 2>&1" || eval "$tool version 2>&1" || echo "unknown")
        log_ok "$tool (${version%%$'\n'*})"
        ((TOOLS_OK++)) || true
    else
        log_error "$tool missing. Install: $install_cmd"
        ((TOOLS_FAIL++)) || true
    fi
}

echo "Required Tools:"
check_tool "git"         "choco install git"
check_tool "node"        "https://nodejs.org/"
check_tool "npm"         "comes with node"
check_tool "jq"          "choco install jq"
check_tool "lark-cli"   "npm install -g @larksuite/cli"
check_tool "graphify"    "npm install -g graphify"

echo ""
echo "Summary: $TOOLS_OK ok, $TOOLS_FAIL missing"

# Check project structure
echo ""
echo "Project Structure:"
check_dir() {
    local dir="$1"
    if [[ -d "$PROJECT_ROOT/$dir" ]]; then
        log_ok "$dir/"
    else
        log_warn "$dir/ (not created yet - run wiki-init)"
    fi
}

check_dir "scripts"
check_dir "schema"
check_dir "skill-core"

# Check scripts are executable
echo ""
echo "Scripts:"
for script in "$PROJECT_ROOT"/scripts/*.sh; do
    if [[ -x "$script" ]]; then
        log_ok "$(basename "$script")"
    else
        log_warn "$(basename "$script") (not executable)"
    fi
done

# Check lark-cli auth
echo ""
echo "Authentication:"
if command -v lark-cli &>/dev/null; then
    if lark-cli auth whoami 2>/dev/null; then
        log_ok "lark-cli authenticated"
    else
        log_warn "lark-cli not authenticated. Run: lark-cli auth login"
    fi
fi

# Recommendations
echo ""
if [[ $TOOLS_FAIL -gt 0 ]]; then
    log_error "Please install missing tools before using the wiki."
    exit 1
else
    log_ok "All tools installed!"
    echo ""
    echo "Next steps:"
    echo "  1. lark-cli auth login          # Authenticate with Feishu"
    echo "  2. ./bin/wiki-init              # Initialize wiki"
    echo "  3. ./bin/wiki-ingest <source>   # Add your first document"
fi

echo "═══════════════════════════════════════════════════════════════"

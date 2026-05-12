#!/usr/bin/env bash
# setup — One-time environment setup for LLM Wiki

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_ok()    { echo -e "${GREEN}[✓]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC}  $*"; }
log_error() { echo -e "${RED}[✗]${NC}  $*"; }
log_info()  { echo -e "${BLUE}[i]${NC}  $*"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  LLM Wiki — Environment Setup"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    MINGW*|MSYS*) MACHINE=Windows;;
    *)          MACHINE="UNKNOWN:$OS"
esac

log_info "Detected: $MACHINE"

# Install jq if missing
if ! command -v jq &>/dev/null; then
    log_warn "jq not found. Installing..."
    case "$MACHINE" in
        Windows)
            if command -v choco &>/dev/null; then
                choco install jq -y
                log_ok "jq installed via Chocolatey"
            else
                log_error "Chocolatey not found. Install jq manually: https://stedolan.github.io/jq/download/"
                exit 1
            fi
            ;;
        Mac)
            if command -v brew &>/dev/null; then
                brew install jq
                log_ok "jq installed via Homebrew"
            else
                log_error "Homebrew not found. Install: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                exit 1
            fi
            ;;
        Linux)
            if command -v apt-get &>/dev/null; then
                sudo apt-get install -y jq
            elif command -v yum &>/dev/null; then
                sudo yum install -y jq
            else
                log_error "Please install jq manually"
                exit 1
            fi
            log_ok "jq installed"
            ;;
    esac
else
    log_ok "jq already installed"
fi

# Install lark-cli if missing
if ! command -v lark-cli &>/dev/null; then
    log_warn "lark-cli not found. Installing..."
    npm install -g @larksuite/cli
    log_ok "lark-cli installed"
else
    log_ok "lark-cli already installed"
fi

# Install graphify if missing
if ! command -v graphify &>/dev/null; then
    log_warn "graphify not found. Installing..."
    npm install -g graphify
    log_ok "graphify installed"
else
    log_ok "graphify already installed"
fi

# Make scripts executable
log_info "Making scripts executable..."
chmod +x "$PROJECT_ROOT"/scripts/*.sh 2>/dev/null || true
chmod +x "$PROJECT_ROOT"/bin/* 2>/dev/null || true
log_ok "Scripts executable"

# Create bin symlinks
log_info "Creating command shortcuts..."
mkdir -p "$PROJECT_ROOT/bin"
for script in "$PROJECT_ROOT"/scripts/*.sh; do
    name="$(basename "$script" .sh)"
    ln -sf "$script" "$PROJECT_ROOT/bin/$name" 2>/dev/null || true
done
log_ok "Created bin/ shortcuts"

# Add to PATH reminder
echo ""
log_ok "Setup complete!"
echo ""
echo "Quick commands:"
echo "  ./bin/check-env     — Verify environment"
echo "  ./bin/wiki-init     — Initialize wiki"
echo "  ./bin/wiki-ingest   — Add documents"
echo "  ./bin/wiki-query    — Search knowledge"
echo ""
echo "Next steps:"
echo "  1. lark-cli auth login      # Authenticate with Feishu"
echo "  2. ./bin/wiki-init          # Create wiki structure"
echo "  3. ./bin/wiki-ingest <url>  # Add your first document"
echo ""
echo "═══════════════════════════════════════════════════════════════"

#!/usr/bin/env bash
# env.sh — Project environment setup
# Source this file: source scripts/env.sh

export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${PROJECT_ROOT}/bin:${PATH}"

# Verify jq is available
if ! command -v jq &>/dev/null; then
    echo "Warning: jq not found in PATH" >&2
fi

echo "✓ Environment configured for LLM Wiki"
echo "  PROJECT_ROOT: ${PROJECT_ROOT}"
echo "  jq: $(command -v jq 2>/dev/null || echo 'not found')"

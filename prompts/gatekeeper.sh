#!/usr/bin/env bash
# GATEKEEPER — Automated quality gates (no LLM)
# Usage: gatekeeper.sh <worktree-path> [project-type]
# Exit 0 = PASS, Exit 1 = FAIL
# 
# This script runs ALL automated quality checks.
# Every check must pass. No exceptions. No overrides.

set -euo pipefail

WORKTREE="${1:?Usage: gatekeeper.sh <worktree-path> [project-type]}"
PROJECT_TYPE="${2:-auto}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILURES=()

run_check() {
    local name="$1"
    shift
    echo -e "${YELLOW}▶ Running: ${name}${NC}"
    if "$@" 2>&1; then
        echo -e "${GREEN}✅ ${name}: PASSED${NC}"
    else
        echo -e "${RED}❌ ${name}: FAILED${NC}"
        FAILURES+=("$name")
    fi
    echo ""
}

cd "$WORKTREE"

# Auto-detect project type
if [ "$PROJECT_TYPE" = "auto" ]; then
    [ -f "pyproject.toml" ] && PROJECT_TYPE="python"
    [ -f "package.json" ] && PROJECT_TYPE="node"
    [ -f "pyproject.toml" ] && [ -d "frontend" ] && PROJECT_TYPE="fullstack"
fi

echo "=========================================="
echo "  GATEKEEPER — Quality Gates"
echo "  Worktree: $WORKTREE"
echo "  Type: $PROJECT_TYPE"
echo "=========================================="
echo ""

case "$PROJECT_TYPE" in
    python)
        run_check "Ruff (lint)" ruff check src/
        run_check "Ruff (format)" ruff format --check src/
        run_check "MyPy (types)" mypy src/
        run_check "Pytest (tests)" pytest --tb=short -q
        ;;
    node)
        run_check "Check" npm run check
        run_check "Build" npm run build
        ;;
    fullstack)
        # Backend
        echo "--- BACKEND ---"
        run_check "Ruff (lint)" ruff check src/
        run_check "Ruff (format)" ruff format --check src/
        run_check "MyPy (types)" mypy src/
        run_check "Pytest (tests)" pytest --tb=short -q
        # Frontend
        echo "--- FRONTEND ---"
        cd frontend
        run_check "Svelte Check" npm run check
        run_check "Frontend Build" npm run build
        cd ..
        ;;
    *)
        echo -e "${RED}Unknown project type: $PROJECT_TYPE${NC}"
        exit 1
        ;;
esac

echo "=========================================="
if [ ${#FAILURES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ ALL GATES PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ FAILED GATES:${NC}"
    for f in "${FAILURES[@]}"; do
        echo -e "${RED}  - $f${NC}"
    done
    exit 1
fi

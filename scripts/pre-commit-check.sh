#!/bin/bash
# pre-commit-check.sh — Run before committing to verify no secrets in source
#
# Install as a git hook:
#   cp scripts/pre-commit-check.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit

set -e

echo "Running pre-commit security check..."

# Check staged files for API keys
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)

if [ -z "$STAGED_FILES" ]; then
    echo "No Swift files staged, skipping."
    exit 0
fi

ISSUES=0

# Check for hardcoded API keys
for file in $STAGED_FILES; do
    if grep -n "sk-ant-\|sk-proj-\|AKIA[0-9A-Z]\{16\}\|ghp_[A-Za-z0-9]\{36\}\|gho_[A-Za-z0-9]" "$file" 2>/dev/null; then
        echo "ERROR: Potential API key found in $file"
        ISSUES=$((ISSUES + 1))
    fi
done

# Check for Process() or shell execution in src/
for file in $STAGED_FILES; do
    if echo "$file" | grep -q "^src/"; then
        if grep -n "Process()\|NSTask\|/bin/bash\|/bin/sh" "$file" 2>/dev/null; then
            echo "ERROR: Shell execution found in $file"
            ISSUES=$((ISSUES + 1))
        fi
    fi
done

if [ $ISSUES -gt 0 ]; then
    echo "Pre-commit check FAILED: $ISSUES issue(s) found."
    echo "Fix the issues or use --no-verify to skip (not recommended)."
    exit 1
fi

echo "Pre-commit check passed."
exit 0

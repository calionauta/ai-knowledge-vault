#!/bin/bash
# coverage-report.sh — Show what percentage of raw notes have been compiled.
#
# Portable: works with any markdown vault, no KiwiFS frontmatter needed.
# Counts raw files vs wiki source files to determine coverage.
#
# Usage: bash coverage-report.sh [--json]

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"
JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

# Count raw files (exclude trash, hidden, and temp files)
RAW_FILES=$(curl -sf "${KIWI_API}/api/kiwi/tree?path=raw/" 2>/dev/null || echo '{"results":[]}')
RAW_COUNT=$(echo "$RAW_FILES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get('results', data if isinstance(data, list) else [])
    # Filter: only .md files, exclude trash/ prefix
    count = 0
    for item in items:
        path = item.get('path', item) if isinstance(item, dict) else item
        if path.endswith('.md') and not path.startswith('raw/trash/'):
            count += 1
    print(count)
except: print(0)
" 2>/dev/null)

# Count wiki source files
WIKI_FILES=$(curl -sf "${KIWI_API}/api/kiwi/tree?path=wiki/sources/" 2>/dev/null || echo '{"results":[]}')
WIKI_COUNT=$(echo "$WIKI_FILES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get('results', data if isinstance(data, list) else [])
    count = len(items)
    print(count)
except: print(0)
" 2>/dev/null)

# Calculate coverage
if [ "$RAW_COUNT" -gt 0 ]; then
    COVERAGE=$(echo "scale=2; $WIKI_COUNT * 100 / $RAW_COUNT" | bc 2>/dev/null || echo "0")
else
    COVERAGE="0"
fi
NOT_COMPILED=$((RAW_COUNT - WIKI_COUNT))

if $JSON; then
  cat << JSONEOF
{
  "total_raw": $RAW_COUNT,
  "compiled": $WIKI_COUNT,
  "not_compiled": $NOT_COMPILED,
  "coverage_pct": $COVERAGE
}
JSONEOF
else
  echo "──────────────────────────────────────"
  echo "  Coverage Report"
  echo "──────────────────────────────────────"
  echo "  Total raw files:   $RAW_COUNT"
  echo "  Compiled (wiki):   $WIKI_COUNT"
  echo "  Not compiled:      $NOT_COMPILED"
  echo "  Coverage:          ${COVERAGE}%"
  echo "──────────────────────────────────────"
fi

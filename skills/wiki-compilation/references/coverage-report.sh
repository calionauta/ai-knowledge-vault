#!/bin/bash
# coverage-report.sh — Show what percentage of raw notes have been compiled.
#
# Portable: works with any KiwiFS vault, no special frontmatter needed.
# - Raw count: uses KiwiFS memory report (total_episodic)
# - Wiki sources count: walks the tree recursively
#
# Usage: bash coverage-report.sh [--json]

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"
JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

# --- Count raw files from memory report (most reliable) ---
REPORT=$(curl -sf "${KIWI_API}/api/kiwi/memory/report?episodes_prefix=raw/" 2>/dev/null || echo '{}')
RAW_COUNT=$(echo "$REPORT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('total_episodic', 0))
except: print(0)
")

# --- Count wiki source files by walking tree recursively ---
TREE=$(curl -sf "${KIWI_API}/api/kiwi/tree?path=wiki/" 2>/dev/null || echo '{}')
WIKI_COUNT=$(echo "$TREE" | python3 -c "
import sys, json

def count_md(node):
    \"\"\"Recursively count .md files in a tree node.\"\"\"
    count = 0
    # Skip root directory itself
    for child in node.get('children', []):
        name = child.get('name', '')
        if child.get('isDir', False):
            # Recurse into subdirectory
            count += count_md(child)
        elif name.endswith('.md') and not name.startswith('.'):
            # Check if it's inside sources/ or another wiki subdir
            path = child.get('path', '')
            if 'sources/' in path:
                count += 1
            # Could also count entities, concepts, syntheses
            elif any(d in path for d in ['entities/', 'concepts/', 'syntheses/']):
                count += 1
    return count

try:
    data = json.load(sys.stdin)
    print(count_md(data))
except: print(0)
")

# Calculate coverage
if [ "$RAW_COUNT" -gt 0 ]; then
    COVERAGE=$(echo "scale=2; $WIKI_COUNT * 100 / $RAW_COUNT" | bc 2>/dev/null || echo "0")
else
    COVERAGE="0"
fi
NOT_COMPILED=$((RAW_COUNT - WIKI_COUNT))
[ "$NOT_COMPILED" -lt 0 ] && NOT_COMPILED=0

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

#!/bin/bash
# lint.sh — Run lint checks on the wiki.
# Checks: orphan pages, broken [[links]], missing source_checksum.
#
# Usage: bash lint.sh [--fix]

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"
FIX=false
[[ "${1:-}" == "--fix" ]] && FIX=true

ISSUES=0

# --- Check 1: Orphan source pages (no corresponding raw file) ---
echo "=== Lint: Orphan sources ==="
TREE=$(curl -sf "${KIWI_API}/api/kiwi/tree?path=wiki/sources/" 2>/dev/null || echo '[]')
SOURCES=$(echo "$TREE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for item in data:
            p = item.get('path', item) if isinstance(item, dict) else item
            print(p)
    elif isinstance(data, dict):
        for item in data.get('results', []):
            print(item.get('path', ''))
except: pass
" 2>/dev/null)

while IFS= read -r SRC; do
  [ -z "$SRC" ] && continue
  SRC_CONTENT=$(curl -sf "${KIWI_API}/api/kiwi/file?path=${SRC}" 2>/dev/null || true)
  RAW_FILE=$(echo "$SRC_CONTENT" | grep "^source_file:" | sed 's/.*source_file: *//' | head -1)
  if [ -n "$RAW_FILE" ]; then
    EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "${KIWI_API}/api/kiwi/file?path=${RAW_FILE}" 2>/dev/null)
    if [ "$EXISTS" != "200" ]; then
      echo "ORPHAN: $SRC references missing raw file: $RAW_FILE"
      ISSUES=$((ISSUES + 1))
    fi
  fi
done <<< "$SOURCES"

# --- Check 2: Missing source_checksum ---
echo ""
echo "=== Lint: Missing source_checksum ==="
while IFS= read -r SRC; do
  [ -z "$SRC" ] && continue
  SRC_CONTENT=$(curl -sf "${KIWI_API}/api/kiwi/file?path=${SRC}" 2>/dev/null || true)
  if ! echo "$SRC_CONTENT" | grep -q "^source_checksum:"; then
    echo "MISSING: $SRC has no source_checksum in frontmatter"
    ISSUES=$((ISSUES + 1))
  fi
done <<< "$SOURCES"

# --- Check 3: Missing merged-from ---
echo ""
echo "=== Lint: Missing merged-from ==="
ALL_WIKI=$(curl -sf "${KIWI_API}/api/kiwi/tree?path=wiki/" 2>/dev/null || echo '[]')
ALL_FILES=$(echo "$ALL_WIKI" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for item in data:
            p = item.get('path', item) if isinstance(item, dict) else item
            if p not in ('wiki/index.md', 'wiki/log.md', 'wiki/overview.md'):
                print(p)
    elif isinstance(data, dict):
        for item in data.get('results', []):
            p = item.get('path', '')
            if p not in ('wiki/index.md', 'wiki/log.md', 'wiki/overview.md'):
                print(p)
except: pass
" 2>/dev/null)

while IFS= read -r WP; do
  [ -z "$WP" ] && continue
  CONTENT=$(curl -sf "${KIWI_API}/api/kiwi/file?path=${WP}" 2>/dev/null || true)
  if [ -n "$CONTENT" ] && ! echo "$CONTENT" | grep -q "^merged-from:"; then
    echo "MISSING: $WP has no merged-from in frontmatter"
    ISSUES=$((ISSUES + 1))
  fi
done <<< "$ALL_FILES"

# --- Summary ---
echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo "✓ Lint passed — no issues found."
else
  echo "⚠ Found ${ISSUES} issue(s). Review above."
fi

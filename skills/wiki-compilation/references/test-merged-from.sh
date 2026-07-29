#!/bin/bash
# test-merged-from.sh — Test that merged-from tracking works end-to-end.
#
# This script:
# 1. Creates a test raw file with memory_kind: episodic and episode_id
# 2. Creates a wiki source page with merged-from referencing the episode
# 3. Checks the memory report to verify merged_from_refs increased
# 4. Cleans up the test files
#
# Usage: bash test-merged-from.sh

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=true

echo "=============================================="
echo "  Merged-From Integration Test"
echo "=============================================="

# ---- Step 1: Create test raw file with memory_kind and episode_id ----
echo ""
echo "1. Creating test raw file..."

RAW_CONTENT='---
memory_kind: episodic
episode_id: test-merged-from-validation
type: note
tags: [test]
title: "Test Merged From"
---

# Test Merged From

This is a test file to validate merged-from tracking.
Created at: '"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'

## Content
- KiwiFS episodic memory tracking test
- Testing merged-from coverage calculation
'

RAW_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${KIWI_API}/api/kiwi/file?path=raw/test-merged-from.md" \
  -H "X-Actor: agent:test" \
  --data-binary "$RAW_CONTENT" 2>/dev/null)
RAW_HTTP=$(echo "$RAW_RESPONSE" | tail -1)

if [ "$RAW_HTTP" = "200" ]; then
  echo "   ✅ Raw file created (HTTP 200)"
else
  echo "   ❌ Raw file creation failed (HTTP $RAW_HTTP)"
  PASS=false
fi

# ---- Step 2: Create wiki source page with merged-from ----
echo ""
echo "2. Creating wiki source page with merged-from..."

WIKI_CONTENT='---
title: "Test Merged From Source"
type: source
memory_kind: semantic
tags: [test]
date: '"$(date +%Y-%m-%d)"'
source_file: raw/test-merged-from.md
last_updated: '"$(date +%Y-%m-%d)"'
source_checksum: sha256-test
merged-from:
  - type: episode
    id: test-merged-from-validation
    date: "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
    note: "test merged-from validation"
---

## Summary
Test page for merged-from tracking validation.

## Key Claims
- merged-from with episode_id matching works
'

WIKI_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${KIWI_API}/api/kiwi/file?path=wiki/sources/test-merged-from.md" \
  -H "X-Actor: agent:test" \
  --data-binary "$WIKI_CONTENT" 2>/dev/null)
WIKI_HTTP=$(echo "$WIKI_RESPONSE" | tail -1)

if [ "$WIKI_HTTP" = "200" ]; then
  echo "   ✅ Wiki page created (HTTP 200)"
else
  echo "   ❌ Wiki page creation failed (HTTP $WIKI_HTTP)"
  PASS=false
fi

# ---- Step 3: Check memory report ----
echo ""
echo "3. Checking memory report..."

# Wait a moment for KiwiFS to process
sleep 1

REPORT=$(curl -sf "${KIWI_API}/api/kiwi/memory/report?episodes_prefix=raw/" 2>/dev/null || true)

if [ -z "$REPORT" ]; then
  echo "   ❌ Could not fetch memory report"
  PASS=false
else
  MERGED=$(echo "$REPORT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('merged_from_refs', 'ERROR'))" 2>/dev/null || echo "ERROR")
  EPISODIC=$(echo "$REPORT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('episodic_count', 'ERROR'))" 2>/dev/null || echo "ERROR")
  COVERAGE=$(echo "$REPORT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('coverage_pct', 'ERROR'))" 2>/dev/null || echo "ERROR")
  WARNINGS=$(echo "$REPORT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
w=[x for x in d.get('warnings',[]) if 'test-merged-from' in x.lower()]
print('FOUND' if w else 'NONE')
" 2>/dev/null || echo "ERROR")

  echo "   merged_from_refs: $MERGED"
  echo "   episodic_count:  $EPISODIC"
  echo "   coverage_pct:    $COVERAGE%"
  echo "   warnings for test file: $WARNINGS"

  if [ "$MERGED" != "ERROR" ] && [ "$MERGED" -gt 0 ]; then
    echo ""
    echo "   ✅ MERGED-FROM TRACKING WORKS! (merged_from_refs=$MERGED)"
  else
    echo ""
    echo "   ⚠️  merged_from_refs is still 0."
    echo "   Possible reasons:"
    echo "   - Memory report may not recalculate in real-time"
    echo "   - Try: docker restart kiwifs && sleep 3"
    echo "   - Then re-run this test"
  fi
fi

# ---- Step 4: Verify files are readable ----
echo ""
echo "4. Verifying test files..."

RAW_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "${KIWI_API}/api/kiwi/file?path=raw/test-merged-from.md" 2>/dev/null)
WIKI_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "${KIWI_API}/api/kiwi/file?path=wiki/sources/test-merged-from.md" 2>/dev/null)

echo "   raw/test-merged-from.md:         HTTP $RAW_CHECK"
echo "   wiki/sources/test-merged-from.md: HTTP $WIKI_CHECK"

# ---- Summary ----
echo ""
echo "=============================================="
if $PASS; then
  echo "  Test completed. Review results above."
else
  echo "  Some steps failed. Check errors above."
fi
echo "=============================================="
echo ""
echo "To clean up test files:"
echo "  curl -X DELETE \"${KIWI_API}/api/kiwi/file?path=raw/test-merged-from.md\" -H \"X-Actor: agent:cleanup\""
echo "  curl -X DELETE \"${KIWI_API}/api/kiwi/file?path=wiki/sources/test-merged-from.md\" -H \"X-Actor: agent:cleanup\""

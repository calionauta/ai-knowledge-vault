#!/bin/bash
# check-coverage.sh — Query KiwiFS memory report and print coverage summary.
#
# Usage: bash check-coverage.sh [--json]

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"
JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

REPORT=$(curl -sf "${KIWI_API}/api/kiwi/memory/report?episodes_prefix=raw/" 2>/dev/null || true)
if [ -z "$REPORT" ]; then
  echo "ERROR: Could not reach KiwiFS API at ${KIWI_API}" >&2
  exit 1
fi

if $JSON; then
  echo "$REPORT"
else
  echo "$REPORT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ep = data.get('episodic_count', data.get('total_episodic', 0))
merged = data.get('merged_from_refs', 0)
coverage = data.get('coverage_pct', 0)
unmerged = data.get('total_unmerged', ep)
contra = data.get('contradictions', 0)
avg_age = data.get('avg_age_days', 0)
print(f'Episodic files: {ep}')
print(f'Total unmerged: {unmerged}')
print(f'Merged refs:    {merged}')
print(f'Coverage:       {coverage}%')
print(f'Contradictions: {contra}')
print(f'Avg age:        {avg_age:.1f} days')
"
fi

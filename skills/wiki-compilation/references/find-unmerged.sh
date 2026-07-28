#!/bin/bash
# find-unmerged.sh — List raw files that need wiki compilation.
# Uses KiwiFS memory report to find unmerged files, then filters out
# any that already have a wiki/sources/<slug>.md page.
#
# Usage: bash find-unmerged.sh [--limit N] [--json]
#   --limit N  Max files to return (default: 10)
#   --json     Output JSON lines for machine parsing (default: human-readable)

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"
LIMIT=10
JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2 ;;
    --json)  JSON=true; shift ;;
    *)       echo "Unknown: $1"; exit 1 ;;
  esac
done

# Helper: derive slug from raw path
slugify() {
  local path="$1"
  path="${path#raw/}"          # strip raw/ prefix
  path="${path%.md}"           # strip .md extension
  path="$(echo "$path" | tr ' /' '-' | tr '[:upper:]' '[:lower:]')"
  # Remove special chars except hyphens
  path="$(echo "$path" | sed 's/[^a-z0-9-]//g')"
  # Collapse multiple hyphens
  path="$(echo "$path" | sed 's/--*/-/g')"
  # Strip leading/trailing hyphens
  path="${path#-}"; path="${path%-}"
  echo "$path"
}

# Get list of unmerged episodic files from memory report
REPORT=$(curl -sf "${KIWI_API}/api/kiwi/memory/report?episodes_prefix=raw/&limit=5000")
if [ -z "$REPORT" ]; then
  echo "ERROR: Could not reach KiwiFS API at ${KIWI_API}" >&2
  exit 1
fi

# Parse episodic files JSON array
FILES=$(echo "$REPORT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data.get('episodic_files', []):
    print(f['path'])
" 2>/dev/null)

if [ -z "$FILES" ]; then
  echo "No unmerged files found."
  exit 0
fi

COUNT=0
while IFS= read -r RAW_PATH; do
  [ -z "$RAW_PATH" ] && continue
  [ "$COUNT" -ge "$LIMIT" ] && break

  SLUG=$(slugify "$RAW_PATH")
  SOURCE_PATH="wiki/sources/${SLUG}.md"

  # Check if source page already exists
  EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "${KIWI_API}/api/kiwi/file?path=${SOURCE_PATH}" 2>/dev/null)

  if [ "$EXISTS" != "200" ]; then
    # Read raw content and compute checksum
    RAW_CONTENT=$(curl -sf "${KIWI_API}/api/kiwi/file?path=${RAW_PATH}" 2>/dev/null || true)
    if [ -z "$RAW_CONTENT" ]; then
      continue  # skip unreadable files
    fi
    CHECKSUM=$(printf '%s' "$RAW_CONTENT" | sha256sum | cut -d' ' -f1)

    if $JSON; then
      printf '{"path":"%s","slug":"%s","checksum":"%s"}\n' "$RAW_PATH" "$SLUG" "$CHECKSUM"
    else
      echo "UNMERGED: $RAW_PATH → $SLUG (sha256:$CHECKSUM)"
    fi
    COUNT=$((COUNT + 1))
  fi
done <<< "$FILES"

if [ "$COUNT" -eq 0 ]; then
  echo "All raw files already compiled. Coverage should be 100%."
fi

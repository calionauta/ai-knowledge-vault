#!/bin/bash
# detect-changes.sh — Find wiki source pages whose raw file has changed.
# Compares stored source_checksum with current SHA256 of raw file content.
#
# Usage: bash detect-changes.sh [--json]

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"
JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

# List all wiki source files
TREE=$(curl -sf "${KIWI_API}/api/kiwi/tree?path=wiki/sources/" 2>/dev/null || echo '[]')
SOURCES=$(echo "$TREE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for item in data:
            print(item.get('path', item))
    elif isinstance(data, dict):
        for item in data.get('results', []):
            print(item.get('path', ''))
except:
    pass
" 2>/dev/null)

if [ -z "$SOURCES" ]; then
  echo "No wiki sources found."
  exit 0
fi

CHANGED=false
while IFS= read -r SRC_PATH; do
  [ -z "$SRC_PATH" ] && continue

  SRC_CONTENT=$(curl -sf "${KIWI_API}/api/kiwi/file?path=${SRC_PATH}" 2>/dev/null || true)
  [ -z "$SRC_CONTENT" ] && continue

  # Extract source_file and source_checksum from frontmatter
  RAW_FILE=$(echo "$SRC_CONTENT" | grep "^source_file:" | sed 's/.*source_file: *//' | head -1)
  STORED_CHECKSUM=$(echo "$SRC_CONTENT" | grep "^source_checksum:" | sed 's/.*source_checksum: *sha256-//' | head -1)

  [ -z "$RAW_FILE" ] && continue
  [ -z "$STORED_CHECKSUM" ] && continue

  # Read raw file and compute current checksum
  RAW_CONTENT=$(curl -sf "${KIWI_API}/api/kiwi/file?path=${RAW_FILE}" 2>/dev/null || true)
  [ -z "$RAW_CONTENT" ] && continue

  CURRENT_CHECKSUM=$(printf '%s' "$RAW_CONTENT" | sha256sum | cut -d' ' -f1)

  if [ "$CURRENT_CHECKSUM" != "$STORED_CHECKSUM" ]; then
    CHANGED=true
    SLUG=$(basename "$SRC_PATH" .md)
    if $JSON; then
      printf '{"path":"%s","slug":"%s","old_checksum":"%s","new_checksum":"%s"}\n' \
        "$RAW_FILE" "$SLUG" "$STORED_CHECKSUM" "$CURRENT_CHECKSUM"
    else
      echo "CHANGED: $RAW_FILE (sha256: $STORED_CHECKSUM → $CURRENT_CHECKSUM)"
    fi
  fi
done <<< "$SOURCES"

if ! $CHANGED; then
  echo "No changed files detected."
fi

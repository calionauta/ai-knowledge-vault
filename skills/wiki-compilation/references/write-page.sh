#!/bin/bash
# write-page.sh — Write a wiki page via KiwiFS API with proper headers.
# Handles merged-from frontmatter and source_checksum automatically.
#
# Usage: bash write-page.sh <path> <content>
#   Content should be full markdown including frontmatter.
#   The script adds X-Actor header automatically.

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"

if [ $# -lt 2 ]; then
  echo "Usage: write-page.sh <path> <content>" >&2
  echo "Example: write-page.sh wiki/sources/my-slug.md \"---\\ntitle: ...\" " >&2
  exit 1
fi

PATH_ARG="$1"
CONTENT="$2"
shift 2

# Encode the path for URL
ENCODED_PATH=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PATH_ARG'))" 2>/dev/null || echo "$PATH_ARG")

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${KIWI_API}/api/kiwi/file?path=${ENCODED_PATH}" \
  -H "X-Actor: agent:mercury" \
  --data-binary "$CONTENT" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo "OK: wrote ${PATH_ARG} (${HTTP_CODE})"
else
  echo "ERROR: ${HTTP_CODE} writing ${PATH_ARG}" >&2
  echo "$BODY" >&2
  exit 1
fi

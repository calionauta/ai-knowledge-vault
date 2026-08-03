#!/bin/bash
# coverage.sh — raw/vs/wiki-coverage by simple file counting (no external API).
#
# Usage: coverage.sh
# Env override: KB_DIR (default: ~/octarine-notes)

set -uo pipefail
KB_DIR="${KB_DIR:-$HOME/octarine-notes}"

RAW_COUNT=$(find "$KB_DIR/raw" -type f \( -name "*.md" -o -iname "*.pdf" -o -iname "*.txt" \
  -o -iname "*.html" -o -iname "*.docx" -o -iname "*.png" -o -iname "*.jpg" \) 2>/dev/null | wc -l)
SRC_COUNT=$(find "$KB_DIR/wiki/sources" -type f 2>/dev/null | wc -l)

PCT=0
if [ "$RAW_COUNT" -gt 0 ]; then
  PCT=$(( SRC_COUNT * 100 / RAW_COUNT ))
fi

echo "raw files:    $RAW_COUNT"
echo "wiki sources: $SRC_COUNT"
echo "coverage:     ${PCT}%"
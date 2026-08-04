#!/bin/bash
# compile.sh — daily-limited OpenKB compilation with priority for recent files.
#
# Priority:
#   1. All files modified in last 24h (recent — highest priority)
#   2. BATCH_SIZE oldest uncompiled files, sorted by modification date (newest first)
#
# OpenKB tracks compiled files in .openkb/hashes.json — never recompiles.
# Env: KB_DIR, OPENKB, BATCH_SIZE (default 30)
set -uo pipefail

KB_DIR="${KB_DIR:-$HOME/octarine-notes}"
OPENKB="${OPENKB:-$HOME/openkb-env/bin/openkb}"
BATCH_SIZE="${BATCH_SIZE:-30}"
cd "$KB_DIR" || exit 1
[ -f "$KB_DIR/.env" ] && { set -a; source "$KB_DIR/.env"; set +a; }

echo "[compile] start $(date -u +%FT%TZ)"
git pull --rebase >/dev/null 2>&1 || true

# Find uncompiled files (not in wiki/sources/, tracked by OpenKB hashes)
UNCOMPILED=$(find raw/ -type f -name "*.md" | while IFS= read -r f; do
  slug=$(basename "$f" .md)
  [ ! -f "wiki/sources/${slug}.md" ] && echo "$f"
done)

TOTAL_UNCOMPILED=$(echo "$UNCOMPILED" | grep -c "." 2>/dev/null || echo 0)
echo "[compile] uncompiled: $TOTAL_UNCOMPILED"

# Split: recent (24h) vs old
RECENT_FILES=""
OLD_FILES=""
echo "$UNCOMPILED" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ -n "$(find "$f" -mtime -1 2>/dev/null)" ]; then
    echo "R:$f"
  else
    echo "O:$f"
  fi
done > /tmp/compile_split_$$.txt

RECENT_COUNT=$(grep "^R:" /tmp/compile_split_$$.txt 2>/dev/null | wc -l)
OLD_COUNT=$(grep "^O:" /tmp/compile_split_$$.txt 2>/dev/null | wc -l)
echo "[compile] recent (24h): $RECENT_COUNT, old remaining: $OLD_COUNT"

# Take BATCH_SIZE oldest files sorted by modification date (newest first)
OLD_FILES=$(grep "^O:" /tmp/compile_split_$$.txt 2>/dev/null | sed "s/^O://" | \
  xargs -0 -I{} sh -c echo  {} | \
  sort -rn | head -n "$BATCH_SIZE" | awk {print })
OLD_BATCH_COUNT=$(echo "$OLD_FILES" | grep -c "." 2>/dev/null || echo 0)
rm -f /tmp/compile_split_$$.txt

echo "[compile] compiling: $RECENT_COUNT recent + $OLD_BATCH_COUNT old"
TOTAL=$((RECENT_COUNT + OLD_BATCH_COUNT))
[ "$TOTAL" -eq 0 ] && { echo "[compile] nothing to compile"; exit 0; }

# Compile recent files
if [ "$RECENT_COUNT" -gt 0 ]; then
  echo "[compile] recent files..."
  TMP=$(mktemp -d)
  grep "^R:" /tmp/compile_split_$$.txt 2>/dev/null | sed "s/^R://" | while IFS= read -r f; do
    [ -f "$f" ] && ln -sf "$(realpath "$f")" "$TMP/$(basename "$f")" 2>/dev/null
  done
  "$OPENKB" --kb-dir "$KB_DIR" add "$TMP" 2>&1 | tail -3
  rm -rf "$TMP"
fi

# Compile old batch (sorted by mtime, newest first)
if [ "$OLD_BATCH_COUNT" -gt 0 ]; then
  echo "[compile] old files (newest first)..."
  TMP=$(mktemp -d)
  echo "$OLD_FILES" | while IFS= read -r f; do
    [ -f "$f" ] && ln -sf "$(realpath "$f")" "$TMP/$(basename "$f")" 2>/dev/null
  done
  "$OPENKB" --kb-dir "$KB_DIR" add "$TMP" 2>&1 | tail -3
  rm -rf "$TMP"
fi

"$OPENKB" --kb-dir "$KB_DIR" lint 2>&1 | tail -3 || true

if [ -n "$(git status --porcelain)" ]; then
  git add wiki/ raw/
  git commit -m "wiki: compile ($RECENT_COUNT recent + $OLD_BATCH_COUNT old) $(date -u +%Y-%m-%d)" >/dev/null 2>&1 || true
  git pull --rebase >/dev/null 2>&1 || true
  git push >/dev/null 2>&1 || echo "[compile] push failed"
fi

SRC_NOW=$(ls wiki/sources/ 2>/dev/null | wc -l)
echo "[compile] done: $SRC_NOW wiki sources"
echo "[compile] end $(date -u +%FT%TZ)"

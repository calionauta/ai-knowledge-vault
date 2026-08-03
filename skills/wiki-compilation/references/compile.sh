#!/bin/bash
# compile.sh — run OpenKB incremental compilation over raw/ and sync the wiki.
#
# Usage: compile.sh [--commit]
#   default : compile + lint only
#   --commit: also git add/commit, pull --rebase, push (safe for scheduled runs)
#
# Env overrides:
#   KB_DIR   knowledge base root (default: ~/octarine-notes)
#   OPENKB   path to the openkb binary (default: ~/openkb-env/bin/openkb)
#
# Provider keys are loaded from $KB_DIR/.env (OPENAI_API_KEY / OPENAI_BASE_URL),
# which is gitignored and chmod 600.

set -uo pipefail

KB_DIR="${KB_DIR:-$HOME/octarine-notes}"
OPENKB="${OPENKB:-$HOME/openkb-env/bin/openkb}"
cd "$KB_DIR" || { echo "KB_DIR not found: $KB_DIR"; exit 1; }

if [ -f "$KB_DIR/.env" ]; then
  set -a; source "$KB_DIR/.env"; set +a
fi

echo "[compile] start $(date -u +%FT%TZ)"
"$OPENKB" --kb-dir "$KB_DIR" add raw/ || { echo "[compile] openkb add failed"; exit 1; }
"$OPENKB" --kb-dir "$KB_DIR" lint 2>&1 | tail -20 || true

if [ "${1:-}" = "--commit" ] && [ -n "$(git status --porcelain)" ]; then
  git add wiki/ raw/
  git commit -m "wiki: OpenKB compile $(date -u +%Y-%m-%d)" >/dev/null 2>&1 || true
  git pull --rebase >/dev/null 2>&1 || true
  git push >/dev/null 2>&1 || echo "[compile] push failed (transient?)"
fi

echo "[compile] done $(date -u +%FT%TZ)"

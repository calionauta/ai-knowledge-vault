#!/bin/bash
# auto-commit.sh — periodic git sync for the octarine-notes vault.
# Runs every 30 minutes. Adjust the cron schedule as needed.
#
# Install in crontab:
#   */30 * * * * /path/to/auto-commit.sh >> /path/to/auto-commit.log 2>&1

REPO_DIR="$(dirname "$0")"

cd "$REPO_DIR" || exit 1

if [[ -n $(git status --porcelain) ]]; then
    git add -A
    git commit -m "auto: sync $(date +'%Y-%m-%d %H:%M')"
    git pull --rebase >/dev/null 2>&1 || true
    git push origin main 2>&1 || echo "Push failed (might be transient)"
    echo "$(date): Changes committed and pushed."
else
    echo "$(date): Nothing to commit."
fi

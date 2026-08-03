#!/bin/bash
# sync.sh — pull the latest notes (raw/) and agent edits (wiki/research|articles) from origin.
#
# Usage: sync.sh
# Env override: KB_DIR (default: ~/octarine-notes)

set -uo pipefail
KB_DIR="${KB_DIR:-$HOME/octarine-notes}"
git -C "$KB_DIR" pull --rebase
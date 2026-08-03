---
name: notes-search
description: >
  Search, read, and write notes in the octarine-notes vault (plain Markdown on
  disk, git-versioned). All notes go into raw/Daily/YYYY-MM-DD.md with
  timestamped headings. CRITICAL: only report what commands return. Never
  fabricate data.
version: 2.0.0
intents:
  - search notes
  - find note
  - read note
  - write note
  - save note
  - daily notes
  - recent notes
  - what did I note
  - save url to daily note
allowed-tools:
  - exec
  - bash
---

# Notes Search Skill

## Vault layout

`VAULT=${VAULT:-$HOME/octarine-notes}` — a plain git repo, no external service.

- `raw/Daily/YYYY-MM-DD.md` — daily notes (`## HHhMM - Title` sections)
- `raw/` — other immutable source notes (topics, people, imports)
- `wiki/` — compiled pages (read for retrieval; never hand-edit)

## CRITICAL RULES

1. Notes go into `raw/Daily/YYYY-MM-DD.md`. NEVER save elsewhere.
2. NEVER modify existing `raw/` files. Only create today's daily or append to it.
3. Never fabricate data — only report what commands return.
4. Use plain filesystem tools (`printf`, `mkdir`, `cat`, `rg`); no external API.

## Daily note format

```
# YYYY-MM-DD

## 09h15 - Short Title
- Content point 1
- Content point 2
```

Time format `HHhMM` (Brazilian standard). No colons in headings.

## Save a note

```bash
DATE=$(TZ=America/Sao_Paulo date +%Y-%m-%d)
TIME=$(TZ=America/Sao_Paulo date +%Hh%M)
TITLE="Short title derived from content"
CONTENT="content"
FILE="$VAULT/raw/Daily/$DATE.md"
mkdir -p "$VAULT/raw/Daily"
if [ -f "$FILE" ]; then
  printf "\n## %s - %s\n- %s\n" "$TIME" "$TITLE" "$CONTENT" >> "$FILE"
else
  printf "# %s\n\n## %s - %s\n- %s\n" "$DATE" "$TIME" "$TITLE" "$CONTENT" > "$FILE"
fi
```

## Save from URL

1. Use `fetch_url` to get the page content.
2. Extract the page title and meta description.
3. Append to today's daily as `## HH:MM - [Page Title](url)` with a description line.
   Do NOT add the page's own headings.

## Search

```bash
rg -l -i "<query>" "$VAULT/raw" "$VAULT/wiki"        # full text
rg -i -l "<query>" "$VAULT/raw/Daily"                # daily notes
git -C "$VAULT" log --oneline --since="3 days ago"   # recent changes
```

For retrieval, prefer compiled pages: read `wiki/index.md`, then follow `[[wikilinks]]`.

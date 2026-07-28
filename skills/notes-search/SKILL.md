---
name: notes-search
description: >
  Search, read, and write notes in a KiwiFS markdown vault.
  All notes go into Daily files with timestamped headings.
  CRITICAL: Only report what commands return. Never fabricate data.
version: 1.0.0
intents:
  - search notes
  - find note
  - read note
  - write note
  - save note
  - daily notes
  - recent notes
  - what did I note
allowed-tools:
  - exec
  - bash
---

# Notes Search Skill

## CRITICAL RULES

1. ALL notes go into `raw/Daily/YYYY-MM-DD.md`. NEVER save elsewhere.
2. NEVER fabricate data. Only report what commands return.
3. Timezone: configure TZ environment variable per user location.
4. Use curl for KiwiFS API, never shell filesystem commands.

## Daily note format (MANDATORY)

All notes use `raw/Daily/YYYY-MM-DD.md` with this structure:

```
# YYYY-MM-DD

## 09h15 - Short Title
- Content point 1
- Content point 2
```

Time format: `HHhMM` (Brazilian standard, used in Portugal and France too).
No colons in headings — avoids parser bugs. Examples: `09h15`, `14h30`.

## How to save a note

```bash
DATE=$(TZ=$TIMEZONE date +%Y-%m-%d)
TIME=$(TZ=$TIMEZONE date +%Hh%M)
TITLE="Title derived from content"
FILE="raw/Daily/${DATE}.md"

CONTENT=$(printf "# %s\n\n## %s - %s\n- %s\n" "$DATE" "$TIME" "$TITLE" "content")
EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3333/api/kiwi/file?path=${FILE}")

if [ "$EXISTS" = "200" ]; then
  CONTENT=$(printf "\n## %s - %s\n- %s\n" "$TIME" "$TITLE" "content")
  curl -s -X POST "http://localhost:3333/api/kiwi/file/append?path=${FILE}" \
    -H "X-Actor: agent:mercury" --data-binary "$CONTENT"
else
  curl -s -X PUT "http://localhost:3333/api/kiwi/file?path=${FILE}" \
    -H "X-Actor: agent:mercury" --data-binary "$CONTENT"
fi
```

Use `--data-binary` NOT `-d` to preserve newlines.

## Search

Recent changes (last N days):
```bash
docker exec kiwifs git -C /data log --oneline --since="3 days ago" --name-only
```

Full-text search:
```bash
curl -s "http://localhost:3333/api/kiwi/search?q=<query>&limit=10"
```

Semantic search:
```bash
curl -s -X POST "http://localhost:3333/api/kiwi/search/semantic" -d "{\"query\":\"<query>\",\"limit\":5}"
```

Read specific file:
```bash
curl -s "http://localhost:3333/api/kiwi/file?path=<path>"
```

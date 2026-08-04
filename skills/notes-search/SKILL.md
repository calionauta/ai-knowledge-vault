---
name: notes-search
description: >
  Search, read, and write notes in the knowledge vault (plain Markdown on
  disk, git-versioned). Searches both raw/ and wiki/ using filesystem tools
  (fast, free). For synthesis questions, falls back to openkb query (LLM).
  All notes go into raw/Daily/YYYY-MM-DD.md with timestamped headings.
  CRITICAL: only report what commands return. Never fabricate data.
version: 3.0.0
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
  - search raw
  - search wiki
  - openkb query
  - synthesize
  - question about notes
allowed-tools:
  - exec
  - bash
---

# Notes Search Skill v3

## Vault layout

`VAULT=${VAULT:-$HOME/octarine-notes}` — plain git repo, no external service.

- `raw/Daily/YYYY-MM-DD.md` — daily notes (`## HHhMM - Title` sections)
- `raw/` — other immutable source notes (topics, people, imports)
- `wiki/` — compiled pages (read for retrieval; never hand-edit)

## CRITICAL RULES

1. Notes go into `raw/Daily/YYYY-MM-DD.md`. NEVER save elsewhere.
2. NEVER modify existing `raw/` files. Only create today's daily or append to it.
3. Never fabricate data — only report what commands return.
4. Use filesystem tools for search; `openkb query` only for synthesis.

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

## Search — two modes

### Mode 1: Filesystem search (fast, free)

Use when: searching for a term, name, topic, or keyword.

```bash
rg -l -i "<query>" "$VAULT/raw" "$VAULT/wiki"        # full text
rg -i -l "<query>" "$VAULT/raw/Daily"                # daily notes only
git -C "$VAULT" log --oneline --since="3 days ago"   # recent changes
```

For retrieval, prefer compiled pages: read `wiki/index.md`, then follow `[[wikilinks]]`.

### Mode 2: openkb query (synthesis, costs tokens)

Use when: user asks a question that needs synthesis across multiple sources.
Examples: "o que sei sobre X?", "como funciona Y?", "qual a relação entre A e B?"

```bash
cd "$VAULT" && source .env 2>/dev/null
~/openkb-env/bin/openkb --kb-dir "$VAULT" query "<question>"
```

### How to decide which mode

| Query pattern | Mode | Why |
|---------------|------|-----|
| Single term or name ("pricing", "Thiago") | Filesystem | Quick lookup, no cost |
| "buscar X", "procurar X" | Filesystem | Explicit search request |
| "o que sei sobre X", "como funciona Y" | openkb query | Needs synthesis |
| "qual a relação entre A e B" | openkb query | Cross-source analysis |
| "explique X", "resuma Y" | openkb query | LLM synthesis needed |
| Question mark (?) at end | openkb query | It's a question |

### Hybrid approach (recommended)

1. **Always start with filesystem search** (fast, free) in both `raw/` and `wiki/`
2. **If results are sufficient** → return them directly
3. **If results are sparse OR user asks a synthesis question** → fall back to `openkb query`
4. **Always tell the user** which mode was used

Example flow:
```
User: "o que sei sobre pricing strategies?"
  → rg "pricing" raw/ wiki/ → finds 12 files
  → "Encontrei 12 arquivos. Quer que eu use openkb query para síntese?"
  → User: "sim"
  → openkb query "pricing strategies" → synthesized answer
```

## openkb query reference

The `openkb query` command runs RAG over the compiled wiki using LLM.
It costs tokens but provides synthesized answers.

```bash
cd "$VAULT" && source .env 2>/dev/null
~/openkb-env/bin/openkb --kb-dir "$VAULT" query "<question>"
```

Prefer reading `wiki/index.md` + 1-2 concept pages directly over `openkb query`
when possible — cheaper, stays in context. Use `openkb query` only when no
obvious slug matches and a direct grep returns nothing useful.

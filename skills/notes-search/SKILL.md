---
name: notes-search
description: >
  Search, read, and write notes in the knowledge vault (plain Markdown on
  disk, git-versioned). Searches both raw/ and wiki/ using filesystem tools
  (fast, free). For synthesis questions, falls back to openkb query (LLM).
  All notes go into raw/Daily/YYYY-MM-DD.md with timestamped headings.
  CRITICAL: only report what commands return. Never fabricate data.
version: 3.1.0
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

# Notes Search Skill v3.1

## Vault layout

`VAULT=${VAULT:-$HOME/octarine-notes}` — plain git repo, no external service.

- `raw/Daily/YYYY-MM-DD.md` — daily notes (`## HHhMM - Title` sections)
- `raw/` — other immutable source notes (topics, people, imports)
- `wiki/` — compiled pages (read for retrieval; never hand-edit)

## CRITICAL RULES

1. Notes go into `raw/Daily/YYYY-MM-DD.md`. NEVER save elsewhere.
2. NEVER modify existing `raw/` files. Only create today's daily or append to it.
3. Never fabricate data — only report what commands return.
4. Always search first (filesystem), offer synthesis second (openkb query).

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

## Search — always filesystem first, synthesis optional

### Step 1: Filesystem search (always do this first)

```bash
rg -l -i "<query>" "$VAULT/raw" "$VAULT/wiki"        # full text
rg -i -l "<query>" "$VAULT/raw/Daily"                # daily notes only
git -C "$VAULT" log --oneline --since="3 days ago"   # recent changes
```

Return results to user. This is fast and free.

### Step 2: Offer synthesis (only if user asks)

After showing filesystem results, ask:
"Encontrei X resultados. Quer que eu sintetize com openkb query?"

Only use openkb query if:
- User explicitly asks for synthesis ("sintetize", "explique", "resuma")
- User confirms after seeing filesystem results
- User's original message was clearly a question needing cross-source analysis

### Step 3: openkb query (when user confirms)

```bash
cd "$VAULT" && source .env 2>/dev/null
~/openkb-env/bin/openkb --kb-dir "$VAULT" query "<question>"
```

### Decision flow

```
User message
  │
  ├─ Is it explicitly a synthesis request? ("sintetize", "explique", "resuma")
  │   └─ YES → openkb query directly
  │
  ├─ Is it a search term? ("buscar X", "procurar X", or just a keyword)
  │   └─ YES → filesystem search, show results, offer synthesis
  │
  └─ Unclear?
      └─ Start with filesystem, then offer synthesis
```

## Search capabilities

| Method | What it searches | Semantic? | Cost |
|--------|-----------------|-----------|------|
| `rg` (ripgrep) | Text/lexical match in raw/ + wiki/ | No — keyword only | Free |
| `openkb query` | Compiled wiki via LLM + PageIndex | Reasoning-based (not embeddings) | Tokens |
| OpenKnowledge semantic (future) | Embeddings over wiki/ | Yes — true semantic | Local model or API |

**Current state:** no true semantic search. `openkb query` is the closest (LLM reasoning
over PageIndex), but it's not embeddings-based. For true semantic search, would need
Ollama with embeddings model or OpenAI embeddings API.

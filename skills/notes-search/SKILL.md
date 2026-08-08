---
name: notes-search
description: >
  Search, read, and write notes in the knowledge vault (plain Markdown on
  disk, git-versioned). Searches both raw/ and wiki/ using filesystem tools
  (fast, free). For synthesis questions, falls back to openkb query (LLM).
  All notes go into raw/Daily/YYYY-MM-DD.md with timestamped headings.
  CRITICAL: only report what commands return. Never fabricate data.
version: 3.4.0
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

# Notes Search Skill v3.4

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

### Format for URL/link annotations (CRITICAL — do not invert)

When saving a URL/link, the structure is three levels, in this exact order:

1. **Tags** on the parent bullet (first line).
2. **Link with title** indented below the tags — the title is the page title
   obtained from the URL (`fetch_url`), used as the link text:
   `[Page Title](url)`.
3. **Description** indented one MORE level below the link (a bulletpoint under
   the URL, NOT on the same level as the URL).

```
- [[raw/Topics/Tools]] [[raw/Topics/OpenSource]]
  - [Cloudflare OS](https://os.cloudflare.app/)
    - Cloudflare OS is the open source AI operating system companies can shape around...
- [[raw/Topics/Tools]]
  - [Drafted - Design your dream house plan with AI](https://drafted.ai/)
    - Generate floor plans, 3D models, renders, and professional CAD/BIM exports. $16M funding.
```

Rules:
- Title comes from the URL/page title (`fetch_url`), never invented.
- The description is a child bullet of the link — always one indentation level
  deeper than the URL line.
- NEVER put description on the same line/level as the URL.
- **Tool tags:** when the user indicates the URL is a Tool, ALWAYS use
  `[[raw/Topics/Tools]]` as a tag. If the tool is open source, ALWAYS add
  `[[raw/Topics/OpenSource]]` as well, both on the same parent bullet
  (e.g. `- [[raw/Topics/Tools]] [[raw/Topics/OpenSource]]`). Apply automatically
  whenever the user says "tool" / "opensource" — do not ask.

### Existing URL check (ALWAYS before annotating)

For EVERY URL the user asks to annotate, first search the vault for it:

```bash
rg -l -F "<url>" "$VAULT/raw" "$VAULT/wiki"
```

- **Not found** → proceed with the normal flow (fetch_url → append to today's daily).
- **Found** → do NOT annotate immediately. Stop and confirm with the user, per URL:
  1. **Duplicar (D)** — annotate again anyway (e.g. in today's daily as requested).
  2. **Mover (M)** — move the existing annotation to the daily note the user is
     requesting (delete from the old location, add to the new one).
  3. **Enriquecer (E)** — keep it where it is; update that existing annotation
     with the new title/description from `fetch_url` (as the skill already does).
  4. **Ignorar (I)** — leave as is, skip this URL.

> M and E modify an existing `raw/` file (exception to CRITICAL RULE #2) — only
> execute them when the user explicitly chooses that option.

For multiple URLs, present one compact numbered list so the user can answer
easily, one letter per URL:

```
1. https://exemplo.com/foo — já anotada em 2026-08-05 → D/M/E/I
2. https://exemplo.com/bar — já anotada em 2026-08-06 → D/M/E/I
```

The user replies like `1E 2M` (or "1 enriquecer, 2 mover") and you act on each.

### Steps

1. Search for the URL in the vault (see "Existing URL check" above).
2. Use `fetch_url` to get the page content.
3. Extract the page title (used as the link text) and meta description.
4. Append to today's daily as tags → link → description (three-level format above).
   Do NOT add the page's own headings.

## Tags (user convention)

When the user asks to "tag" a note (or mentions tagging, tag name, etc.), a tag is a
**wiki-link mention to a Topics page**, NOT a free-form word:

- Single level: `[[raw/Topics/tag-exemplo]]`
- Nested levels: `[[raw/Topics/nivel-1/nivel-2]]` (levels separated by `/`)
- The braces in `{...}` above are placeholders only — never write literal braces.

### Format in daily notes

Use the tag as its own bullet, with the annotation indented below it:

```
- [[raw/Topics/tag-exemplo]]
    - anotação
```

Multiple annotations under one tag keep the same indented level. A note can have
multiple tag bullets. Never mix the tag and the annotation on the same line
(keeps the tag line a pure link, easy to parse/audit).

### Naming convention: kebab-case lowercase

- Tag file names use **kebab-case lowercase** (`ai-native`, `machine-learning`,
  `long-term-memory`). NO camelCase (breaks on acronyms: `aiNative` vs `AInative`
  is ambiguous and caused the `ai` vs `AI-native` duplicate).
- Proper nouns already established keep their exact existing name
  (`Region`, `Brasil`) — single words, no variation risk.
- Directory levels also kebab-case lowercase unless they are existing proper nouns.

Rules:

1. **Reuse existing Topics.** Before creating a new Topics file, search
   `$VAULT/raw/Topics/` for an existing name with the same meaning, tolerating
   variation in:
   - plural/singular (e.g. `argument` vs `arguing`, `assumption` vs `assumptions`)
   - gender (e.g. `Adulto` vs `Adulti`)
   - capitalization/formatting (`ai` vs `AI-native`, `AIGemini`)
   If an existing Topics page covers the same concept, use its exact path in the
   mention. Only create a new Topics file when no existing one matches.
2. Nested tags use existing subdirectory structure when present
   (e.g. `Topics/Region/Brasil` already exists — use it instead of creating
   `Topics/Brasil`).
3. When a tag is used in a daily note, the mention links to the Topics page;
   the Topics file itself is created in `raw/Topics/` (do not create it inside
   `raw/Daily/`).

### Canonical names (dedup audit, 2026-08-07)

Plural losers deleted, singular winners canonical: `assumption`, `emotion`,
`experiment`, `psychedelic`, `reason` (NOT `assumptions`, `emotions`,
`experiments`, `psychedelics`, `reasons`). Also canonical: `arguments` (not
`arguing`), `adulto` (not `Adulti`), `ai` (not `AI-native`). When tagging,
always use these exact names.

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

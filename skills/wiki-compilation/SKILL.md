---
name: wiki-compilation
description: >
  Compile raw notes into a structured wiki layer.
  Reads sources, extracts entities and concepts, detects contradictions,
  maintains index, overview, and log. Tracks compilation via merged-from
  frontmatter so KiwiFS memory reports show coverage.
  Follows the LLM Wiki Agent pattern.
version: 3.0.0
intents:
  - compile wiki
  - ingest notes
  - recompile changed notes
  - update wiki
  - extract entities
  - detect contradictions
  - run lint
  - check coverage
allowed-tools:
  - exec
  - bash
---

# Wiki Compilation Skill

## Path resolution

Scripts live alongside this SKILL.md in the `references/` subdirectory.

The `SKILL_DIR` variable auto-detects where scripts are, with fallbacks:
1. Mercury-managed path: `${MERCURY_INSTALL:-$HOME/.mercury}/skills/wiki-compilation/`
2. Git repo path (common dev setups): `$HOME/Development/ai-knowledge-vault/skills/wiki-compilation/`
3. Current directory's parent

```bash
# Auto-detect skill directory
if [ -d "${MERCURY_INSTALL:-$HOME/.mercury}/skills/wiki-compilation/references" ]; then
  SKILL_DIR="${MERCURY_INSTALL:-$HOME/.mercury}/skills/wiki-compilation"
elif [ -d "$HOME/Development/ai-knowledge-vault/skills/wiki-compilation/references" ]; then
  SKILL_DIR="$HOME/Development/ai-knowledge-vault/skills/wiki-compilation"
else
  # Fallback: assume scripts are next to this SKILL.md
  SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")/.." 2>/dev/null && pwd)/wiki-compilation"
fi
```

**Setup:** Copy the `references/` folder to the Mercury skill directory:
```bash
# From the repo, after cloning:
mkdir -p ~/.mercury/skills/wiki-compilation
cp -r skills/wiki-compilation/references ~/.mercury/skills/wiki-compilation/
```

All deterministic operations (finding files, writing pages, checking coverage,
detecting changes, linting) are delegated to these scripts. The LLM focuses on
what it does best: extracting meaning, structuring knowledge, and detecting
contradictions.

Scripts available in `$SKILL_DIR/references/`:

| Script | Purpose | Used in |
|--------|---------|---------|
| `find-unmerged.sh` | List raw files needing compilation | Ingest Step 1 |
| `write-page.sh` | Write a wiki page via KiwiFS API | Ingest Step 3 |
| `update-meta.sh` | Rebuild index, append to log | Ingest Step 4 |
| `check-coverage.sh` | Print memory report summary | Ingest Step 5, Coverage check |
| `detect-changes.sh` | Find raw files with changed content | Recompile |
| `lint.sh` | Check orphan pages, missing metadata | Lint |

## CRITICAL RULES

1. NEVER modify files in `raw/`. Read only.
2. Wiki pages can be created/updated. Source pages are append-only by default — updates are allowed only during explicit recompilation (detect-changes.sh found a checksum mismatch).
3. Flag contradictions. Never silently resolve them.
4. Update index.md on every change via `$SKILL_DIR/references/update-meta.sh --rebuild-index`.
5. **Every wiki page MUST include `merged-from`** in frontmatter — this is how KiwiFS tracks coverage in the memory report.
6. **Before creating a source page, run `find-unmerged.sh` to check if one already exists.**
7. Every wiki page you write must ALSO be registered via `update-meta.sh --log "<entry>"`.

## Context

The vault has two top-level directories:

- `raw/` — source notes (immutable, human-written)
- `wiki/` — compiled knowledge (agent-maintained)

### Wiki structure

```
wiki/
  index.md       — Catalog of all pages
  log.md         — Append-only chronological record
  overview.md    — Living synthesis across sources
  sources/       — One summary per source document
  entities/      — People, companies, projects, products
  concepts/      — Ideas, frameworks, methods
  syntheses/     — Saved query answers
```

### How compilation tracking works

KiwiFS provides two mechanisms for tracking what has been compiled:

**A) `merged-from` frontmatter** — each wiki page lists which raw files were used:
```yaml
merged-from:
  - type: episode
    id: raw/Daily/2026-07-28.md
```

**B) Memory report API** — shows how many raw files have been merged:
```bash
bash $SKILL_DIR/references/check-coverage.sh
```

**C) Source page existence** — if `wiki/sources/<slug>.md` exists, the raw file has been compiled at least once. But this alone doesn't update the memory report — `merged-from` is required.

### Page frontmatter

**Source page** — stores the SHA256 checksum of the raw file for change detection:
```yaml
---
title: "Source Title"
type: source
tags: []
date: YYYY-MM-DD
source_file: raw/...
last_updated: YYYY-MM-DD
source_checksum: sha256-abc123...
merged-from:
  - type: episode
    id: raw/path/to/file.md
---
```

**Entity / Concept / Synthesis page:**
```yaml
---
title: "Page Name"
type: entity | concept | synthesis
tags: []
sources: [source-slug]
last_updated: YYYY-MM-DD
merged-from:
  - type: episode
    id: raw/path/to/file.md
---
```

> `merged-from` lists one or more raw files that were used to create/update this page.
> KiwiFS reads this field to calculate `coverage_pct` in the memory report.
> Sources can be shared across multiple entity/concept pages — each must list its own `merged-from`.
>
> `source_checksum` is the SHA256 hash of the raw file content at compile time.
> On subsequent runs, the skill re-hashes and compares — if different, the note was edited and needs recompilation.
> This is more reliable than timestamps because it detects actual content changes, not file saves or touches.

## Workflow: Ingest (incremental)

Run daily (scheduled at 2 AM) or on demand.

### Step 1 — Find what needs compilation

```bash
bash $SKILL_DIR/references/find-unmerged.sh --limit 10 --json
```

Returns JSON lines like:
```json
{"path":"raw/Daily/2026-07-28.md","slug":"daily-2026-07-28","checksum":"abc123..."}
```

For each returned file, the file is **new** (no wiki source exists yet).

**Why SHA256 instead of timestamps?** KiwiFS stores files as content-addressed blobs — there is no git history inside the container. A content checksum is deterministic and portable: it catches actual edits and ignores false positives from file saves or touches.

### Step 2 — Compile each file

For each file returned by `find-unmerged.sh`:

a. Read the raw note:
   ```bash
   curl -s "http://localhost:3333/api/kiwi/file?path=<raw_path>"
   ```

b. LLM extracts from the content:
   - **Summary** → `wiki/sources/<slug>.md`
   - **Entities** → `wiki/entities/<Name>.md` (create or update)
   - **Concepts** → `wiki/concepts/<Name>.md` (create or update)
   - **Contradictions** with existing wiki content (read existing pages via curl first)
   - **Overview revision** → only if the changes affect the overall synthesis

c. Every wiki page written MUST include:
   ```yaml
   merged-from:
     - type: episode
       id: <raw_path>
   ```

   Source pages MUST also include:
   ```yaml
   source_checksum: sha256-<hash_of_raw_content>
   ```

### Step 3 — Write pages

Use the write-page script — it handles X-Actor header and error checking:

```bash
bash $SKILL_DIR/references/write-page.sh "wiki/sources/${SLUG}.md" "<full markdown content>"
bash $SKILL_DIR/references/write-page.sh "wiki/entities/${NAME}.md" "<entity content>"
bash $SKILL_DIR/references/write-page.sh "wiki/concepts/${NAME}.md" "<concept content>"
```

### Step 4 — Update index and log

```bash
# Rebuild index (reads all wiki files via API)
bash $SKILL_DIR/references/update-meta.sh --rebuild-index

# Append to log
bash $SKILL_DIR/references/update-meta.sh --log "## [YYYY-MM-DD] ingest | <Title> | merged-from: <raw_path> | checksum: sha256-<hash>\n"
```

### Step 5 — Check memory coverage

After each batch, verify the memory report:

```bash
bash $SKILL_DIR/references/check-coverage.sh
```

Target output:
```
Coverage: 1%
Merged refs: 10
Episodic files: 3771
```

> **Target:** After each batch, `coverage_pct` should increase. After a full first-time compilation, it should approach 100%.
> If it stays at 0%, check that `merged-from` was written correctly in the frontmatter
> and that the memory report uses the same `episodes_prefix` (must be `raw/`).

### Source page format

```markdown
---
title: "Source Title"
type: source
tags: []
date: YYYY-MM-DD
source_file: raw/...
last_updated: YYYY-MM-DD
source_checksum: sha256-<hash>
merged-from:
  - type: episode
    id: raw/path/to/file.md
---

## Summary
2-4 sentence summary.

## Key Claims
- Claim 1
- Claim 2

## Key Quotes
> "Quote" — context

## Connections
- [[EntityName]] — relation
- [[ConceptName]] — relation

## Contradictions
- Contradicts [[OtherPage]] on: ...
```

### Entity page format

```markdown
---
title: "Entity Name"
type: entity
tags: []
sources: [slug1]
last_updated: YYYY-MM-DD
merged-from:
  - type: episode
    id: raw/path/to/file.md
---

## Summary
Brief description.

## Role / Context
How this entity appears across sources.

## Relationships
- [[RelatedEntity]] — relationship
- [[ConceptName]] — how they connect
```

### Concept page format

```markdown
---
title: "Concept Name"
type: concept
tags: []
sources: [slug1]
last_updated: YYYY-MM-DD
merged-from:
  - type: episode
    id: raw/path/to/file.md
---

## Summary
Definition and key idea.

## Key Points
- Point 1
- Point 2

## Related
- [[EntityName]]
- [[RelatedConcept]]
```

## Workflow: Recompile changed notes

When a raw file is edited, its content changes → the SHA256 checksum differs → the skill detects it automatically.

```bash
bash $SKILL_DIR/references/detect-changes.sh
```

Returns lines like:
```
CHANGED: raw/Daily/2026-07-28.md (sha256: abc123... → def456...)
```

For each changed file:

1. Read the updated raw file: `curl -s "http://localhost:3333/api/kiwi/file?path=<raw_path>"`
2. Re-extract entities, concepts, and update the summary via LLM
3. **Update** existing wiki pages (don't create duplicates) — use `write-page.sh` on the same path
4. Update `last_updated` and `source_checksum` in frontmatter
5. Keep the same `merged-from` entries (add new ones if the raw file spawned new entities/concepts)
6. Update `wiki/overview.md` if the changes affect it
7. Log the recompilation: `bash $SKILL_DIR/references/update-meta.sh --log "## [YYYY-MM-DD] recompile | <Title> | checksum: sha256-<hash>\n"`

## Workflow: Lint

Run weekly.

```bash
bash $SKILL_DIR/references/lint.sh
```

Checks performed:
1. **Orphan sources** — source pages whose `source_file` no longer exists in raw/
2. **Missing source_checksum** — source pages without a checksum (legacy data)
3. **Missing merged-from** — wiki pages without `merged-from` in frontmatter

Additionally, flag stale pages (not updated in 30+ days) by checking `last_updated` dates.

Report findings — do not auto-fix without confirmation.

## Workflow: Query

When the user asks a question about the notes:

1. Search the wiki:
   ```bash
   curl -s "http://localhost:3333/api/kiwi/search?q=<query>&limit=10"
   curl -s -X POST "http://localhost:3333/api/kiwi/search/semantic" -d "{\"query\":\"<query>\",\"limit\":5}"
   ```

2. Read relevant wiki pages — note their `merged-from` to show provenance.

3. Synthesize answer with `[[PageName]]` citations and mention which raw sources were used.

4. Ask user if they want the answer saved as `wiki/syntheses/<slug>.md`. All such pages MUST include `merged-from` in frontmatter.

All read operations (search, file reads) don't need special headers. Only writes need `X-Actor: agent:mercury` (the write-page.sh script handles this automatically).

## Workflow: Check coverage

Run this to verify compilation completeness:

```bash
bash $SKILL_DIR/references/check-coverage.sh
```

**Interpreting results:**

| Coverage | Meaning |
|----------|---------|
| 0% | No `merged-from` entries found in wiki pages |
| 1-99% | Partial — some files still need compilation |
| 100% | All raw files have been merged into wiki pages |

## Batch ingestion (first-time compilation)

For an existing vault with many notes (3,771+ files):

1. Run `find-unmerged.sh` in a loop, processing one batch per execution:
   ```bash
   # Each run finds the next 10 unmerged files
   bash $SKILL_DIR/references/find-unmerged.sh --limit 10 --json
   ```

2. For each batch of 10:
   - Process each file through Steps 2-4 (compile via LLM, write pages, update meta)
   - Run lint after every 50 sources: `bash $SKILL_DIR/references/lint.sh`
   - **Verify coverage** after each batch: `bash $SKILL_DIR/references/check-coverage.sh`

3. Full compilation may take multiple sessions (~378 batches for 3,771 files at 10/batch).
   Resume by re-running `find-unmerged.sh` — it automatically skips already-compiled files.

## Daily ingestion schedule (10 notes/day)

For ongoing maintenance, process a small batch daily:

```bash
# Run by the scheduled prompt at 2 AM
bash $SKILL_DIR/references/find-unmerged.sh --limit 10 --json
```

Then process the results through Steps 2-4.

The `find-unmerged.sh` script uses the KiwiFS memory report API to find files
that lack a `wiki/sources/<slug>.md` page. It always picks files in the order
returned by the API, so each run progresses through the unmerged list.

Over time, as files are compiled and `merged-from` is written, the memory report's
`coverage_pct` rises and the number of unmerged files shrinks.

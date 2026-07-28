---
name: wiki-compilation
description: >
  Compile raw notes into a structured wiki layer.
  Reads sources, extracts entities and concepts, detects contradictions,
  maintains index, overview, and log. Tracks compilation via merged-from
  frontmatter so KiwiFS memory reports show coverage.
  Follows the LLM Wiki Agent pattern.
version: 2.0.0
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
schedule: "0 2 * * *"
---

# Wiki Compilation Skill

## CRITICAL RULES

1. NEVER modify files in `raw/`. Read only.
2. Wiki pages can be created/updated. Source pages are append-only.
3. Flag contradictions. Never silently resolve them.
4. Update index.md on every change.
5. **Every wiki page MUST include `merged-from`** in frontmatter — this is how KiwiFS tracks coverage in the memory report.
6. **Before creating a source page, check if one already exists.** If the raw file is newer than `last_updated`, recompile.

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
curl -s "http://localhost:3333/api/kiwi/memory/report?episodes_prefix=raw/"
```
Returns `coverage_pct` — target is 100%.

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
# Option A: Recently changed files (daily routine)
curl -s "http://localhost:3333/api/kiwi/changes?since=24h&limit=50"

# Option B: Unmerged files from memory report (for coverage tracking)
curl -s "http://localhost:3333/api/kiwi/memory/report?episodes_prefix=raw/&limit=50"
```

For each file returned, determine whether to compile or skip:

```bash
# Derive slug from the raw file path
# Example: raw/Daily/2026-07-28.md → daily-2026-07-28
# Example: raw/Topics/ProjectManagement.md → topics-project-management
# Rule: lowercase, replace / and spaces with -, remove extension and special chars
SLUG=$(echo "$RAW_PATH" | sed 's|^raw/||' | sed 's|\.md$||' | tr ' /' '-' | tr '[:upper:]' '[:lower:]')

SOURCE_PATH="wiki/sources/${SLUG}.md"

# Read the raw file content
RAW_CONTENT=$(curl -s "http://localhost:3333/api/kiwi/file?path=${RAW_PATH}")

# Compute SHA256 checksum of raw content
# Using sha256sum which is available in the kiwifs container
RAW_CHECKSUM=$(printf '%s' "$RAW_CONTENT" | sha256sum | cut -d' ' -f1)

# Check if a wiki source already exists
EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3333/api/kiwi/file?path=${SOURCE_PATH}")

if [ "$EXISTS" = "200" ]; then
  # Read the existing source page's checksum from frontmatter
  EXISTING_CHECKSUM=$(curl -s "http://localhost:3333/api/kiwi/file?path=${SOURCE_PATH}" | grep "source_checksum:" | sed 's/.*source_checksum: *sha256-//')

  if [ "$RAW_CHECKSUM" = "$EXISTING_CHECKSUM" ] && [ -n "$EXISTING_CHECKSUM" ]; then
    echo "ALREADY_COMPILED=true (checksum match: $RAW_CHECKSUM)"
  else
    echo "REQUIRES_RECOMPILE=true (old: $EXISTING_CHECKSUM, new: $RAW_CHECKSUM)"
  fi
else
  echo "NEW_FILE=true (no existing source page)"
fi
```

> **Why SHA256 instead of timestamps?** KiwiFS stores files as content-addressed blobs — there is no git history inside the container. The file's modification time from the API is the container's internal clock, not the original write time. A content checksum is **deterministic and portable**: it catches actual edits and ignores false positives from file saves or touches.

### Step 2 — Compile each file

Only process files that are:
- **New** (no wiki/sources/<slug>.md exists)
- **Changed** (SHA256 checksum differs from stored `source_checksum`)

For each file to compile:

a. Read the raw note:
   ```bash
   curl -s "http://localhost:3333/api/kiwi/file?path=<raw_path>"
   ```

b. LLM extracts:
   - Summary → `wiki/sources/<slug>.md`
   - Entities → `wiki/entities/<Name>.md` (create or update)
   - Concepts → `wiki/concepts/<Name>.md` (create or update)
   - Contradictions with existing wiki content
   - Overview revision → `wiki/overview.md`

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

All write operations MUST use the `X-Actor: agent:mercury` header:

```bash
curl -s -X PUT "http://localhost:3333/api/kiwi/file?path=${SOURCE_PATH}" \
  -H "X-Actor: agent:mercury" -d "<content with merged-from + source_checksum>"
```

### Step 4 — Update index and log

```bash
# Update index
curl -s -X PUT "http://localhost:3333/api/kiwi/file?path=wiki/index.md" \
  -H "X-Actor: agent:mercury" -d "<updated index>"

# Append to log (POST /file/append is confirmed available — returns 200)
curl -s -X POST "http://localhost:3333/api/kiwi/file/append?path=wiki/log.md" \
  -H "X-Actor: agent:mercury" \
  -d "## [YYYY-MM-DD] ingest | <Title> | merged-from: <raw_path> | checksum: sha256-<hash>\n"
```

### Step 5 — Check memory coverage

After each batch, verify the memory report using Python (more reliable than grep for JSON/text responses):

```bash
curl -s "http://localhost:3333/api/kiwi/memory/report?episodes_prefix=raw/" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"Coverage: {data.get('coverage_pct', '?')}%\")
print(f\"Merged refs: {data.get('merged_from_refs', '?')}\")
print(f\"Episodic files: {data.get('episodic_count', data.get('total_episodic', '?'))}\")
"
```

> **Target:** After a full first-time compilation, `coverage_pct` should approach 100%.
> If it stays at 0%, check that `merged-from` was written correctly in the frontmatter
> and that the memory report uses the same `episodes_prefix` (must be `raw/`).
>
> **Note:** The API may return either JSON or formatted text depending on the KiwiFS version.
> The Python approach works with JSON; if the response is plain text, parse field values directly
> (e.g., `grep 'Coverage:' | grep -oP '\d+'`).

### Source page format

```markdown
---
title: "Source Title"
type: source
tags: []
date: YYYY-MM-DD
source_file: raw/...
last_updated: YYYY-MM-DD
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

When a raw file is edited, its content changes → the SHA256 checksum differs → the skill detects it automatically during the next ingest cycle.

### Detection mechanism

The recompilation check is built into Step 1 of the ingest workflow (see above).

```bash
# For every wiki source file, compare stored checksum with current raw content
for SRC_FILE in $(curl -s "http://localhost:3333/api/kiwi/tree?path=wiki/sources/" | jq -r '.[].path'); do
  SRC_CONTENT=$(curl -s "http://localhost:3333/api/kiwi/file?path=$SRC_FILE")
  RAW_FILE=$(echo "$SRC_CONTENT" | grep "source_file:" | sed 's/.*source_file: *//')
  EXISTING_CHECKSUM=$(echo "$SRC_CONTENT" | grep "source_checksum:" | sed 's/.*source_checksum: *sha256-//')

  # Read raw file and compute current checksum
  RAW_CONTENT=$(curl -s "http://localhost:3333/api/kiwi/file?path=${RAW_FILE}")
  CURRENT_CHECKSUM=$(printf '%s' "$RAW_CONTENT" | sha256sum | cut -d' ' -f1)

  if [ "$CURRENT_CHECKSUM" != "$EXISTING_CHECKSUM" ]; then
    echo "RECOMPILE: $RAW_FILE (checksum mismatch)"
  fi
done
```

> **Why not timestamps?** KiwiFS does not expose file modification timestamps via its API,
> and the underlying storage is content-addressed, not a git repository. A SHA256 checksum
> is deterministic: the same content always produces the same hash, so false positives
> (file touched but content unchanged) are impossible.

### Recompile process

For each file flagged for recompilation:

1. Read the updated raw file: `curl -s "http://localhost:3333/api/kiwi/file?path=<raw_path>"`
2. Re-extract entities, concepts, and update the summary via LLM
3. **Update** existing wiki pages (don't create duplicates) — use `PUT` on the same path
4. Update `last_updated` and `source_checksum` in frontmatter
5. Keep the same `merged-from` entries (add new ones if the raw file spawned new entities/concepts)
6. Update `wiki/overview.md` if the changes affect it
7. Log the recompilation in `wiki/log.md`

All writes MUST use `-H "X-Actor: agent:mercury"`:

```bash
curl -s -X PUT "http://localhost:3333/api/kiwi/file?path=wiki/sources/${SLUG}.md" \
  -H "X-Actor: agent:mercury" -d "<updated content>"

curl -s -X POST "http://localhost:3333/api/kiwi/file/append?path=wiki/log.md" \
  -H "X-Actor: agent:mercury" \
  -d "## [YYYY-MM-DD] recompile | <Title> | checksum: sha256-<hash>\n"
```

## Workflow: Lint

Run weekly.

1. Check for orphan pages, broken links, contradictions:
   ```bash
   curl -s "http://localhost:3333/api/kiwi/janitor"
   ```

2. Flag stale pages (not updated in 30+ days).

3. Cross-check with memory report — files that have `merged-from` but no corresponding `wiki/sources/<slug>.md` should be flagged as broken.

4. Cross-check `source_checksum` values — if a source page has a checksum but the raw file content hash differs, flag it for recompilation.

5. Report findings — do not auto-fix without confirmation.

## Workflow: Query

When the user asks a question about the notes:

1. Search the wiki:
   ```bash
   curl -s "http://localhost:3333/api/kiwi/search?q=<query>&limit=10"
   curl -s -X POST "http://localhost:3333/api/kiwi/search/semantic" \
     -d "{\"query\":\"<query>\",\"limit\":5}"
   ```

2. Read relevant wiki pages — note their `merged-from` to show provenance.

3. Synthesize answer with `[[PageName]]` citations and mention which raw sources were used.

4. Ask user if they want the answer saved as `wiki/syntheses/<slug>.md`. All such pages MUST include `merged-from` in frontmatter.

All read operations (search, file reads) don't need special headers. Only writes need `-H "X-Actor: agent:mercury"`.

## Workflow: Check coverage

Run this to verify compilation completeness:

```bash
REPORT=$(curl -s "http://localhost:3333/api/kiwi/memory/report?episodes_prefix=raw/")
echo "$REPORT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"Episodic files: {data['episodic_count']}\")
print(f\"Total unmerged: {data['total_unmerged']}\")
print(f\"Merged refs: {data['merged_from_refs']}\")
print(f\"Coverage: {data['coverage_pct']}%\")
print(f\"Contradictions: {data['contradictions']}\")
print(f\"Avg age: {data['avg_age_days']:.1f} days\")
"
```

**Interpreting results:**

| Coverage | Meaning |
|----------|---------|
| 0% | No `merged-from` entries found in wiki pages |
| 1-99% | Partial — some files still need compilation |
| 100% | All raw files have been merged into wiki pages |

## First-time compilation

For an existing vault with many notes (3,771+ files):

1. Get the full list of unprocessed files from memory report:
   ```bash
   curl -s "http://localhost:3333/api/kiwi/memory/report?episodes_prefix=raw/&limit=3771"
   ```

2. Process in **batches of 10**. For each batch:
   - Check which files already have `wiki/sources/<slug>.md`
   - Compile only the new ones
   - Add `merged-from` to every page written

3. Run lint after every 50 sources.

4. **Verify coverage after each batch:**
   ```bash
   curl -s "http://localhost:3333/api/kiwi/memory/report?episodes_prefix=raw/" | grep coverage_pct
   ```

5. Full compilation may take multiple sessions. Resume by re-running the coverage check and processing only files below the last batch.

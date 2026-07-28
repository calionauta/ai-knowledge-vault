---
name: wiki-compilation
description: >
  Compile raw notes into a structured wiki layer.
  Reads sources, extracts entities and concepts, detects contradictions,
  maintains index, overview, and log.
  Follows the LLM Wiki Agent pattern.
version: 1.0.0
intents:
  - compile wiki
  - ingest notes
  - update wiki
  - extract entities
  - detect contradictions
  - run lint
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

### Page frontmatter

```yaml
---
title: "Page Title"
type: source | entity | concept | synthesis
tags: []
sources: []
last_updated: YYYY-MM-DD
---
```

## Workflow: Ingest

Run this on schedule or on demand.

1. Find new/changed sources in `raw/`:
   ```bash
   curl -s "http://localhost:3333/api/kiwi/changes?since=24h&limit=50"
   ```

2. For each new file:
   a. Read via curl:
      ```bash
      curl -s "http://localhost:3333/api/kiwi/file?path=<path>"
      ```
   b. LLM extracts:
      - Summary → `wiki/sources/<slug>.md`
      - Entities → `wiki/entities/<Name>.md` (create or update)
      - Concepts → `wiki/concepts/<Name>.md` (create or update)
      - Contradictions with existing wiki content
      - Overview revision → `wiki/overview.md`

3. Write each page:
   ```bash
   curl -s -X PUT "http://localhost:3333/api/kiwi/file?path=<path>" \
     -H "X-Actor: agent:mercury" -d "<content>"
   ```

4. Update `wiki/index.md`:
   ```bash
   curl -s -X PUT "http://localhost:3333/api/kiwi/file?path=wiki/index.md" \
     -H "X-Actor: agent:mercury" -d "<updated index>"
   ```

5. Append to `wiki/log.md`:
   ```bash
   curl -s -X POST "http://localhost:3333/api/kiwi/file/append?path=wiki/log.md" \
     -H "X-Actor: agent:mercury" -d "## [YYYY-MM-DD] ingest | <Title>\n"
   ```

### Source page format

```markdown
---
title: "Source Title"
type: source
tags: []
date: YYYY-MM-DD
source_file: raw/...
last_updated: YYYY-MM-DD
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

## Workflow: Lint

Run weekly.

1. Check for orphan pages, broken links, contradictions:
   ```bash
   curl -s "http://localhost:3333/api/kiwi/janitor"
   ```

2. Flag stale pages (not updated in 30+ days).

3. Report findings — do not auto-fix without confirmation.

## Workflow: Query

When the user asks a question about the notes:

1. Search the wiki:
   ```bash
   curl -s "http://localhost:3333/api/kiwi/search?q=<query>&limit=10"
   curl -s -X POST "http://localhost:3333/api/kiwi/search/semantic" \
     -d "{\"query\":\"<query>\",\"limit\":5}"
   ```

2. Read relevant wiki pages.

3. Synthesize answer with `[[PageName]]` citations.

4. Ask user if they want the answer saved as `wiki/syntheses/<slug>.md`.

## First-time compilation

For an existing vault with many notes:

1. Process in batches of ~10 sources
2. Identify affected pages first — do not update blindly
3. Run lint after every 50 sources
4. Full compilation may take multiple sessions

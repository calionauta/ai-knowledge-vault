# Schema — Notes Vault

## Directory Structure

```
vault/
├── purpose.md          # Why the vault exists (directional intent)
├── schema.md           # This file — structural rules
├── AGENTS.md           # Agent instructions
├── README.md           # Human instructions
│
├── raw/                # IMMUTABLE source documents (humans only)
│   ├── Daily/          # YYYY-MM-DD.md — one file per day
│   ├── Topics/         # Reference topics [[Topics/name]]
│   ├── People/         # People profiles
│   ├── Projects/       # Project documentation
│   └── any/            # Any additional categories
│
└── wiki/               # COMPILED knowledge (agent maintains)
    ├── index.md        # Page catalog
    ├── log.md          # Append-only chronological record
    ├── overview.md     # Living synthesis across sources
    ├── drafts/         # Provisional research (status: provisional)
    ├── curated/        # Canonical articles (status: canonical)
    ├── sources/        # Source summaries
    ├── entities/       # People, companies, products (TitleCase.md)
    ├── concepts/       # Ideas, frameworks, methods (TitleCase.md)
    └── syntheses/      # Saved query answers
```

## Page Types

| Type | Location | Description | Agent can modify? |
|------|----------|-------------|-------------------|
| `daily` | `raw/Daily/` | Daily journal entry | No (append only) |
| `topic` | `raw/Topics/` | Reference topic | No |
| `person` | `raw/People/` | People profile | No |
| `project` | `raw/Projects/` | Project notes | No |
| `source` | `wiki/sources/` | Source summary | Yes (overwrite) |
| `entity` | `wiki/entities/` | Entity profile | Yes (overwrite) |
| `concept` | `wiki/concepts/` | Concept definition | Yes (overwrite) |
| `synthesis` | `wiki/syntheses/` | Saved query answer | Yes (overwrite) |
| `draft` | `wiki/drafts/` | Provisional research | Yes (overwrite) |
| `article` | `wiki/curated/` | Canonical article | Yes (with review) |

## Naming Conventions

| Entity | Convention | Example |
|--------|-----------|---------|
| Daily files | `YYYY-MM-DD.md` | `2026-07-28.md` |
| Topic files | `Kebab-Case.md` | `project-management.md` |
| Entity files | `TitleCase.md` | `AliceJohnson.md` |
| Concept files | `TitleCase.md` | `MachineLearning.md` |
| Source files | `kebab-case-slug.md` | `paper-on-rag.md` |
| Synthesis files | `kebab-case-slug.md` | `comparison-of-frameworks.md` |

## Frontmatter Fields

```yaml
---
title: "Page Title"
type: daily | topic | person | project | source | entity | concept | synthesis | draft | article
tags: []                    # Labels for classification
status: draft | active | archived | provisional | canonical
sources: []                 # Source slugs that inform this page
last_updated: YYYY-MM-DD
---
```

## Workflows

### Ingest (daily, scheduled)
1. Find new/changed files in `raw/` (last 24h)
2. For each: analyze → extract entities/concepts/contradictions
3. Write/update `wiki/sources/`, `wiki/entities/`, `wiki/concepts/`
4. Update `wiki/index.md` and `wiki/log.md`
5. Revise `wiki/overview.md` if warranted
6. **Post-ingest validation**: check broken `[[wikilinks]]`, index completeness

### Research (on demand)
1. User asks a question
2. Search wiki + raw via KiwiFS API
3. Synthesize answer with `[[PageName]]` citations
4. Save as `wiki/drafts/<slug>.md` (status: provisional)

### Consolidate (on demand, human decision)
1. User confirms a decision is final
2. Promote from `wiki/drafts/` to `wiki/curated/` (status: canonical)
3. Add `supersedes:` chain pointing back to draft

### Health (every session, zero LLM cost)
- Check `wiki/index.md` sync with actual files
- Check for empty/stub files
- Check `wiki/log.md` coverage

### Lint (periodic, every 10-15 ingests)
- Orphan pages (no inbound links)
- Broken `[[wikilinks]]`
- Contradictions across pages
- Stale summaries (not updated in 30+ days)
- Missing entity pages (entities mentioned in 3+ sources but no page)
- Phantom hubs (pages referenced by 2+ pages but non-existent)

## Wiki Links

Use `[[PageName]]` or `[[Category/PageName]]` to link pages.
KiwiFS resolves links with fuzzy matching.

## Git Sync

```bash
git push origin main    # KiwiFS auto-commits every write
```

## References

This schema is inspired by:
- [Karpathy's LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [nashsu/llm_wiki](https://github.com/nashsu/llm_wiki) — purpose/schema split, two-step ingest
- [SamurAIGPT/llm-wiki-agent](https://github.com/SamurAIGPT/llm-wiki-agent) — health/lint boundary, post-ingest validation, graph health report
- [OpenKnowledge](https://openknowledge.ai) — provisional/canonical split, per-folder frontmatter
- [KiwiFS](https://docs.kiwifs.com) — markdown filesystem, FTS5 + vector search, git versioning

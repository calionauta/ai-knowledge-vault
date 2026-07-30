# AGENTS.md — Notes Vault

This vault follows the [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
pattern: raw sources are compiled into a structured, interlinked wiki.
See `purpose.md` for directional intent and `schema.md` for structural rules.

Inspired by [nashsu/llm_wiki](https://github.com/nashsu/llm_wiki),
[SamurAIGPT/llm-wiki-agent](https://github.com/SamurAIGPT/llm-wiki-agent),
and [OpenKnowledge](https://openknowledge.ai).

## Vault Structure

```
raw/              # Source documents (immutable — never modify)
  Daily/          # ONE file per day: YYYY-MM-DD.md
                    Format:
                      # YYYY-MM-DD
                      ## 09h15 - Title
                      - content with [[wikilinks]]
  Topics/         # Reference topics — [[Topics/name]] for cross-refs
  People/         # People (classified by frontmatter tags)
  Projects/       # Projects (classified by frontmatter tags)
  any/            # Any category folders
wiki/             # Compiled knowledge (agent owns this layer)
  index.md        # Page catalog — update on every change
  log.md          # Append-only chronological record
  overview.md     # Living synthesis across sources
  sources/        # Source summaries
  entities/       # People, companies, products (TitleCase.md)
  concepts/       # Ideas, frameworks, methods (TitleCase.md)
  syntheses/      # Saved query answers
  drafts/         # Provisional research (status: provisional)
  curated/        # Canonical articles (status: canonical)
```

## Key Rules

1. **Raw is immutable.** Never modify files in `raw/`. Only create new ones.
2. **All notes go into `raw/Daily/YYYY-MM-DD.md`** with `## 09h15 - Title`.
3. **Wiki pages can be overwritten** — they hold the current best understanding.
4. **Contradictions are flagged**, never silently resolved.
5. **Classification is by frontmatter tags**, not by folder structure.
6. **Use `[[wikilinks]]`** to connect related pages.
7. ** Read `schema.md` for full workflow instructions** (ingest, research, consolidate, health, lint).

## Wiki Links (instead of tags)

Use `[[Topics/name]]` for ALL cross-references. DO NOT use `#tags`.

Wikilinks are superior to hashtags because:
- **Bidirectional** — KiwiFS shows backlinks on every page
- **Graph-enabled** — every link creates an edge in the knowledge graph
- **Contextual** — links live in sentences, showing WHY they exist
- **Portable** — works in any markdown viewer, no plugin needed
- **Nestable** — `[[Topics/pai/filho]]` for hierarchical grouping

Examples:
```markdown
- [[Topics/ProjectManagement]] — reference topic
- [[Topics/terapia/abordagens]] — nested topic
- [[People/Fulano]] — person profile
- [[Projects/Apollo]] — project
- [[raw/Daily/2026-07-28]] — link to a specific day
```

Orphan topics (pages referenced but not yet created) become page creation signals.

## Frontmatter Schema

```yaml
---
title: "Page Title"
type: daily | topic | person | project | source | entity | concept | synthesis | draft | article
tags: []       # Optional — use wikilinks for navigation, tags for metadata only
status: draft | active | archived | provisional | canonical
last_updated: YYYY-MM-DD
---
```

Tags should be used sparingly and only for cross-cutting metadata
(like `confidence: low`). Navigation is done via `[[wikilinks]]`.

## Search

KiwiFS API at `http://localhost:3333`:

```bash
# Full-text search
curl -s "http://localhost:3333/api/kiwi/search?q=<query>&limit=10"

# Semantic search
curl -s -X POST "http://localhost:3333/api/kiwi/search/semantic" -d '{"query":"<query>","limit":5}'

# DQL query (structured over frontmatter)
curl -s "http://localhost:3333/api/kiwi/query?q=TABLE+title+FROM+%22raw/People%22+WHERE+tags+CONTAINS+%22client%22"

# Knowledge graph (all connections)
curl -s "http://localhost:3333/api/kiwi/graph"

# Graph analytics (PageRank, communities, orphans)
curl -s "http://localhost:3333/api/kiwi/graph/analytics?limit=20"

# Backlinks for a page
curl -s "http://localhost:3333/api/kiwi/backlinks?path=Topics/ProjectManagement"
```

## Git Sync

```bash
git push origin main
```

KiwiFS auto-commits every write. Push periodically to GitHub.

## Memory Report (consolidation tracking)

KiwiFS provides a memory report that shows which raw notes have not yet
been compiled into wiki pages. Run to check compilation coverage:

```bash
curl -s "http://localhost:3333/api/kiwi/memory/report?episodes_prefix=raw/"
```

Returns a list of files in `raw/` not yet referenced by any `wiki/` page
via `merged-from` frontmatter. Use this to decide what to compile next.

## KiwiFS Agent Playbook

`/data/.kiwi/playbook.md` is a symlink to this file (`AGENTS.md`).
KiwiFS serves it via MCP as `kiwi://playbook` for agents that connect
via the Model Context Protocol (Claude Desktop, Cursor, etc.).

## Known Issues

### ONNX vector search crashes during reindex

`kiwifs reindex --root /data --vector` panics with `slice bounds out of range`
when the `sugarme/tokenizer` v0.3.0 Metaspace pretokenizer processes certain
text patterns (confirmed triggers: 50+ consecutive spaces, mixed Unicode,
very long lines). See:
- [sugarme/tokenizer#78](https://github.com/sugarme/tokenizer/issues/78)
- [sugarme/tokenizer#77](https://github.com/sugarme/tokenizer/issues/77)

Only affects ONNX reindex. FTS5 (BM25) works fine. Fix pending upstream.

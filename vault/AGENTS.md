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

## Frontmatter Schema

```yaml
---
type: daily | topic | person | project | source | entity | concept | synthesis | draft | article
tags: []
status: draft | active | archived | provisional | canonical
last_updated: YYYY-MM-DD
---
```

## Search

KiwiFS API at `http://localhost:3333`:

```bash
# Full-text search
curl -s "http://localhost:3333/api/kiwi/search?q=<query>&limit=10"

# Semantic search
curl -s -X POST "http://localhost:3333/api/kiwi/search/semantic" -d '{"query":"<query>","limit":5}'

# DQL query (structured over frontmatter)
curl -s "http://localhost:3333/api/kiwi/query?q=TABLE+title+FROM+%22raw/People%22+WHERE+tags+CONTAINS+%22client%22"
```

## Git Sync

```bash
git push origin main
```

KiwiFS auto-commits every write. Push periodically to GitHub.

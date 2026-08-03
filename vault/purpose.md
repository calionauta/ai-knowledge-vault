# Purpose — Knowledge Vault

## Why this vault exists

A personal knowledge base that compounds over time: daily notes, reference topics,
people profiles, project docs, and compiled knowledge — searchable by AI agents
(Mercury on the server via Telegram; OpenKnowledge on the desktop).

## Key questions it answers

- What did I do on a given day?
- What do I know about topic X?
- Who is person Y and how do they relate to my work?
- What is the status of project Z?
- What have I learned recently that contradicts or refines previous understanding?

## How it works

1. **Raw notes** go into `raw/` (daily files, topics, people, imports). Immutable.
2. **OpenKB** (server, scheduled) compiles `raw/` into `wiki/{sources,summaries,concepts,entities}`
   + `index.md`/`log.md`, incrementally and automatically.
3. **OpenKnowledge** (desktop) reads the compiled wiki for retrieval and writes
   `wiki/research/` (provisional) and `wiki/articles/` (canonical) on top of it.
4. Everything is plain Markdown + `[[wikilinks]]`, versioned in git.

## Design principles

| Principle | Practice |
|-----------|----------|
| **Immutable sources** | `raw/` is never modified by agents. Only humans add/edit here. |
| **Compiled knowledge** | `wiki/` is agent-maintained; OpenKB regenerates its layers, the agent curates research/articles. |
| **Incremental updates** | Never rebuild from scratch; OpenKB only compiles new/changed files. |
| **Contradictions are flagged** | Never silently resolved. Always surfaced. |
| **One wiki, full pipeline** | From ingest (`sources/`) to consolidated knowledge (`articles/`) in a single `wiki/`. |

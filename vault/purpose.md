# Purpose — Notes Vault

## Why this vault exists

This vault is a personal knowledge base that compounds over time.
It stores daily notes, project documentation, reference topics, people profiles,
and compiled knowledge — all accessible via AI agent (Telegram) and web UI.

## Key questions it answers

- What did I do on a given day?
- What do I know about topic X?
- Who is person Y and how do they relate to my work?
- What is the status of project Z?
- What have I learned recently that contradicts or refines previous understanding?

## How it works

1. **Raw notes** go into `raw/Daily/YYYY-MM-DD.md` with `## HH:MM - Title` sections
2. **Reference topics** live in `raw/Topics/` and are linked via `[[Topics/name]]`
3. **People and projects** are classified by frontmatter tags, not folders
4. **Wiki compilation** (scheduled nightly) extracts entities, concepts, and
   contradictions from raw notes into `wiki/`
5. **Search** works via KiwiFS API (FTS5 + semantic) or ZENITH (local fallback)

## Design principles

| Principle | Practice |
|-----------|----------|
| **Immutable sources** | `raw/` is never modified by agents. Only humans create/edit here. |
| **Compiled knowledge** | `wiki/` is owned by the agent. Overwritten freely. |
| **Incremental updates** | Never rebuild the wiki. Only update affected pages. |
| **Contradictions are flagged** | Never silently resolved. Always surfaced. |
| **Classification by tags** | Not by folder structure. Frontmatter over directory. |
| **Daily notes first** | All new notes go into the daily file. Exceptions are rare. |

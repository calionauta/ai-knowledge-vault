---
name: wiki-compilation
description: >
  Compile the immutable raw/ notes into the wiki/ knowledge base using the
  OpenKB CLI on the server, and coordinate the agent-curated research/ and
  articles/ layers from the desktop (OpenKnowledge). Ingest = drop files into
  raw/; compile = `openkb add`; curation = write wiki/research/ and
  wiki/articles/. Never modify raw/.
version: 4.1.0
intents:
  - compile wiki
  - ingest notes
  - recompile changed notes
  - update wiki
  - run lint
  - check coverage
  - openkb
  - wiki status
  - research synthesis
  - consolidate article
allowed-tools:
  - exec
  - bash
---

# Wiki Compilation (OpenKB + OpenKnowledge)

## Where things run and who owns what

| Layer | Runs on | Owner | What it is |
|-------|---------|-------|------------|
| `raw/` | server + desktop | human | immutable input; the ONLY place notes enter |
| `wiki/{sources,summaries,concepts,entities}` + `index.md`/`log.md` | **server** | **OpenKB CLI** | automatic compile pipeline (ingest -> synthesis) |
| `wiki/research/` (status: draft) | **desktop** | **agent (OpenKnowledge)** | provisional, cited synthesis |
| `wiki/articles/` (status: final) | **desktop** | **agent** | canonical knowledge, `supersedes` chain |
| `.openkb/` | server | OpenKB state | never committed |

This is ONE pipeline, not two: OpenKB does ingest+compile; the agent does
research+consolidate on top of the compiled pages.

## CRITICAL RULES

1. NEVER modify files in `raw/`. Read only. New notes are added; existing ones are never edited.
2. The OpenKB compiler owns `sources/ summaries/ concepts/ entities/ index.md log.md`.
   It must NEVER write to `research/` or `articles/`.
3. The curator agent writes ONLY `research/` and `articles/`; it must not hand-edit
   OpenKB-owned pages (a future `openkb recompile` would overwrite them).
4. Flag contradictions. Never silently resolve them.
5. Always `git pull --rebase` before pushing; the server and desktop push to the same repo.
6. Wiki page text: Portuguese (OpenKB `language: pt`). Skill files and comments: English.

## Reference scripts ($SKILL_DIR/references/)

```bash
# Path resolution — scripts live next to this SKILL.md
SKILL_DIR="${SKILL_DIR:-$HOME/.mercury/skills/wiki-compilation}"
```

| Script | Purpose |
|--------|---------|
| `sync.sh` | `git pull --rebase` — bring new raw notes and agent edits |
| `compile.sh` | `openkb add raw/` (incremental) + `openkb lint` + optional commit/push |
| `coverage.sh` | count raw files vs `wiki/sources` (no external API) |

## Workflow: daily compile (server, scheduled)

1. `bash "$SKILL_DIR/references/sync.sh"` — pull new notes from origin.
2. `bash "$SKILL_DIR/references/compile.sh" --commit` — compile + lint + push wiki.
3. `bash "$SKILL_DIR/references/coverage.sh"` — report coverage.
4. Notify via Telegram with counts and any `openkb lint` warnings.

`openkb add raw/` is incremental: it skips unchanged files via
`.openkb/hashes.json`, so a daily run only compiles new/changed notes.

## Workflow: research (desktop agent, on demand)

1. Retrieve: read `wiki/index.md`, then 1-2 `wiki/concepts/*.md`; follow `[[wikilinks]]`.
   Prefer reading compiled pages over `openkb query` (cheaper, stays in context).
2. Synthesize across 2+ sources -> write `wiki/research/<slug>.md`
   (`type: Research`, `status: draft`, `sources:`, cited body). Build ON TOP of the
   compiled pages — cite `[[concepts/...]]` / `[[summaries/...]]` instead of re-summarizing.
3. git add/commit/push (`pull --rebase` first).

## Workflow: consolidate (human decision)

1. When a position becomes canonical, promote it:
   `git mv wiki/research/<slug>.md wiki/articles/<slug>.md`.
2. Set `status: final` and add `supersedes:` pointing at the draft/prior article.
3. git add/commit/push.

## Page conventions (see also wiki/AGENTS.md)

- OpenKB-generated pages carry OKF frontmatter: `type`, `description`, `sources`
  (concepts/entities), `doc_type`/`full_text` (sources).
- Curated pages: `type: Research|Article`, `status: draft|final`, `sources`, `supersedes`.
- Wikilinks resolve relative to `wiki/`: `[[concepts/slug]]`, `[[summaries/slug]]`,
  `[[entities/slug]]`, `[[research/slug]]`, `[[articles/slug]]`. Piped aliases allowed.

## Topic/tag conventions (`raw/Topics/`)

1. **Naming: lowercase kebab-case.** `ai-native`, `machine-learning`. NEVER camelCase —
   it breaks on acronyms (`aiNative` vs `AInative`) and is the root cause of
   `ai` vs `AI-native` style duplicates. Existing single-word proper nouns
   (`Region`, `Brasil`) stay as-is.
2. **Link format in notes: tag as its own bullet, annotation indented below:**
   ```markdown
   - [[raw/Topics/ai-native]]
       - annotation text
   ```
   Keeps the tag line a pure link (easy to grep/audit for duplicates), supports
   multiple annotations under one tag, and long notes don't pollute the link.
   Do NOT put the tag inline on the annotation line.
3. **No duplicates — not even variations.** One canonical Topic per concept.
   When creating a new Topic, first `grep -ri "Topics/" raw/` to check existing
   spellings (singular vs plural, case). If a variation exists, reuse the
   canonical one; merge+delete stubs rather than creating new files.
4. **Canonical names post-dedup (Aug 2026):** `assumption`, `emotion`,
   `experiment`, `psychedelic`, `reason` (singular wins); `arguments` (wins over
   `arguing`); `adulto` (wins over `Adulti`); `ai` (wins over `AI-native`).

## Provider

OpenKB uses LiteLLM. Provider env lives in `<KB_DIR>/.env`
(`OPENAI_API_KEY` + `OPENAI_BASE_URL`, gitignored, chmod 600).
Config: `.openkb/config.yaml` -> `model: openai/MiniMax-M3`, `language: pt`,
`pageindex_threshold: 20`.

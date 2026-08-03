# AGENTS.md — Knowledge Vault (octarine-notes)

This is the single contract for the `octarine-notes` knowledge base. It is read by
**OpenKB** (the server-side compiler) at runtime and by any **agent** (OpenKnowledge on the
desktop, Mercury, opencode, Claude Code) that operates on the vault. Keep it in English;
compiled wiki content stays in Portuguese (`language: pt` in OpenKB config).

The vault follows the [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
pattern: immutable sources are compiled into an interlinked wiki that compounds over time.

## Structure

```
octarine-notes/
├── raw/                 # IMMUTABLE input. The ONLY place notes enter. Never edit existing files.
└── wiki/                 # The single knowledge base — full pipeline (ingest -> consolidated)
    ├── AGENTS.md         # this contract
    ├── index.md · log.md # maintained by OpenKB
    ├── sources/          # normalized ingest of each raw doc        (OpenKB)  ← INGEST
    ├── summaries/        # per-document summary                     (OpenKB)  ← COMPILE
    ├── concepts/         # cross-document synthesis                 (OpenKB)  ← SYNTHESIS
    ├── entities/         # people/orgs/places/products              (OpenKB)
    ├── explorations/     # saved `openkb query` answers             (OpenKB)
    ├── reports/          # lint reports                             (OpenKB)
    ├── research/         # agent-authored provisional synthesis     (agent)   status: draft
    └── articles/         # agent-authored canonical knowledge       (agent)   status: final
```

## Layer ownership — do not cross

| Path | Owner | Role | Instruction |
|------|-------|------|-------------|
| `raw/` | human | immutable input | never edit; only add new files |
| `wiki/sources|summaries|concepts|entities` + `index.md`/`log.md` | **OpenKB** | compile pipeline | generated; do not hand-edit |
| `wiki/research/` | **agent** | provisional synthesis (status: draft, cites) | OpenKB must NOT write here; link concepts to it |
| `wiki/articles/` | **agent** | canonical (status: final, supersedes) | OpenKB must NOT write here; link concepts to it |

The OpenKB compiler owns exactly `sources/ summaries/ concepts/ entities/ index.md log.md`
(plus `explorations/ reports/`). It must never create/edit/delete under `research/` or
`articles/`. The curator agent writes ONLY `research/` and `articles/` and must not hand-edit
OpenKB-owned pages (a future `openkb recompile` overwrites them).

## Frontmatter

Generated pages carry OKF-style YAML frontmatter:
- Source/summary: `type`, `description`, `sources`, `full_text` (long docs add `doc_type: pageindex`).
- Concept: `type: Concept`, `description`, `sources: [...]`.
- Entity: `type` subtype (`Person`/`Organization`/`Place`/`Product`/`Work`/`Event`), `description`, `sources`.
- Curated pages: `type: Research|Article`, `status: draft|final`, `description`, `sources`, optional `supersedes`.

## Wikilinks

Obsidian-compatible `[[wikilink]]`, resolved relative to `wiki/`:
`[[concepts/slug]]`, `[[summaries/slug]]`, `[[entities/slug]]`, `[[sources/slug]]`,
`[[research/slug]]`, `[[articles/slug]]`. Piped aliases allowed (`[[entities/name|Label]]`).
Keep links resolved; run `openkb lint` (`--fix`) to strip stale ones.

## Workflows

### Ingest (new note)
Drop the file into `raw/` (any supported format: md, pdf, docx, html, txt, url). Push to origin.
OpenKB picks it up on the next scheduled compile.

### Compile (server, scheduled by Mercury)
1. `git pull --rebase` (bring new notes + agent edits).
2. `openkb --kb-dir <repo> add raw/` (incremental; skips unchanged via hashes).
3. `openkb --kb-dir <repo> lint`.
4. `git add wiki/ raw/ && git pull --rebase && git commit && git push`.

### Research (desktop agent, on demand)
Read `wiki/index.md` + 1-2 `wiki/concepts/*.md`, follow `[[wikilinks]]`. Synthesize across 2+
sources into `wiki/research/<slug>.md` (`status: draft`), citing `[[concepts/...]]` /
`[[summaries/...]]`. Build on top of compiled pages — do not re-summarize them.

### Consolidate (human decision)
Promote `wiki/research/<slug>.md` -> `wiki/articles/<slug>.md` (`status: final`), add
`supersedes:` chain. Push.

### Health / lint
`openkb lint` for structural checks. `coverage.sh` counts raw vs `wiki/sources`.

## Git sync
- Server -> origin: Mercury daily (pull -> compile -> push).
- Desktop -> origin: agent writes `wiki/research/` + `wiki/articles/`, pushes.
- Always `git pull --rebase` before push (both sides write the same repo).
- `.openkb/` and `.env` are gitignored (state + secrets).

## Provider
OpenKB uses LiteLLM. Provider env in `<root>/.env` (`OPENAI_API_KEY`, `OPENAI_BASE_URL`),
gitignored, chmod 600. `.openkb/config.yaml`: `model: openai/MiniMax-M3`, `language: pt`,
`pageindex_threshold: 20`.
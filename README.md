# ai-knowledge-vault

Source of truth for the `octarine-notes` knowledge vault: the **wiki-compilation skill**
(used by Mercury on the server), the **vault contract** (`vault/AGENTS.md`, deployed as
`wiki/AGENTS.md`), and templates. No KiwiFS dependency.

## The strategy: one wiki, full pipeline

Two tools cooperate on the **same git repo** (`github.com/calionauta/octarine-notes`):

| Tool | Where | Layer | Role |
|------|-------|-------|------|
| **OpenKB** (`openkb` CLI) | server (`~/octarine-notes`), scheduled by Mercury | `wiki/{sources,summaries,concepts,entities}` + `index.md`/`log.md` | ingest + compile: `raw/` → wiki, incremental |
| **OpenKnowledge** (app + agent) | desktop | `wiki/research/` (status: draft), `wiki/articles/` (status: final) | research + consolidate on top of the compiled wiki |
| **Mercury** (daemon) | server | orchestrator | daily: `git pull` → `openkb add raw/` → lint → push → Telegram |

`raw/` is immutable input. `wiki/` is the single knowledge base — from ingest to consolidated
knowledge. `wiki/AGENTS.md` is the contract read by both OpenKB and any agent.

## Repo layout

```
skills/wiki-compilation/     Mercury skill: OpenKB compile + git orchestration
  SKILL.md                   workflow (English)
  references/compile.sh      openkb add raw/ + lint (+ optional commit/push)
  references/sync.sh         git pull --rebase
  references/coverage.sh     raw vs wiki/sources counting
skills/notes-search/         filesystem-based note search/save (no external API)
skills/project-manager/      project/issue backends (multica, runfusion, ...)
vault/AGENTS.md              canonical contract → deploy as wiki/AGENTS.md
vault/purpose.md             why the vault exists
mercury/mercury.yaml         Mercury config template (MiniMax provider)
templates/daily-note.md      raw/Daily/YYYY-MM-DD.md template
```

## Deploying to the server

```bash
# 1. Skill → Mercury
rsync -a skills/wiki-compilation/ deploy@server.calionauta.com:~/.mercury/skills/wiki-compilation/
# 2. Contract → vault
scp vault/AGENTS.md deploy@server.calionauta.com:~/octarine-notes/wiki/AGENTS.md
```

Remove stale Mercury skill copies that referenced KiwiFS:
`wiki-compilation-v2/`, `references/` (top-level), `vault-search/`, `auto-push/`.

## Local development

```bash
# Desktop: clone the vault and open it in OpenKnowledge (content dir = wiki/)
git clone https://github.com/calionauta/octarine-notes
# Configure .ok/config.yml with content.dir: wiki (see Desktop section in the plan)
```

## Notes

- All repo content is in **English**; compiled wiki content is **Portuguese**
  (OpenKB `language: pt`, model `openai/MiniMax-M3` via `api.minimax.io/v1`).
- `.openkb/` and `.env` are gitignored (OpenKB state + secrets).
- Never modify `raw/`.

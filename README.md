# ai-knowledge-vault

Source of truth for the knowledge vault: the **wiki-compilation skill**
(used by Mercury on the server), the **notes-search skill** (Mercury + openkb query),
the **vault contract** (`vault/AGENTS.md`, deployed as `wiki/AGENTS.md`), and templates.

## The strategy: one wiki, full pipeline

| Tool | Where | Layer | Role |
|------|-------|-------|------|
| **OpenKB** (`openkb` CLI) | server, scheduled by Mercury | `wiki/{sources,summaries,concepts,entities}` + `index.md`/`log.md` | ingest + compile: `raw/` → wiki, incremental |
| **OpenKnowledge** (app + agent) | desktop | `wiki/research/` (status: draft), `wiki/articles/` (status: final) | research + consolidate on top of the compiled wiki |
| **Mercury** (daemon) | server | orchestrator + search | daily compile + notes-search (filesystem + openkb query) |

`raw/` is immutable input. `wiki/` is the single knowledge base — from ingest to consolidated
knowledge. `wiki/AGENTS.md` is the contract read by both OpenKB and any agent.

## notes-search skill (Mercury)

Two search modes for finding notes:

| Mode | When | How | Cost |
|------|------|-----|------|
| **Filesystem** | Search for term/name/keyword | `rg` in raw/ + wiki/ | Free |
| **openkb query** | Synthesis questions ("o que sei sobre X?") | `openkb query` (LLM) | Tokens |

The skill auto-detects: questions → openkb query; terms → filesystem search.
Always starts with filesystem (fast, free), falls back to openkb if needed.

## Repo layout

```
skills/wiki-compilation/     Mercury skill: OpenKB compile + git orchestration
  SKILL.md                   workflow (English)
  references/compile.sh      openkb add raw/ + lint (+ optional commit/push)
  references/sync.sh         git pull --rebase
  references/coverage.sh     raw vs wiki/sources counting
skills/notes-search/         search (filesystem + openkb query) + save notes
skills/project-manager/      project/issue backends (multica, runfusion, ...)
vault/AGENTS.md              canonical contract → deploy as wiki/AGENTS.md
vault/purpose.md             why the vault exists
mercury/mercury.yaml         Mercury config template (MiniMax provider)
templates/daily-note.md      raw/Daily/YYYY-MM-DD.md template
scripts/enrich-urls.py       enrich bare URLs with title + description
```

## Deploying to the server

```bash
rsync -a skills/wiki-compilation/ deploy@server:~/.mercury/skills/wiki-compilation/
rsync -a skills/notes-search/ deploy@server:~/.mercury/skills/notes-search/
scp vault/AGENTS.md deploy@server:~/vault/wiki/AGENTS.md
```

## Local development

```bash
git clone https://github.com/calionauta/ai-knowledge-vault
# Desktop: clone the vault and open it in OpenKnowledge (content dir = wiki/)
```

# Notes Vault

> A personal knowledge vault powered by KiwiFS + Mercury Agent.  
> Searchable. Versioned. Accessible via Telegram. Compiled by AI.

[Why](#why) · [Architecture](#architecture) · [Quick Start](#quick-start) · [Local vs Server](#local-vs-server) · [KiwiFS Setup](#kiwif-configuration) · [Mercury Setup](#mercury-configuration) · [Skills](#skills) · [LLM Wiki](#llm-wiki-pattern) · [Project Management](#project-management) · [Vault Structure](#vault-structure) · [Troubleshooting](#troubleshooting)

---

## Why

Most note systems are either **read-only for agents** (Notion, Obsidian without hacks) or **write-only for humans** (raw markdown files with no search). Notes Vault gives you both:

- **Humans** write markdown in any editor (Obsidian, Octarine, VS Code)
- **Agents** read/write/search via REST API or Telegram
- **Git** versions everything automatically
- **LLM Wiki** compiles raw notes into structured, interlinked knowledge

The result: your notes compound across sessions instead of vanishing in chat history.

---

## Architecture

```
┌─ LOCAL ──────────────────────────────────┐
│  Your editor (Obsidian, Octarine, etc.)  │
│  git push → GitHub                       │
└──────────────────────────────────────────┘
                    │
            git pull/push
                    │
┌─ SERVER (optional) ──────────────────────┐
│  KiwiFS (port 3333)                      │
│    ├── Markdown vault (git versioned)     │
│    ├── Full-text + semantic search        │
│    ├── Web UI (built-in)                 │
│    └── REST API                          │
│                                           │
│  Mercury Agent (daemon)                  │
│    ├── Telegram/Discord interface        │
│    ├── Notes skill (search + write)      │
│    ├── Wiki compilation (scheduled)      │
│    └── Project manager (pluggable)       │
└──────────────────────────────────────────┘
```

### Two modes

| Mode | When to use | Requirements |
|------|-------------|-------------|
| **Local only** | Single machine, always on | KiwiFS binary + Mercury running locally |
| **Server + local** | Access from anywhere, 24/7 | VPS (2GB RAM minimum), Tailscale or Cloudflare |

---

## Quick Start

Choose your path:

### 👤 For humans

```bash
# 1. Install KiwiFS
curl -fsSL https://raw.githubusercontent.com/kiwifs/kiwifs/main/install.sh | sh

# 2. Initialize vault
kiwifs init --template blank --root ./my-vault

# 3. Set up the structure (copy from this repo)
cp -r vault/* ./my-vault/

# 4. Start KiwiFS
kiwifs serve --root ./my-vault

# Open http://localhost:3333
```

### 🤖 For LLM agents

> Give this repository URL to Claude Code, Codex, Mercury, or any agent
> that reads markdown. The agent will ask you questions and set everything up.

```
I want to set up a Notes Vault based on:
https://github.com/calionauta/knowledge-vault

Guide me through the setup step by step.
Start by asking me:
1. Local only or server + local?
2. Do I have an existing notes repository on GitHub?
3. What LLM provider do you use? (API key needed)
4. Telegram bot token? (optional)
```

---

## Local vs Server

The setup assistant (human or LLM) will ask:

| Question | Options |
|----------|---------|
| Where will KiwiFS run? | `local` (your machine) or `server` (VPS) |
| Existing notes? | GitHub repo URL, local path, or none |
| GitHub CLI (`gh`) available? | Auto-detected. If missing, offers to install or delegates. |
| Timezone | Auto-detected from IP, confirm or override |
| Daily note format | Default: `YYYY-MM-DD.md` |
| Git auto-push? | Yes (every 30 min via Mercury schedule) |

### If you choose "local only"

KiwiFS and Mercury run on your machine. KiwiFS auto-commits changes to git.
You push to GitHub manually or via Mercury schedule.
Mercury connects to Telegram for mobile access.

**Requires:** Your machine to be on when you need Telegram access.

### If you choose "server + local"

KiwiFS runs on a VPS (2GB RAM minimum). You edit locally with your preferred
editor and push to GitHub. The server pulls and serves the vault 24/7.
Mercury runs on the server.

**Requires:** A VPS + Tailscale or Cloudflare tunnel for web access.

---

## KiwiFS Configuration

### Server config (`kiwifs/config.toml`)

```toml
[server]
port = 3333
host = "0.0.0.0"

[storage]
root = "/data"

[search]
engine = "sqlite"

[search.vector]
enabled = true
worker_count = 2

[search.vector.embedder]
provider = "onnx"
model_path = "~/.kiwi/models/multilingual-e5-small/onnx/model.onnx"
dimensions = 384
query_prefix = "query: "
passage_prefix = "passage: "

[search.vector.store]
provider = "sqlite-vec"

[versioning]
strategy = "git"

[backup]
remote = ""  # Set to your GitHub remote
interval = "10m"
```

### Vault config (`vault/.kiwi/config.toml`)

```toml
[workspace]
name = "My Vault"
template = "blank"

[search]
engine = "sqlite"

[search.vector]
enabled = true
worker_count = 2

[search.vector.embedder]
provider = "onnx"
model_path = "~/.kiwi/models/multilingual-e5-small/onnx/model.onnx"
dimensions = 384
query_prefix = "query: "
passage_prefix = "passage: "

[search.vector.store]
provider = "sqlite-vec"

[versioning]
strategy = "git"

[janitor]
stale_days = 90
check_orphans = true
check_broken_links = true
```

> **About the ONNX model:** `multilingual-e5-small` supports 100+ languages
> (including pt-BR, en-US, es, etc.). Download it with:
> ```bash
> kiwifs model download multilingual-e5-small --root ./my-vault
> ```

### Docker

```bash
docker run -d \
  --name kiwifs \
  -p 3333:3333 \
  -v ./my-vault:/data \
  ameliaanhlam/kiwifs
```

---

## Mercury Configuration

Mercury is the AI agent that connects Telegram to your vault.

### Template config (`mercury/mercury.yaml`)

```yaml
identity:
  name: mercury
  owner: ""  # Set during setup

providers:
  openai:
    name: openai
    apiKey: "${OPENAI_API_KEY}"
    baseUrl: ""  # Set your provider endpoint
    model: ""    # Set your model
    enabled: true

channels:
  telegram:
    enabled: true
    botToken: "${TELEGRAM_TOKEN}"

web:
  enabled: true
  port: 6174

permissions:
  mode: allow-all

skills:
  auto_discover: true
```

### Setup flow

1. Copy the template and set your API key and Telegram token
2. Run `mercury setup` to complete onboarding (Telegram pairing)
3. Approve your Telegram user: `mercury telegram approve <CODE>`

### Web dashboard

Access the Mercury web dashboard (when running locally):

```
http://localhost:6174
```

If running on a server, use a reverse proxy or Tailscale to access port 6174.

---

## Skills

These SKILL.md files teach Mercury how to interact with your vault.
They contain **zero personal data** — all user-specific values are
configured via environment variables or during setup.

### Notes Search

**File:** `skills/notes-search/SKILL.md`

Commands: search notes, read notes, write daily entries, list recent changes.

```
"what did I note this week?"
"save this idea: ..."
"search for authentication patterns"
```

All notes go into `raw/Daily/YYYY-MM-DD.md` with `## HH:MM - Title` format.

### Wiki Compilation

**File:** `skills/wiki-compilation/SKILL.md`

Scheduled nightly. Reads raw notes, extracts entities and concepts,
maintains the wiki layer.

```
"compile the wiki"
"ingest today notes"
```

Follows the [LLM Wiki Agent](https://github.com/SamurAIGPT/llm-wiki-agent) pattern.

### Project Manager

**File:** `skills/project-manager/SKILL.md`

Pluggable backend for project management. Supports multiple adapters:

| Adapter | Backend | Access | Setup |
|---------|---------|--------|-------|
| `multica` | [multica.ai](https://multica.ai) | CLI (`multica`) | `pip install multica` or binary |
| `runfusion` | [runfusion.ai](https://runfusion.ai) | REST API | API key |
| `multigent` | [multigent](https://github.com/multigent/multigent) | API/CLI | `pip install multigent` |
| `mercury-native` | Mercury Kanban | Native | Built-in, no setup |

To use, set the adapter in your config:

```yaml
# ~/.mercury/project-manager-config.yaml
adapter: multica  # or runfusion, multigent, mercury-native
```

---

## LLM Wiki Pattern

The vault follows the [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
pattern: raw sources are compiled into structured, interlinked wiki pages.

### Three layers

```
raw/              ← immutable source notes (you write)
wiki/             ← compiled knowledge (agent maintains)
AGENTS.md         ← rules for the agent
```

### Operations

| Operation | Frequency | What happens |
|-----------|-----------|-------------|
| **Ingest** | Daily (scheduled) | Agent reads new raw notes, updates wiki pages, extracts entities |
| **Query** | On demand | Agent searches wiki/raw, synthesizes answer with citations |
| **Lint** | Weekly | Agent checks for contradictions, orphans, stale claims |

### Key rules

- Raw notes are **immutable** — agent never modifies `raw/`
- Wiki pages can be **overwritten** — they hold the current best understanding
- Contradictions are **flagged**, never silently resolved
- Each ingest touches 5-15 wiki pages (entities, concepts, sources)
- The `index.md` file is the navigation entry point

### First-time compilation

For an existing vault with many notes:

1. Process in batches of ~10 sources
2. Each batch: identify affected pages → update → flag contradictions
3. Run lint after every 50 sources
4. Full compilation may take several sessions

---

## Vault Structure

```
my-vault/
├── raw/                    # Source documents (immutable)
│   ├── Daily/              # Daily notes YYYY-MM-DD.md
│   ├── Topics/             # Reference topics [[Topics/name]]
│   ├── Notes/              # General notes (deprecated, use Daily)
│   ├── People/             # People (classified by frontmatter tags)
│   ├── Projects/           # Projects (classified by frontmatter tags)
│   ├── BusinessIdeas/      # Business ideas
│   └── ...                 # Any other categories
├── wiki/                   # Agent-maintained wiki
│   ├── index.md            # Page catalog
│   ├── log.md              # Chronological record
│   ├── overview.md         # Living synthesis
│   ├── sources/            # Source summaries
│   ├── entities/           # People, companies, products
│   ├── concepts/           # Ideas, frameworks, methods
│   └── syntheses/          # Saved query answers
├── AGENTS.md               # Vault rules
├── SCHEMA.md               # Frontmatter conventions
├── .kiwi/
│   └── config.toml         # KiwiFS config
└── index.md                # Vault home
```

### Daily note format

```markdown
# 2026-07-28

## 09:15 - Meeting with Client
- Discussed project timeline
- Action items: send proposal by Friday
- [[Topics/ProjectManagement]]

## 14:30 - Research Notes
- Found interesting paper on X
- Key insight: ...
```

### Classification by tags, not folders

```yaml
---
type: person
tags: [client, friend, mentor]  # Any combination
status: active
---

---
type: project
tags: [product, consulting, app]
client: "[[People/Name]]"
status: active
---
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| KiwiFS won't start | Port 3333 in use? Change with `--port` |
| Mercury daemon not running | Run `mercury start` or check `journalctl --user -u mercury` |
| Telegram no response | Send `/start` to your bot, then `mercury telegram approve <CODE>` |
| Git push fails | Check remote URL: `git remote -v`. Use HTTPS with GitHub token. |
| ONNX model not found | Run `kiwifs model download multilingual-e5-small --root .` |
| Permission denied in Docker volume | Files owned by container user. Use `docker exec -u root` to fix. |
| "No output generated" from Mercury | Check provider API key and base URL. Model may not exist. |

---

## License

MIT

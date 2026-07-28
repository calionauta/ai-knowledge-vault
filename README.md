# Knowledge Vault

> Your notes and project management live in separate silos — this repo bridges them.
> [KiwiFS](https://github.com/kiwifs/kiwifs) stores and searches Markdown.
> [Mercury](https://mercuryagent.sh) (AI agent) connects Telegram, CLI, and REST
> to notes, wiki, and tasks — with pluggable project management adapters
> ([Multica](https://multica.ai), [Runfusion](https://runfusion.ai), [Kanban](https://mercuryagent.sh)).
> Pre-built skills.

[Quick Start](#quick-start) · [Why](#why) · [Architecture](#architecture) · [Local vs Server](#local-vs-server) · [KiwiFS Setup](#kiwif-configuration) · [Mercury Setup](#mercury-configuration) · [Skills](#mercury-skills--notes--projects) · [LLM Wiki](#llm-wiki-pattern) · [Project Management](#project-management) · [Vault Structure](#vault-structure) · [Troubleshooting](#troubleshooting)

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
I want to set up a Knowledge Vault based on:
https://github.com/calionauta/knowledge-vault

Guide me through the setup step by step.
Start by asking me:
1. Local only or server + local?
2. Do you need project management? (Mercury Kanban / Multica / Runfusion)
3. Do I have an existing notes repository on GitHub?
4. What LLM provider do you use? (API key needed)
5. Telegram bot token? (optional)
```

---

## Why

Most note systems are either **read-only for agents** (Notion, Obsidian without hacks)
or **write-only for humans** (raw files, no search). And project management lives
in a completely separate silo (Jira, Trello, Notion databases) that agents can't reach.

**Knowledge Vault** fixes both problems with **Mercury as the bridge**:

- **Humans** write notes in any editor + manage projects via Mercury Kanban or external tools
- **Mercury** connects everything: reads notes, compiles the wiki, and syncs tasks — all via Telegram, CLI, or REST
- **Agents** can search notes, update tasks, and compile knowledge across both worlds
- **KiwiFS** stores markdown files with full-text + vector search, git versioning, and a web UI
- **Git** versions everything automatically

The result: your notes **and projects** compound across sessions instead of vanishing in chat history. All through one Telegram bot.

> **✅ Pre-built and ready to use:** This repo includes [Notes Search](./skills/notes-search/SKILL.md),
> [Wiki Compilation](./skills/wiki-compilation/SKILL.md), and
> [Project Management](./skills/project-manager/SKILL.md) skills — each is a `SKILL.md` file
> that Mercury reads and runs. Copy the vault, configure Mercury, and it works.

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
│  Mercury — AI bridge                     │
│    ├── Telegram/Discord/CLI interface    │
│    ├── Notes: search, write, read        │
│    ├── Wiki compilation (scheduled)      │
│    └── Projects: tasks via pluggable project management adapters  │
└──────────────────────────────────────────┘
```

### Two modes

| Mode | When to use | Requirements |
|------|-------------|-------------|
| **Local only** | Single machine, always on | KiwiFS binary + Mercury running locally |
| **Server + local** | Access from anywhere, 24/7 | VPS (2GB RAM minimum), Tailscale or Cloudflare |

---

## Local vs Server

The setup assistant (human or LLM) will ask:

| Question | Options |
|----------|---------|
| Where will KiwiFS run? | `local` (your machine) or `server` (VPS) |
| Enable semantic search? | `yes` (needs ONNX build or Ollama) or `no` (uses FTS5 only, simpler) |
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
type = "onnx"
# Model: intfloat/multilingual-e5-small (huggingface.co/intfloat/multilingual-e5-small)
model_path = "/data/.kiwi/models/multilingual-e5-small/onnx/model.onnx"
tokenizer_path = "/data/.kiwi/models/multilingual-e5-small/tokenizer.json"
dimensions = 384
query_prefix = "query: "
passage_prefix = "passage: "

[search.vector.store]
provider = "sqlite-vec"  # github.com/asg017/sqlite-vec

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
type = "onnx"
# Model: intfloat/multilingual-e5-small (huggingface.co/intfloat/multilingual-e5-small)
model_path = "/data/.kiwi/models/multilingual-e5-small/onnx/model.onnx"
tokenizer_path = "/data/.kiwi/models/multilingual-e5-small/tokenizer.json"
dimensions = 384
query_prefix = "query: "
passage_prefix = "passage: "

[search.vector.store]
provider = "sqlite-vec"  # github.com/asg017/sqlite-vec

[versioning]
strategy = "git"

[memory]
episodes_path_prefix = "raw/"

[janitor]
stale_days = 90
check_orphans = true
check_broken_links = true
```

> The `episodes_path_prefix = "raw/"` config tells KiwiFS to track raw notes
> as episodic memory. Use `curl http://localhost:3333/api/kiwi/memory/report`
> to see which notes haven't been compiled into wiki pages yet.

### Symlink playbook → AGENTS.md

For MCP-capable agents (Claude Desktop, Cursor), KiwiFS exposes a playbook
via `kiwi://playbook`. Symlink it to AGENTS.md so both interfaces get the
same instructions:

```bash
cd .kiwi
ln -sf ../AGENTS.md playbook.md
```

> **Vector search note:** The pre-built KiwiFS Docker image (`ameliaanhlam/kiwifs`)
> does **not** include ONNX runtime. Vector/semantic search is disabled by default.
> Full-text search (BM25/FTS5) works out of the box with any image.

### Docker (no semantic search — simpler)

Uses the official image. Only FTS5 search available.

```bash
docker run -d \
  --name kiwifs \
  --restart unless-stopped \
  -p 3333:3333 \
  -v ./my-vault:/data \
  ameliaanhlam/kiwifs
```

### Docker (with ONNX semantic search)

Build a custom image with [ONNX Runtime](https://github.com/microsoft/onnxruntime) 1.28+. The Dockerfile auto-detects your CPU architecture (x86_64 or ARM64).

```dockerfile
# syntax=docker/dockerfile:1
# Stage 1: Build web UI (required for //go:embed ui/dist)
FROM --platform=$BUILDPLATFORM node:22-alpine AS ui
WORKDIR /ui
COPY ui/package.json ui/package-lock.json* ./
RUN npm ci --no-audit --no-fund --loglevel=error
COPY ui ./
ENV NODE_OPTIONS=--max-old-space-size=3072
RUN npm run build

# Stage 2: Build Go binary with CGO + ONNX
FROM --platform=$BUILDPLATFORM golang:1.26-bookworm AS builder
ARG TARGETARCH
RUN apt-get update && apt-get install -y git ca-certificates pkg-config curl
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

# Download ONNX Runtime 1.28+ for your arch
# Uses shell variable ORT_ARCH (Docker ADD doesn't expand non-ARG vars)
RUN ORT_ARCH=x64; \
    [ "$TARGETARCH" = "arm64" ] && ORT_ARCH=aarch64; \
    echo "Downloading ONNX Runtime for ${TARGETARCH} (${ORT_ARCH})..." && \
    curl -fSL -o /tmp/onnx.tgz \
      "https://github.com/microsoft/onnxruntime/releases/download/v1.28.0/onnxruntime-linux-${ORT_ARCH}-1.28.0.tgz" && \
    tar xzf /tmp/onnx.tgz -C /opt/ && \
    mv /opt/onnxruntime-linux-${ORT_ARCH}-1.28.0 /opt/onnxruntime && \
    rm /tmp/onnx.tgz

COPY . .
RUN rm -rf ui/dist
COPY --from=ui /ui/dist ./ui/dist

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-I/opt/onnxruntime/include"
ENV CGO_LDFLAGS="-L/opt/onnxruntime/lib -lonnxruntime"
ENV GOOS=linux GOARCH=$TARGETARCH
RUN go build -tags onnx -ldflags="-s -w" -o /kiwifs .

# Stage 3: Runtime
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates git && \
    rm -rf /var/lib/apt/lists/* && useradd -m kiwi

COPY --from=builder /opt/onnxruntime/lib/libonnxruntime.so.1.28.0 /usr/lib/
RUN ln -sf libonnxruntime.so.1.28.0 /usr/lib/libonnxruntime.so.1 && \
    ln -sf libonnxruntime.so.1 /usr/lib/libonnxruntime.so && \
    ln -sf libonnxruntime.so /usr/lib/onnxruntime.so && ldconfig

COPY --from=builder /kiwifs /usr/local/bin/kiwifs
RUN mkdir -p /data && chown kiwi:kiwi /data
USER kiwi
EXPOSE 3333
VOLUME ["/data"]
ENTRYPOINT ["kiwifs"]
CMD ["serve", "--root", "/data", "--port", "3333", "--host", "0.0.0.0"]
```

> **⚠️ Important:** The line `ln -sf libonnxruntime.so /usr/lib/onnxruntime.so` creates
> a symlink **without the `lib` prefix**. This is required because the Go bindings
> [`yalue/onnxruntime_go`](https://github.com/yalue/onnxruntime_go) calls
> `dlopen("onnxruntime.so")` at runtime. Without it, ONNX initialization will fail
> with "cannot open shared object file".

Build and run:

```bash
# Clone kiwifs
gh repo clone kiwifs/kiwifs /tmp/kiwifs || \
  git clone https://github.com/kiwifs/kiwifs.git /tmp/kiwifs

# Build (auto-detects your CPU architecture)
cd /tmp/kiwifs
docker build -t kiwifs-onnx -f Dockerfile.onnx .

# Run
docker run -d \
  --name kiwifs \
  --restart unless-stopped \
  -p 3333:3333 \
  -v ./my-vault:/data \
  kiwifs-onnx

# Download the multilingual model to the persistent volume
docker exec -u root kiwifs sh -c '
  apt-get update -qq && apt-get install -y -qq curl ca-certificates
  mkdir -p /data/.kiwi/models/multilingual-e5-small/onnx
  curl -fSL -o /data/.kiwi/models/multilingual-e5-small/onnx/model.onnx \
    "https://huggingface.co/intfloat/multilingual-e5-small/resolve/main/onnx/model.onnx"
  curl -fSL -o /data/.kiwi/models/multilingual-e5-small/tokenizer.json \
    "https://huggingface.co/intfloat/multilingual-e5-small/resolve/main/tokenizer.json"
  chown -R kiwi:kiwi /data/.kiwi/models
'
```

> **Note:** ONNX Runtime v1.28+ supports both x86_64 and ARM64 Linux. The `--platform`
> flag is omitted from `docker build` so it builds natively for your architecture.
> For cross-compilation (e.g. building ARM64 image on x86_64), add
> `--platform linux/arm64` and ensure `docker buildx` is configured.

### Alternative: Ollama embedder (simpler than ONNX)

If you prefer not to build a custom Docker image, install [Ollama](https://ollama.ai) and use it as embedder. Ollama runs as a separate service and the KiwiFS official image connects to it.

**Pros vs ONNX:**
| Aspect | ONNX (built-in) | Ollama (sidecar) |
|--------|----------------|------------------|
| Docker setup | Needs custom build | Official image works |
| Extra service | No | Yes, Ollama on port 11434 |
| Model size | 449MB (multilingual-e5-small) | 137MB (nomic-embed-text) |
| RAM usage | ~200MB | ~200MB |
| CPU arch | x86_64 + ARM64 | x86_64 + ARM64 |
| Multi-language | ✅ (e5-small trained for 100+ langs) | ✅ (nomic-embed-text supports 100+ langs) |
| GPU acceleration | CPU only (in this setup) | CPU + CUDA + Metal |

**Config:**

```toml
[search.vector.embedder]
provider = "ollama"
base_url = "http://localhost:11434"
model = "nomic-embed-text"
timeout = "120s"
```

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull nomic-embed-text

# Restart KiwiFS container with Ollama network access
docker run -d \
  --name kiwifs \
  --restart unless-stopped \
  --add-host host.docker.internal:host-gateway \
  -p 3333:3333 \
  -v ./my-vault:/data \
  ameliaanhlam/kiwifs
```

See [KiwiFS vector search docs](https://docs.kiwifs.com/configuration#vector-search) for all embedder options.

---

## Mercury Configuration

Mercury is the **AI bridge** between your notes, your projects, and your messaging apps.
It connects Telegram to both KiwiFS (notes/wiki) and your project management backend.

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

## Mercury Skills — Notes + Projects

Mercury's skills are the bridge between your notes and your projects.
These SKILL.md files teach Mercury how to interact with both worlds.

### Notes Search

**File:** `skills/notes-search/SKILL.md`

Read, write, and search your markdown vault via Telegram or CLI.

```
"what did I note this week?"
"save this idea: ..."
"search for authentication patterns"
```

### Wiki Compilation

**File:** `skills/wiki-compilation/SKILL.md`

Scheduled nightly. Reads raw notes, extracts entities and concepts,
maintains the wiki layer.

```
"compile the wiki"
"ingest today notes"
```

### Project Management

**File:** `skills/project-manager/SKILL.md`

Pluggable backend that lets Mercury manage **tasks and projects** through the same Telegram chat you use for notes. Supports multiple adapters:

| Adapter | Backend | Access | Status |
|---------|---------|--------|--------|
| `mercury-native` | Mercury Kanban | Built-in | ✅ No setup needed |
| `multica` | [multica.ai](https://multica.ai) | CLI (`multica`) | ✅ Tested (production) |
| `runfusion` | [runfusion.ai](https://runfusion.ai) | CLI (`fn`) | ⚠️ Template (needs validation) |
| `multigent` | [multigent](https://github.com/multigent/multigent) | CLI (`multigent`) | ⚠️ Template (needs validation) |

```yaml
# ~/.mercury/project-manager-config.yaml
adapter: mercury-native  # or multica, runfusion, multigent
```

> **In practice:** You text Mercury on Telegram "add task 'review PR' to project Apollo"
> and Mercury creates the task via the configured adapter. Same chat where you ask
> "what did I note yesterday?" — notes and projects, one bridge.

---

## Local Search (ZENITH)

For offline search when the server is unreachable, you can use
[ZENITH](https://github.com/shramanb113/ZENITH) — a hybrid search engine
(lexical + fuzzy + semantic) that runs locally with an embedded ONNX model.
No API key needed.

```bash
go install github.com/shramanb113/ZENITH@latest
zenith index ./my-vault/raw
zenith search --embedder auto "query here"
```

ZENITH is optional. The primary search is via KiwiFS API on the server.

---

## LLM Wiki Pattern

The vault follows the [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
pattern: raw sources compiled into structured, interlinked wiki pages.

Inspired by [nashsu/llm_wiki](https://github.com/nashsu/llm_wiki) (purpose/schema
split, two-step ingest), [SamurAIGPT/llm-wiki-agent](https://github.com/SamurAIGPT/llm-wiki-agent)
(health/lint boundary, post-ingest validation, graph health report), and
[OpenKnowledge](https://openknowledge.ai) (provisional/canonical split).

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
├── purpose.md              # Why the vault exists
├── schema.md               # Structural rules
├── AGENTS.md               # Agent instructions
├── raw/                    # Source documents (immutable)
│   ├── Daily/              # Daily notes YYYY-MM-DD.md
│   ├── Topics/             # Reference topics [[Topics/name]]
│   ├── People/             # People (classified by tags)
│   ├── Projects/           # Projects (classified by tags)
│   └── ...                 # Any categories
├── wiki/                   # Agent-maintained wiki
│   ├── index.md            # Page catalog
│   ├── log.md              # Chronological record
│   ├── overview.md         # Living synthesis
│   ├── sources/            # Source summaries
│   ├── entities/           # People, companies, products
│   ├── concepts/           # Ideas, frameworks, methods
│   ├── syntheses/          # Saved query answers
│   ├── drafts/             # Provisional research
│   └── curated/            # Canonical articles
├── .kiwi/
│   └── config.toml         # KiwiFS config
└── index.md                # Vault home
```

### Navigation: Wikilinks over tags

Use `[[Topics/name]]` instead of `#tags` for all cross-references.
Wikilinks are bidirectional, contextual, and create the knowledge graph.
KiwiFS supports nested paths: `[[Topics/pai/filho]]`.

Tags should only be used as metadata in frontmatter (e.g., `confidence: low`).

### Knowledge graph

KiwiFS generates a real-time knowledge graph from all `[[wikilinks]]`:

```bash
# Full graph
curl http://localhost:3333/api/kiwi/graph

# Graph analytics (PageRank, communities, orphans)
curl http://localhost:3333/api/kiwi/graph/analytics?limit=20

# Backlinks for a page
curl http://localhost:3333/api/kiwi/backlinks?path=Topics/ProjectManagement
```

The web UI (port 3333) has an interactive graph view with Sigma.js + ForceAtlas2.

### Daily note format

```markdown
# 2026-07-28

## 09h15 - Meeting with Client
- Discussed project timeline
- Action items: send proposal by Friday
- [[Topics/ProjectManagement]]

## 14h30 - Research Notes
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

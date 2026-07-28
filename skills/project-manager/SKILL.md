---
name: project-manager
description: >
  Query and manage projects, issues, and tasks.
  Supports pluggable backends: multica, runfusion, multigent, mercury-native.
  Configure which backend to use in project-manager-config.yaml.
version: 1.0.0
intents:
  - list projects
  - project status
  - create task
  - list issues
  - list agents
  - project management
  - what projects
  - active projects
  - create issue
  - active adapter
  - switch adapter
  - which adapter
  - change project backend
allowed-tools:
  - exec
  - bash
---

# Project Manager Skill

## Overview

This skill provides a unified interface for project management.
It supports multiple backends via adapters. Configure your backend in:

```
~/.mercury/project-manager-config.yaml
```

## CRITICAL: Docker volume permissions

The KiwiFS vault is inside a Docker container. NEVER run sed, echo >, or
other shell file-writing commands against the vault filesystem.
Use curl to the KiwiFS REST API (port 3333) or `docker exec` instead.

Example config:
```yaml
adapter: multica  # or: runfusion, multigent, mercury-native
```

## Adapter: multica

Requires: `multica` CLI installed and authenticated.

### Commands

List projects:
```bash
multica project list --output json
```

Get project details:
```bash
multica project get <id> --output json
```

List issues:
```bash
multica issue list --workspace-id <workspace_id> --output json
```

Create issue:
```bash
multica issue create --workspace-id <workspace_id> --title "..." --description "..."
```

List agents:
```bash
multica agent list --output json
```

List agent tasks:
```bash
multica agent tasks <agent_id> --output json
```

### Setup

1. Install via the official multica CLI installer
2. Authenticate: `multica login`
3. Get workspace ID: `multica workspace list`

---

## Adapter: runfusion (Fusion)

Requires: Fusion dashboard running on port 4040 (or configured).
Uses the REST API directly (more reliable than CLI for web-created data).

### Configuration

Set the Fusion API base URL:

```bash
FUSION_API="http://127.0.0.1:4040"  # Local server
```

### Commands (CLI)

List all registered projects:
```bash
fn project list
```

List tasks for a project (REQUIRED: use --project flag):
```bash
fn task list --project <project-name>
```

Create task:
```bash
fn task create "Task title" --project <project-name>
```

Show task details:
```bash
fn task show <task-id>
```

### Setup

1. Install: `npm install -g @runfusion/fusion`
2. Register a project: `fn project add <name> <path>`
3. Start dashboard: `fn dashboard --port 4040 --host 100.120.175.47 --no-auth`

---

## Adapter: multigent

Requires: `multigent` CLI installed. Build from https://github.com/multigent/multigent.

### Commands

```bash
multigent project list
multigent project show <id>
multigent task list --project <id>
multigent task show <id>
multigent agent list
multigent list --help      # Generic list command
multigent create           # Create resources
multigent run              # Execute tasks
```

### Setup

Build from source or download a release from the multigent repository.

---

## Adapter: mercury-native

Uses Mercury's built-in Kanban boards and Goals.
No external dependencies.

### Commands

Mercury Kanban commands (in-chat):
```
Create a task: "add task 'review PR' to board 'Sprint 24'"
List tasks: "show my tasks"
Move task: "move 'review PR' to 'In Progress'"
```

### Setup

No setup required. Mercury Kanban is available by default.

---

## Adapter management

The config file is at `~/.mercury/project-manager-config.yaml`.

### Check active adapter

When the user asks "qual adapter está ativo?" or "which backend am I using?":

```bash
cat ~/.mercury/project-manager-config.yaml
```

Respond with the current adapter name and the available options.

### Switch adapter

When the user asks "troca pra runfusion" or "switch to multigent":

1. Check that the target CLI/API is available
2. Update the config file:
   ```bash
   echo "adapter: <name>" > ~/.mercury/project-manager-config.yaml
   ```
3. Confirm the change and run a quick test command to verify

### List all projects (active adapter)

```bash
# Read the config to determine which adapter to use
CONFIG=$(cat ~/.mercury/project-manager-config.yaml)
# Parse adapter name and run its list command
```

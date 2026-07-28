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

## Adapter: runfusion

Requires: API key configured in environment variable `RUNFUSION_API_KEY`.

### Commands

List projects:
```bash
curl -s -H "Authorization: Bearer $RUNFUSION_API_KEY" \
  "https://api.runfusion.ai/v1/projects"
```

Get project:
```bash
curl -s -H "Authorization: Bearer $RUNFUSION_API_KEY" \
  "https://api.runfusion.ai/v1/projects/<id>"
```

Create task:
```bash
curl -s -X POST -H "Authorization: Bearer $RUNFUSION_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"project_id":"<id>","title":"...","description":"..."}' \
  "https://api.runfusion.ai/v1/tasks"
```

### Setup

1. Get API key from https://runfusion.ai/settings
2. Set environment: `export RUNFUSION_API_KEY="sk-..."`

---

## Adapter: multigent

Requires: `multigent` CLI or API key.

### Commands

List agents:
```bash
multigent agent list
```

List tasks:
```bash
multigent task list --project <id>
```

Create task:
```bash
multigent task create --project <id> --title "..." --description "..."
```

### Setup

```bash
pip install multigent
multigent config set api-key <your-key>
```

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

## Usage

When the user asks about projects, issues, or tasks:

1. Read the config to determine which adapter to use
2. Run the appropriate commands for that adapter
3. Format the results and respond

For write operations (create, update), confirm with the user before executing.

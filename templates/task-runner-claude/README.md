# Claude Code Tasks — Task Runner Template

Ephemeral task runner for executing prompts from the Coder Tasks UI via Claude Code on Kubernetes.

## Task Runner vs Workspace

Unlike workspace templates (e.g. `ai-dev`), task runners are designed to receive a prompt from the Tasks UI and execute it autonomously. They use `coder_ai_task` + `data.coder_task` resources to wire the Tasks UI to the Claude Code agent.

## Included Apps

| App | Description |
|---|---|
| **Claude Code** | Anthropic coding agent (registry module — handles install, AgentAPI, web UI, task reporting) |
| **code-server** | VS Code in the browser |
| **mux** | Terminal multiplexer with AI provider switching UI |
| **Preview** | Authenticated subdomain proxy for app previews |

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `system_prompt` | — | Instructions for Claude Code |
| `setup_script` | — | Shell script to run before Claude starts |
| `preview_port` | 3000 | Port for the app preview |
| `cpu` | 4 | CPU cores (2, 4, 8) |
| `memory` | 8 | Memory in GB (4, 8, 12, 16, 24) |
| `disk_size` | 20 | PVC size in GB (immutable after creation) |
| `git_repo` | — | Repository to clone on start |

No `dotfiles_url` parameter — task runners are ephemeral.

## AI Bridge

All AI tools authenticate through Coder's AI Bridge using the workspace owner's session token. No external API keys needed.

- **Anthropic**: `<access_url>/api/v2/aibridge/anthropic`
- **OpenAI**: `<access_url>/api/v2/aibridge/openai`

The `claude-code` registry module handles `CLAUDE_API_KEY` and `ANTHROPIC_BASE_URL` configuration via AI Bridge. `OPENAI_API_KEY` is set via `coder_env` for mux/other tools.

## Infrastructure

- **Image**: `codercom/enterprise-node:ubuntu`
- **Namespace**: `coder-workspaces` (configurable via `namespace` variable)
- **PVC**: `coder-<workspace-id>-home` mounted at `/home/coder`
- **Security**: runs as UID 1000, pod anti-affinity for spread scheduling

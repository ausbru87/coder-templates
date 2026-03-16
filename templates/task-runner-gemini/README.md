# Gemini Tasks — Task Runner Template

Ephemeral task runner for executing prompts from the Coder Tasks UI via Google Gemini CLI on Kubernetes.

## Task Runner vs Workspace

Unlike workspace templates (e.g. `ai-dev`), task runners are designed to receive a prompt from the Tasks UI and execute it autonomously. They use `coder_ai_task` + `data.coder_task` resources to wire the Tasks UI to the Gemini CLI agent.

## Included Apps

| App | Description |
|---|---|
| **Gemini CLI** | Google coding agent (registry module — handles install, AgentAPI, web UI, task reporting) |
| **code-server** | VS Code in the browser |
| **mux** | Terminal multiplexer |
| **Preview** | Authenticated subdomain proxy for app previews |

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `system_prompt` | — | Instructions for Gemini CLI |
| `setup_script` | — | Shell script to run before Gemini starts |
| `preview_port` | 3000 | Port for the app preview |
| `cpu` | 4 | CPU cores (2, 4, 8) |
| `memory` | 8 | Memory in GB (4, 8, 12, 16, 24) |
| `disk_size` | 20 | PVC size in GB (immutable after creation) |
| `git_repo` | — | Repository to clone on start |

No `dotfiles_url` parameter — task runners are ephemeral.

## ⚠️ AI Bridge Not Supported

**Gemini CLI does not support Coder AI Bridge.** Authentication requires a real Google Gemini API key set at template push time as a Terraform variable.

### Setup: Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/apikey) and create an API key.
2. Push the template with the key as a variable:

```bash
coder templates push task-runner-gemini \
  --variable gemini_api_key=<your-key> \
  --directory templates/task-runner-gemini \
  --yes
```

The key is stored as a sensitive Terraform variable and injected into the workspace pod by the `gemini` module. It is not visible to workspace users.

> **Without `gemini_api_key` set, tasks will fail** — Gemini CLI cannot authenticate headlessly without it.

## Infrastructure

- **Image**: `codercom/enterprise-node:ubuntu`
- **Namespace**: `coder-workspaces` (configurable via `namespace` variable)
- **PVC**: `coder-<workspace-id>-home` mounted at `/home/coder`
- **Security**: runs as UID 1000, pod anti-affinity for spread scheduling

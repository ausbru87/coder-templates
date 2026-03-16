# Kiro Tasks — Task Runner Template

Ephemeral task runner for executing prompts from the Coder Tasks UI via Kiro CLI on Kubernetes.

## Task Runner vs Workspace

Unlike workspace templates (e.g. `ai-dev`), task runners are designed to receive a prompt from the Tasks UI and execute it autonomously. They use `coder_ai_task` + `data.coder_task` resources to wire the Tasks UI to the Kiro CLI agent.

## Included Apps

| App | Description |
|---|---|
| **Kiro CLI** | AWS/Anthropic coding agent (registry module — handles install, AgentAPI, web UI, task reporting) |
| **code-server** | VS Code in the browser |
| **mux** | Terminal multiplexer |
| **Preview** | Authenticated subdomain proxy for app previews |

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `system_prompt` | — | Instructions for Kiro CLI |
| `setup_script` | — | Shell script to run before Kiro starts |
| `preview_port` | 3000 | Port for the app preview |
| `cpu` | 4 | CPU cores (2, 4, 8) |
| `memory` | 8 | Memory in GB (4, 8, 12, 16, 24) |
| `disk_size` | 20 | PVC size in GB (immutable after creation) |
| `git_repo` | — | Repository to clone on start |

No `dotfiles_url` parameter — task runners are ephemeral.

## ⚠️ AI Bridge Not Supported

**Kiro CLI does not support Coder AI Bridge.** Authentication requires a pre-authenticated credential tarball generated from a machine where `kiro-cli` has already been logged in. This tarball is injected as a sensitive Terraform variable at template push time.

### Setup: Kiro CLI Auth Tarball

**Each user who pushes the template needs their own auth tarball tied to their Kiro account.**

#### Step 1 — Install and authenticate Kiro CLI locally

```bash
# Install kiro-cli (adjust for your OS)
curl -fsSL https://desktop-release.q.us-east-1.amazonaws.com/latest/kiro-cli-linux-x64.tar.gz | tar -xz -C ~/.local/bin

# Authenticate (opens browser for AWS Builder ID, IAM Identity Center, GitHub, or Google)
kiro-cli login
```

#### Step 2 — Generate the auth tarball

```bash
# Compress the Kiro credentials directory with zstd and base64-encode it
tar -C ~/.local/share -c kiro-cli | zstd | base64 -w0
```

Copy the output — this is your `kiro_auth_tarball` value.

#### Step 3 — Push the template with the tarball

```bash
coder templates push task-runner-kiro \
  --variable kiro_auth_tarball=<base64-tarball> \
  --directory templates/task-runner-kiro \
  --yes
```

The tarball is stored as a sensitive Terraform variable and extracted into the workspace pod at runtime by the `kiro-cli` module. It is not visible to workspace users.

> **Without `kiro_auth_tarball` set, tasks will fail** — Kiro CLI cannot authenticate interactively inside a container pod.

#### Notes

- **Credential rotation**: Kiro CLI credentials may expire. Regenerate and re-push the template when tasks start failing with auth errors.
- **One tarball per account**: The tarball is tied to the account that ran `kiro-cli login`. All task workspaces created from this template will run as that identity.
- **Security**: Keep the tarball secret — it contains authentication credentials. Never commit it to version control.

## Infrastructure

- **Image**: `codercom/enterprise-node:ubuntu`
- **Namespace**: `coder-workspaces` (configurable via `namespace` variable)
- **PVC**: `coder-<workspace-id>-home` mounted at `/home/coder`
- **Security**: runs as UID 1000, pod anti-affinity for spread scheduling

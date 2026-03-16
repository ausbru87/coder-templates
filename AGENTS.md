# Coder Templates — Agent Guide

## Project Overview

Coder template repository deployed to dev.zambruhni.com via GitLab CI. Contains the `ai-dev` template — a minimal AI-focused Kubernetes development environment.

## Repository Structure

- `templates/ai-dev/main.tf` — The ai-dev workspace template
- `templates/ai-dev/metadata.json` — Template display name and icon
- `templates/ai-dev/scripts/claude/install.sh` — Claude Code post-install config
- `templates/aws-dev/main.tf` — The aws-dev workspace template (AWS + Kiro)
- `templates/aws-dev/metadata.json` — Template display name and icon
- `templates/task-runner-claude/main.tf` — Claude Code task runner template
- `templates/task-runner-claude/metadata.json` — Task runner display name, icon, and slug
- `templates/task-runner-codex/main.tf` — Codex task runner template
- `templates/task-runner-codex/metadata.json` — Task runner display name, icon, and slug
- `versions.json` — Module version registry
- `scripts/` — Automation scripts (cleanup, version check/update)
- `.gitlab-ci.yml` — Pipeline config

## Task Runner: task-runner-claude

Ephemeral task runner that receives prompts from the Coder Tasks UI and executes them via Claude Code. Uses `coder_ai_task` + `data.coder_task` resources. The `claude-code` registry module (v4.8.0) handles installation, AgentAPI, web UI, and task reporting. Located at `templates/task-runner-claude/`.

## Task Runner: task-runner-codex

Ephemeral task runner that receives prompts from the Coder Tasks UI and executes them via OpenAI Codex. Uses `coder_ai_task` + `data.coder_task` resources. The `codex` registry module (v4.3.0, from `coder-labs` org) handles installation, AgentAPI, web UI, and task reporting. Located at `templates/task-runner-codex/`.

## Template: aws-dev

Provisions a Kubernetes pod with:
- **Kiro Desktop IDE** — primary AI coding agent (external app, `kiro://` protocol)
- **VS Code Desktop** — VS Code Desktop connection (external app)
- **code-server** — VS Code in the browser
- **AWS CDK CLI** — installed via npm on startup
- **Kiro CLI** — installed via curl on startup

Kiro authenticates independently via AWS Builder ID, IAM Identity Center, GitHub, or Google. No AI Bridge or Coder API keys are needed.

## Template: ai-dev

Provisions a Kubernetes pod with:
- **code-server** — VS Code in the browser
- **mux** — terminal multiplexer with AI provider UI
- **Claude Code CLI** — Anthropic coding agent (installed via npm)
- **Codex CLI** — OpenAI coding agent (installed via npm)

All AI tools authenticate through Coder's AI Bridge using the workspace owner's session token. No external API keys needed.

### AI Bridge

AI Bridge URLs are constructed from `data.coder_workspace.me.access_url`:
- Anthropic: `<access_url>/api/v2/aibridge/anthropic`
- OpenAI: `<access_url>/api/v2/aibridge/openai`

The session token (`data.coder_workspace_owner.me.session_token`) is injected as `CLAUDE_API_KEY` and `OPENAI_API_KEY` via `coder_env` resources.

### Startup Script

Installs CLIs and writes config files on every workspace start:
1. Install Claude Code + Codex via `npm install -g`
2. Add npm global bin to PATH
3. Write `~/.claude/settings.json` and `~/.claude.json`
4. Write `~/.codex/config.toml` (AI Bridge provider)
5. Write `~/.mux/providers.jsonc` (Anthropic provider)

### Module Versions

Terraform requires literal version strings in `module` blocks. `versions.json` is the source of truth; `scripts/update-module-versions.sh` uses sed to propagate versions into `.tf` files.

## Essential Commands

```bash
# Validate
cd templates/ai-dev && terraform fmt -check && terraform init -backend=false && terraform validate

# Push
coder templates push ai-dev --directory templates/ai-dev --yes

# Check module versions
./scripts/check-module-versions.sh
```

## Conventions

- Container image: always `codercom/enterprise-node:ubuntu`
- PVC naming: `coder-${data.coder_workspace.me.id}-home` (immutable, safe)
- All web apps use `subdomain = true` for XSS prevention
- External auth: GitHub with `optional = true`
- AI Bridge URLs must be constructed from `data.coder_workspace.me.access_url` — never hardcode

## Anti-Patterns to Avoid

- Don't hardcode AI Bridge URLs — use `data.coder_workspace.me.access_url`
- Don't use `data.coder_workspace_owner.me.name` in PVC names — use workspace ID
- Don't add `version` variables for modules — Terraform requires literal strings

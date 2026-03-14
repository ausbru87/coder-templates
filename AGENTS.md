# Coder Templates — Agent Guide

## Project Overview

Coder template repository deployed to dev.zambruhni.com via GitLab CI. Contains the `ai-dev` template — a minimal AI-focused Kubernetes development environment.

## Repository Structure

- `templates/ai-dev/main.tf` — The template (all workspace config)
- `templates/ai-dev/icon.txt` — Template icon (Coder built-in path)
- `templates/ai-dev/scripts/claude/install.sh` — Claude Code post-install config
- `versions.json` — Module version registry
- `scripts/` — Automation scripts (cleanup, version check/update)
- `.gitlab-ci.yml` — Pipeline config

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

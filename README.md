# Coder Templates

Coder workspace templates for Kubernetes-based development environments. Deployed via GitLab CI to [dev.zambruhni.com](https://dev.zambruhni.com).

## Templates

### `ai-dev`

Minimal AI-focused development environment.

**Included:**
- code-server (VS Code in the browser)
- mux (terminal multiplexer with AI provider UI)
- Claude Code CLI (Anthropic coding agent)
- Codex CLI (OpenAI coding agent)

All AI tools authenticate through Coder's [AI Bridge](https://coder.com/docs/guides/using-ai-tools-in-coder) — no external API keys needed. The workspace owner's Coder session token is used as the API key, and requests are proxied through the Coder server.

**Parameters:**

| Parameter | Default | Description |
|---|---|---|
| `cpu` | 4 | CPU cores (2, 4, 8) |
| `memory` | 8 | Memory in GB (4, 8, 12, 16, 24) |
| `disk_size` | 20 | PVC size in GB (immutable after creation) |
| `dotfiles_url` | — | Git dotfiles repo URL |
| `git_repo` | — | Repository to clone on start |

## Repository Structure

```
coder-templates/
├── .gitlab-ci.yml                    # CI: discover → validate → push
├── versions.json                     # Module version registry
├── scripts/
│   ├── check-module-versions.sh      # Compare versions.json vs Coder registry
│   ├── update-module-versions.sh     # Auto-update versions + open GitLab MR
│   └── cleanup-coder.sh             # Wipe instance and push fresh template
└── templates/
    └── ai-dev/
        ├── main.tf                   # Template definition
        ├── metadata.json             # Display name and icon
        └── scripts/claude/install.sh # Claude Code post-install config
```

## CI Pipeline

Runs on GitLab CI at gitlab.zambruhni.com. Any directory under `templates/` containing a `main.tf` is automatically discovered and processed.

| Stage | Trigger | Description |
|---|---|---|
| `discover` | MR or push to main | Detect changed templates via git diff |
| `validate` | After discover | `terraform fmt -check`, `init`, `validate`, plan check |
| `push` | Main branch only | `coder templates push` with auto-activate and icon |
| `check-versions` | Weekly schedule or manual | Check Coder registry for module updates |

**Required CI variables** (set in GitLab):
- `CODER_URL` — Coder instance URL
- `CODER_SESSION_TOKEN` — Coder API token

## Creating a Workspace

```bash
coder login https://dev.zambruhni.com
# Via CLI
coder create my-workspace --template ai-dev
# Or use the web UI at https://dev.zambruhni.com
```

## AI Bridge Environment Variables

These are set automatically on every workspace:

| Variable | Purpose |
|---|---|
| `CLAUDE_API_KEY` | Session token for Claude Code CLI |
| `OPENAI_API_KEY` | Session token for Codex CLI |
| `ANTHROPIC_BASE_URL` | AI Bridge Anthropic endpoint |
| `ANTHROPIC_API_BASE` | AI Bridge Anthropic endpoint (alt) |
| `OPENAI_BASE_URL` | AI Bridge OpenAI endpoint |
| `ANTHROPIC_MODEL` | Default Claude model |
| `ANTHROPIC_SMALL_FAST_MODEL` | Default fast model |

## Module Version Management

`versions.json` tracks all Coder registry module versions used by templates.

```bash
# Check for outdated modules
./scripts/check-module-versions.sh

# Auto-update versions and open GitLab MR
GITLAB_PROJECT_ID=123 GITLAB_TOKEN=xxx ./scripts/update-module-versions.sh
```

## Local Development

```bash
cd templates/ai-dev

# Format, init, validate
terraform fmt -check
terraform init -backend=false
terraform validate

# Push manually
coder login https://dev.zambruhni.com
coder templates push ai-dev --directory templates/ai-dev --yes

# Full cleanup + fresh push
./scripts/cleanup-coder.sh
```

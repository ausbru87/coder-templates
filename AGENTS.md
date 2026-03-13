# Coder Templates — Agent Guide

## Project Overview

Single Coder template (`templates/universal/`) deployed to dev.zambruhni.com via GitLab CI. One template with feature toggles replaces multiple specialized templates.

## Repository Structure

- `templates/universal/main.tf` — The template (all workspace config)
- `templates/universal/scripts/claude/install.sh` — Claude Code post-install
- `versions.json` — Module version registry
- `scripts/` — Automation scripts (cleanup, version check/update)
- `ci/discover_templates.py` — CI helper for change detection
- `.gitlab-ci.yml` — Pipeline config

## Key Patterns

### Conditional Modules
Modules use `count` with locals for feature toggling:
```hcl
count = local.enable_ai ? data.coder_workspace.me.start_count : 0
```

### Startup Script
Uses `%{if}` / `%{endif}` Terraform template directives for conditional install blocks. Order matters: base packages → GitHub CLI → AI config → languages → devsecops → desktop → starship.

### Desktop Mode
When `enable_desktop = true`, XFCE is installed in the container command (before agent init) so KasmVNC finds a working desktop environment.

### AI Bridge
All AI tools authenticate via Coder session token through AI Bridge URLs (`/api/v2/aibridge/anthropic` and `/api/v2/aibridge/openai`). No external API keys needed.

### Module Versions
Terraform requires literal version strings in `module` blocks. `versions.json` is the source of truth; `scripts/update-module-versions.sh` uses sed to propagate versions into `.tf` files.

## Essential Commands

```bash
# Validate
cd templates/universal && terraform fmt -check && terraform init -backend=false && terraform validate

# Push
coder templates push universal --directory templates/universal --yes

# Check module versions
./scripts/check-module-versions.sh
```

## Conventions

- Container image: always `codercom/enterprise-node:ubuntu`
- PVC naming: `coder-${data.coder_workspace.me.id}-home` (immutable, safe)
- All web apps use `subdomain = true` for XSS prevention
- `apt_get()` helper retries on dpkg lock (parallel coder_script resources)
- External auth: both GitHub and GitLab with `optional = true`
- Single AI toggle (`enable_ai_tools`) controls all AI modules as a group

## Anti-Patterns to Avoid

- Don't split into multiple templates — use feature toggles
- Don't hardcode AI Bridge URLs — use `data.coder_workspace.me.access_url`
- Don't use `data.coder_workspace_owner.me.name` in PVC names — use workspace ID
- Don't add `version` variables for modules — Terraform requires literal strings
- Don't skip `apt_get` retry wrapper in startup scripts — dpkg lock conflicts are common

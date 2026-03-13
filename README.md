# Coder Templates (dev.zambruhni.com)

Single consolidated Coder template for Kubernetes-based development workspaces. Deployed via GitLab CI to [dev.zambruhni.com](https://dev.zambruhni.com).

## Template: `universal`

One template with feature toggles instead of multiple specialized templates.

### Parameters

| Parameter | Type | Default | Immutable | Description |
|---|---|---|---|---|
| `dotfiles_url` | string | `""` | yes | Git dotfiles repo URL |
| `git_repo` | string | `""` | yes | Repository to clone on start |
| `cpu` | number | `4` | no | CPU cores (2, 4, 8) |
| `memory` | number | `8` | no | Memory in GB (4, 8, 12, 16, 24) |
| `disk_size` | number | `20` | yes | PVC size in GB (10, 20, 50) |
| `enable_ai_tools` | bool | `true` | yes | Claude Code, mux, aider, codex, coder-login |
| `enable_desktop` | bool | `false` | yes | XFCE + KasmVNC + Chrome + Terminator |
| `enable_devsecops` | bool | `false` | yes | terraform, kubectl, helm, cloud CLIs, security scanners |
| `install_python` | bool | `true` | yes | Python 3 + pip + poetry |
| `install_node` | bool | `true` | yes | Node.js global packages (pnpm, typescript, eslint) |
| `install_java` | bool | `false` | yes | OpenJDK 21 + Maven + Gradle |
| `install_go` | bool | `false` | yes | Go + gopls + delve |
| `install_rust` | bool | `false` | yes | Rust via rustup |
| `enable_filebrowser` | bool | `false` | yes | Web file manager |
| `enable_vscode_desktop` | bool | `false` | yes | VS Code Desktop connector |
| `enable_cursor` | bool | `false` | yes | Cursor IDE connector |

### Always included
- code-server (web VS Code) with Roo Code extension (when AI enabled)
- GitHub CLI
- Starship prompt
- Base dev tools (git, curl, jq, ripgrep, fd, bat, fzf, direnv, build-essential)

### AI tools (when `enable_ai_tools = true`)
All AI tools use Coder's AI Bridge — no external API keys needed.
- **Claude Code** — AI coding agent in browser
- **mux** — terminal multiplexer with AI provider config
- **aider** — AI pair programming
- **codex** — OpenAI coding agent
- **coder-login** — automatic Coder CLI auth
- **Roo Code** — VS Code extension (auto-configured)

## Repository Structure

```
coder-templates/
├── .gitlab-ci.yml          # CI pipeline: discover → validate → push → check-versions
├── versions.json           # Module version registry (single source of truth)
├── ci/
│   └── discover_templates.py
├── scripts/
│   ├── check-module-versions.sh   # Compare versions.json vs Coder registry
│   ├── update-module-versions.sh  # Auto-update versions + open GitLab MR
│   └── cleanup-coder.sh           # Wipe instance and push fresh template
└── templates/
    └── universal/
        ├── main.tf
        └── scripts/claude/install.sh
```

## CI Pipeline

Runs on GitLab CI at gitlab.zambruhni.com.

| Stage | Trigger | Description |
|---|---|---|
| `discover` | MR or push to main | Detect changed templates via git diff |
| `validate` | After discover | `terraform fmt -check`, `init`, `validate`, plan check |
| `push` | Main branch only | `coder templates push` with auto-activate |
| `check-versions` | Weekly schedule or manual | Check Coder registry for module updates |

### CI Variables (set in GitLab)
- `CODER_URL` — Coder instance URL
- `CODER_SESSION_TOKEN` — Coder API token

## Module Version Management

`versions.json` tracks all Coder registry module versions. Scripts in `scripts/` automate checking and updating:

```bash
# Check for outdated modules
./scripts/check-module-versions.sh

# Auto-update versions and open MR
GITLAB_PROJECT_ID=123 GITLAB_TOKEN=xxx ./scripts/update-module-versions.sh
```

## Local Development

```bash
# Validate
cd templates/universal
terraform fmt -check
terraform init -backend=false
terraform validate

# Push manually
coder login https://dev.zambruhni.com
coder templates push universal --directory templates/universal --yes

# Full cleanup + fresh push
./scripts/cleanup-coder.sh
```

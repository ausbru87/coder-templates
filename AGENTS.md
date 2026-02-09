You are an experienced, pragmatic software engineering AI agent. Do not over-engineer a solution when a simple one is possible. Keep edits minimal. If you want an exception to ANY rule, you MUST stop and get permission first.

# Universal GUI — Coder Workspace Template

## Project Overview

This repository contains **Coder workspace templates** for Kubernetes-based remote development environments provisioned via Terraform (HCL). It includes two templates:

- **`universal`** — A headless template with IDEs, AI tools, and language runtimes (no desktop GUI).
- **`universal-gui`** — Everything in `universal` plus an XFCE desktop via KasmVNC with Google Chrome, Terminator, and VS Code Desktop.

The templates are managed as part of a monorepo of Coder templates hosted on GitLab (`gitlab.zambruhni.com/lab/coder-templates`).

Templates in this repo follow the conventions established by the **official Coder documentation** and **example templates**. Use these as your primary references:

| Resource | URL |
|---|---|
| Template authoring docs | https://coder.com/docs/admin/templates |
| Tutorial: template from scratch | https://coder.com/docs/tutorials/template-from-scratch |
| Extending templates (parameters, modules, persistence) | https://coder.com/docs/admin/templates/extending-templates |
| Module registry (all official modules) | https://registry.coder.com/modules |
| Starter template registry | https://registry.coder.com/templates |
| Official example templates (GitHub) | https://github.com/coder/coder/tree/main/examples/templates |
| Coder internal templates repo | https://github.com/coder/templates |
| Terraform provider docs | https://registry.terraform.io/providers/coder/coder/latest/docs |

**Goals:**
- Provide a batteries-included developer workspace with IDEs, AI tools, and language runtimes.
- Deploy as a Kubernetes pod in the `coder-workspaces` namespace with persistent home-directory storage.
- Pre-configure AI tools (Claude Code, Aider, Roo Code) to route through the Coder AI Bridge.
- Follow official Coder template patterns so templates are recognizable to anyone familiar with the Coder ecosystem.

**Technology:**
- **Infrastructure-as-Code:** Terraform (HCL) with the `coder/coder` and `hashicorp/kubernetes` providers.
- **Runtime:** Kubernetes pod running the `codercom/enterprise-node:ubuntu` container image.
- **Coder platform:** Uses Coder modules from [registry.coder.com](https://registry.coder.com/modules) for IDE, AI, and utility integrations.

## Reference

### Important Files

| File | Purpose |
|---|---|
| `universal/main.tf` | Non-GUI template — IDEs, AI tools, and language runtimes without a desktop environment. |
| `universal-gui/main.tf` | GUI template — everything in `universal` plus XFCE desktop via KasmVNC, Google Chrome, Terminator, and VS Code Desktop. |

### Architecture

Both templates share the same structure. The `universal-gui` template adds desktop GUI resources on top.

```
universal/main.tf (non-GUI) & universal-gui/main.tf (GUI)
├── Providers        — coder, kubernetes
├── External Auth    — GitHub, GitLab (optional)
├── Parameters       — dotfiles URL, git repo, memory, language toggles (Node, Python, Go, Rust)
├── Agent            — startup script (apt packages, language installs, AI Bridge config, starship)
│   ├── env          — ANTHROPIC_BASE_URL, OPENAI_BASE_URL, ANTHROPIC_API_BASE
│   └── metadata     — CPU/mem/disk usage, git branch (displayed in Coder UI)
├── Env resources    — ANTHROPIC_API_KEY, OPENAI_API_KEY (session token)
├── IDE Modules      — code-server (web), VS Code Desktop, Cursor
├── AI Modules       — claude-code, aider
├── Utility Modules  — dotfiles, git-clone, filebrowser, mux
├── [GUI only] Desktop — KasmVNC module, XFCE install in container command
├── [GUI only] Desktop Apps — Google Chrome, Terminator, VS Code Desktop (in startup script)
└── K8s Resources    — PVC (20 Gi, /home/coder), Pod (1–4 CPU, configurable memory)
```

### Key Concepts

- **AI Bridge:** A Coder proxy (`https://dev.zambruhni.com/api/v2/aibridge/...`) that forwards Anthropic/OpenAI API requests using the workspace owner's session token. Environment variables and config files are set so all AI tools use it automatically.
- **Coder Modules:** Reusable Terraform modules published at [registry.coder.com](https://registry.coder.com/modules). Source format: `registry.coder.com/coder/<name>/coder`. Pinned by version.
- **Subdomain apps:** Modules that expose web UIs (code-server, mux, claude-code, aider, filebrowser) use `subdomain = true` to prevent XSS via origin isolation.

### Official Coder Template Ordering

All templates in this repo follow the canonical resource ordering used by the official starter templates at [registry.coder.com/templates](https://registry.coder.com/templates) and [github.com/coder/coder examples](https://github.com/coder/coder/tree/main/examples/templates):

1. `terraform` block — `required_providers`
2. `variable` blocks — infrastructure config not exposed to end users
3. `provider` blocks — platform providers
4. `data "coder_provisioner/workspace/workspace_owner"` — Coder data sources
5. `data "coder_external_auth"` — external auth (GitHub, GitLab)
6. `data "coder_parameter"` blocks — user-facing parameters
7. `resource "coder_agent"` — agent with `startup_script`, `env`, `metadata`
8. `resource "coder_env"` — environment variable resources
9. `module` blocks — registry modules (IDEs, AI tools, utilities)
10. Persistent storage resources — PVCs, volumes (with `lifecycle { ignore_changes = all }`)
11. Ephemeral compute resources — pods, containers (with `count = data.coder_workspace.me.start_count`)

### Available Coder Modules

When adding features, check the [module registry](https://registry.coder.com/modules) first — there's likely an official module. Key modules used or available:

**IDEs** — [code-server](https://registry.coder.com/modules/coder/code-server), [vscode-desktop](https://registry.coder.com/modules/coder/vscode-desktop), [vscode-web](https://registry.coder.com/modules/coder/vscode-web), [cursor](https://registry.coder.com/modules/coder/cursor), [windsurf](https://registry.coder.com/modules/coder/windsurf), [zed](https://registry.coder.com/modules/coder/zed), [kiro](https://registry.coder.com/modules/coder/kiro), [jetbrains](https://registry.coder.com/modules/coder/jetbrains), [jupyterlab](https://registry.coder.com/modules/coder/jupyterlab)

**AI Agents** — [claude-code](https://registry.coder.com/modules/coder/claude-code), [aider](https://registry.coder.com/modules/coder/aider), [goose](https://registry.coder.com/modules/coder/goose), [amazon-q](https://registry.coder.com/modules/coder/amazon-q), [mux](https://registry.coder.com/modules/coder/mux)

**Git & Dev Tools** — [git-clone](https://registry.coder.com/modules/coder/git-clone), [git-config](https://registry.coder.com/modules/coder/git-config), [dotfiles](https://registry.coder.com/modules/coder/dotfiles), [filebrowser](https://registry.coder.com/modules/coder/filebrowser), [coder-login](https://registry.coder.com/modules/coder/coder-login), [personalize](https://registry.coder.com/modules/coder/personalize)

**Remote Desktop** — [kasmvnc](https://registry.coder.com/modules/coder/kasmvnc), [windows-rdp](https://registry.coder.com/modules/coder/windows-rdp)

Always check the module's registry page for required/optional parameters before adding it.

## Essential Commands

All commands assume Terraform is installed (available in this workspace as `terraform`).

```bash
# Initialize Terraform providers and modules
cd universal && terraform init
cd universal-gui && terraform init

# Upgrade modules to latest compatible versions
cd universal && terraform init -upgrade
cd universal-gui && terraform init -upgrade

# Validate template syntax
cd universal && terraform validate
cd universal-gui && terraform validate

# Preview changes (dry-run) — requires Coder + K8s provider config
cd universal && terraform plan
cd universal-gui && terraform plan

# Format all .tf files (canonical style)
terraform fmt -recursive

# Check formatting without writing (CI-friendly)
terraform fmt -recursive -check
```

> **Note:** `terraform apply` is not run manually. The Coder platform applies the template when a workspace is created or updated. Use `terraform plan` and `terraform validate` for local verification.

### Pushing the Template to Coder

```bash
# Push as a Coder template (requires coder CLI + authentication)
coder templates push universal --directory universal
coder templates push universal-gui --directory universal-gui
```

## Patterns

Follow the patterns used by the official Coder starter templates at [registry.coder.com/templates](https://registry.coder.com/templates). When in doubt, look at the [Kubernetes starter template](https://registry.coder.com/templates/kubernetes) or the [Docker starter template](https://registry.coder.com/templates/docker) for reference.

### Single-file Template

The entire template lives in `universal/main.tf`. Do **not** split it into multiple `.tf` files unless the template grows significantly (500+ lines of a single logical concern). The current structure uses comment banners (`# ----`) to separate sections. This matches the pattern used by all official Coder starter templates, which each use a single `main.tf`.

### Required Data Sources

Every Coder template **must** include these three data sources (per the [official docs](https://coder.com/docs/admin/templates)):

```hcl
data "coder_provisioner" "me" {}     # Provisioner info (arch, OS)
data "coder_workspace" "me" {}       # Workspace state (name, start_count, id, transition)
data "coder_workspace_owner" "me" {} # Owner info (name, email, session_token)
```

### Agent Configuration

Name the agent `"main"` (consistent with official templates). Always include standard metadata blocks for the Coder dashboard. The official templates use numeric key prefixes for ordering:

```hcl
metadata {
  display_name = "CPU Usage"
  key          = "0_cpu_usage"
  script       = "coder stat cpu"
  interval     = 10
  timeout      = 1
}
```

Set Git identity env vars from the workspace owner (standard pattern in all official templates):

```hcl
env = {
  GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
  GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
}
```

### Module Usage

All modules come from [registry.coder.com](https://registry.coder.com/modules). The source format is:

```
registry.coder.com/coder/{module-name}/coder
```

**Version pinning:** Use exact version pins in this repo for stability. Check the module's registry page for the latest version. Official starter templates use `~> 1.0` (semver ranges) but we prefer exact pins for production predictability.

**Conditional start:** Every module must use `count = data.coder_workspace.me.start_count` so it's only active when the workspace is running:

```hcl
module "code-server" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/code-server/coder"
  version   = "1.4.2"
  agent_id  = coder_agent.main.id
  subdomain = true
}
```

### Ephemeral vs Persistent Resources

This is a critical pattern from the [official resource persistence docs](https://coder.com/docs/admin/templates/extending-templates/resource-persistence):

- **Compute resources** (pods, containers, VMs) are **ephemeral** — use `count = data.coder_workspace.me.start_count`.
- **Storage resources** (PVCs, volumes, disks) are **persistent** — always include `lifecycle { ignore_changes = all }`.
- **Volume names** must use immutable identifiers. Prefer `data.coder_workspace.me.id` over `.name` or owner name, which can change and destroy the volume.

```hcl
# ✅ Safe — workspace ID is immutable
name = "coder-${data.coder_workspace.me.id}-home"

# ❌ Dangerous — username/workspace name can change, destroying the volume
name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-home"
```

### Module Versioning

When updating a module:
1. Check the latest version at its [registry page](https://registry.coder.com/modules) (e.g., https://registry.coder.com/modules/coder/code-server).
2. Update the `version` field.
3. Run `terraform init -upgrade` to fetch the new version.
4. Run `terraform validate` to verify.

### Conditional Resources

Language installs and optional features use Terraform's `%{if ...}` template directives inside the startup script, and `count` expressions for module instantiation. Follow this same pattern for new optional features:

```hcl
# Conditional module (only instantiated if parameter is non-empty)
module "git-clone" {
  count    = data.coder_parameter.git_repo.value != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.2.3"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_repo.value
}
```

### Parameter Conventions

Follow the patterns from the [official parameter docs](https://coder.com/docs/admin/templates/extending-templates/parameters):

- `name` uses `snake_case`; `display_name` is Title Case, human-readable.
- Parameters that toggle feature installation use `type = "bool"` with sensible defaults (`true` for common tools, `false` for niche ones).
- Infrastructure params (region, disk size) are `mutable = false`; resource sizing params (cpu, memory) are `mutable = true`.
- Use `option` blocks to constrain choices. Use `validation` for numeric ranges.
- Parameters use an `icon` field pointing to Coder's built-in icon set (`/icon/<name>.svg` or `/emojis/{code}.png`).

### Kubernetes Labels

Label all K8s resources for tracking and cleanup, following the pattern from official templates:

```hcl
labels = {
  "app.kubernetes.io/name"     = "coder-workspace"
  "app.kubernetes.io/instance" = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  "app.kubernetes.io/part-of"  = "coder"
}
```

## Anti-Patterns

- **Do not hard-code API keys.** AI Bridge credentials are derived from `data.coder_workspace_owner.me.session_token`. Never embed real API keys in the template.
- **Do not use `subdomain = false` for web-facing apps.** All apps that expose a web UI must use `subdomain = true` to prevent XSS. This is called out in comments throughout the file.
- **Do not run `terraform apply` locally.** The Coder platform handles apply; manual apply against a real cluster can create orphaned resources.
- **Do not use `latest` for module versions.** Always pin to a specific version number.
- **Do not use mutable attributes in persistent resource names.** Username and workspace name can change — use `data.coder_workspace.me.id` for volume/disk names (see [resource persistence docs](https://coder.com/docs/admin/templates/extending-templates/resource-persistence)).
- **Do not forget `lifecycle { ignore_changes = all }` on persistent volumes.** Without this, Terraform may destroy user data on template updates.
- **Do not forget `count = data.coder_workspace.me.start_count` on compute resources and modules.** Without this, resources won't stop when the workspace stops.
- **Do not hard-code agent arch/OS.** Use `data.coder_provisioner.me.arch` instead.
- **Do not build features that a registry module already provides.** Check https://registry.coder.com/modules before writing custom `coder_app` resources or startup script logic.
- **Do not set excessive metadata intervals.** The formula for write load is `(metadata_count × running_agents × 2) / avg_interval` writes/sec. Keep intervals ≥10s for fast-changing metrics, ≥60s for slow ones.

## Code Style

- **Formatter:** `terraform fmt` (canonical Terraform style). Run before every commit.
- **Comments:** Use `# ----` banner lines to separate major sections. Use inline `#` comments for non-obvious decisions. Add registry links above modules: `# See https://registry.coder.com/modules/coder/code-server`.
- **Naming:** Terraform resource names use snake_case. Kubernetes resource names use kebab-case with `coder-{owner}-{workspace}` prefix.
- **Strings:** Use `<<-EOT ... EOT` heredocs for multi-line scripts. Use `"..."` for single-line values. Start startup scripts with `set -e`.
- **Agent name:** Use `"main"` (matches official convention).

## Commit and Pull Request Guidelines

### Before Committing

1. Run `terraform fmt -recursive` to fix formatting.
2. Run `cd universal && terraform validate` to check syntax.
3. Review the diff — ensure no secrets, API keys, or personal data are included.

### Commit Messages

Use the `type: message` convention (lowercase type, imperative mood):

```
feat: add Java language toggle parameter
fix: correct Python pip install flags for PEP 668
chore: bump claude-code module to v4.5.0
docs: update AI Bridge configuration comments
refactor: extract startup script sections into comments
```

Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `style`.

### Pull/Merge Requests

- Title should match the primary commit message.
- Description should explain **what** changed and **why**.
- If updating module versions, note the old → new version and link to the module's registry page.
- If adding a new parameter, explain the default value choice.
- If adding a new module, link to its registry page (e.g., `https://registry.coder.com/modules/coder/<name>`).
- After merge, push the updated template to Coder: `coder templates push universal --directory universal`.

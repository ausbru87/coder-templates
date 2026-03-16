# Contributing

Guide for adding and maintaining templates in this repository.

## Adding a New Template

### 1. Create the template directory

```
templates/<name>/
├── main.tf           # Required — template definition
├── README.md         # Recommended — what the template provides, parameters, env vars
├── metadata.json     # Recommended — display name and icon
└── scripts/          # Optional — helper scripts
```

CI automatically discovers any directory under `templates/` that contains a `main.tf`.

### 2. Required Terraform blocks

Every `main.tf` needs at minimum:

```hcl
terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "coder" {}
provider "kubernetes" {
  config_path = var.use_kubeconfig ? "~/.kube/config" : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
```

### 3. Add an icon

Create `templates/<name>/metadata.json` with display name and icon:

```json
{
  "display_name": "My Template",
  "icon": "/icon/code.svg"
}
```

After pushing, CI runs `coder templates edit` to apply these. Browse available built-in icons in the Coder UI template editor. Both fields are optional.

### 4. Track module versions

If your template uses Coder registry modules, add their versions to `versions.json`:

```json
{
  "code-server": "1.3.1",
  "your-module": "1.0.0"
}
```

The version check scripts (`check-module-versions.sh`, `update-module-versions.sh`) will then track updates for your modules.

## Adding a Task Runner

Task runners live under `templates/task-runner-<name>/` alongside regular templates.

### Structure

```
templates/task-runner-<name>/
├── main.tf           # Required — task runner definition
├── README.md         # Recommended — purpose, parameters, apps
└── metadata.json     # Required — must include "slug" field
```

### metadata.json

Use the `slug` field in `metadata.json` to set the Coder template name explicitly (CI falls back to `basename` of the directory if absent):

```json
{
  "display_name": "My Task Runner",
  "icon": "/icon/code.svg",
  "slug": "task-runner-my-name"
}
```

### Task-specific resources

Task runners must include these resources to wire into the Coder Tasks UI:

```hcl
data "coder_task" "me" {}  # provides .prompt from Tasks UI

resource "coder_ai_task" "task" {
  count  = data.coder_workspace.me.start_count
  app_id = module.claude-code[count.index].task_app_id
}
```

The AI agent module (e.g. `claude-code`) receives the prompt via `ai_prompt = data.coder_task.me.prompt`.

## Testing Locally

```bash
cd templates/<name>

# Format check
terraform fmt -check

# Initialize (without backend — no Coder server needed)
terraform init -backend=false

# Validate syntax and references
terraform validate
```

## Deployment

1. Commit changes and push to `main`
2. CI discovers changed templates via git diff
3. CI runs `terraform fmt -check`, `init`, `validate`
4. On `main` branch: CI pushes to Coder with `coder templates push`
5. New template version is auto-activated

For manual pushes:

```bash
coder login https://dev.zambruhni.com
coder templates push <name> --directory templates/<name> --yes
```

## Scripts Reference

| Script | Purpose |
|---|---|
| `scripts/check-module-versions.sh` | Compare `versions.json` against Coder registry for updates |
| `scripts/update-module-versions.sh` | Update versions in `versions.json` and `.tf` files, open GitLab MR |
| `scripts/cleanup-coder.sh` | Delete all workspaces/templates and push fresh `ai-dev` template |

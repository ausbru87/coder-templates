# Contributing

Guide for adding and maintaining templates in this repository.

## Adding a New Template

### 1. Create the template directory

```
templates/<name>/
├── main.tf           # Required — template definition
├── README.md         # Recommended — what the template provides, parameters, env vars
├── icon.txt          # Recommended — Coder icon path (e.g., /icon/code.svg)
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

Create `templates/<name>/icon.txt` containing a Coder built-in icon path (e.g., `/icon/code.svg`). After pushing, CI runs `coder templates edit --icon` with this value. Browse available icons in the Coder UI template editor.

### 4. Track module versions

If your template uses Coder registry modules, add their versions to `versions.json`:

```json
{
  "code-server": "1.3.1",
  "your-module": "1.0.0"
}
```

The version check scripts (`check-module-versions.sh`, `update-module-versions.sh`) will then track updates for your modules.

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

# AWS AI Dev Environment

AWS-focused development environment with Kiro as the primary AI agent. Runs on Kubernetes with AWS CDK, AWS CLI, and Kiro tooling pre-installed.

## Included Apps

| App | Type | Description |
|-----|------|-------------|
| Kiro Desktop | External (`kiro://`) | Kiro IDE — primary AI coding agent |
| code-server | Browser (subdomain) | VS Code in the browser |

## AWS Tooling

- **AWS CLI** — pre-installed in the base image (`codercom/enterprise-node:ubuntu`)
- **AWS CDK** — installed via `npm install -g aws-cdk` on startup

## Authentication

**You must authenticate to Kiro after workspace creation.** Kiro manages its own credentials independently — no AI Bridge or Coder API keys are used.

Open a terminal in the workspace and run:

```bash
kiro-cli login
```

Supported auth methods:

- AWS Builder ID
- IAM Identity Center
- GitHub
- Google

AWS services require separate credentials. Run `aws configure` or set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` environment variables.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cpu` | 4 | CPU cores (2, 4, 8) |
| `memory` | 8 | Memory in GB (4, 8, 12, 16, 24) |
| `disk_size` | 20 | PVC size in GB (immutable after creation) |
| `dotfiles_url` | — | Git dotfiles repo URL |
| `git_repo` | — | Repository to clone on start |

## Usage

```bash
coder create my-workspace --template aws-dev
```

Once the workspace is running:

1. Run `kiro-cli login` in the terminal to authenticate Kiro
2. Open Kiro Desktop via the workspace dashboard
3. Run `aws configure` to set up AWS credentials
4. Run `cdk init` to scaffold a new CDK project

# Coder Templates (dev.zambruhni.com)

This repository is the canonical source for templates pushed to `https://dev.zambruhni.com`.

## Template Catalog

- `tier-ai-task-runner-generic`: task-driven AI runner workspace with `coder_ai_task` and Claude Code.
- `tier-dev-basic`: minimal code-server + terminal workspace.
- `tier-dev-ai-basic`: minimal dev workspace plus AI Bridge, mux, Claude Code, and Codex integration.
- `tier-dev-universal`: general development workspace (Python, Node/JS/TS, Java, optional Go/Rust).
- `tier-dso-universal`: DevSecOps/SRE workspace (Terraform, cloud CLIs, Kubernetes tools, security tooling) with AI modules.

Existing templates remain available during migration:

- `universal`
- `universal-gui`

## Repository Layout

```text
templates/
  tier-ai-task-runner-generic/
  tier-dev-basic/
  tier-dev-ai-basic/
  tier-dev-universal/
  tier-dso-universal/
ci/
  discover_templates.py
.gitlab-ci.yml
```

## GitLab CI Push Flow

Pipeline stages:

1. `discover`: detect changed template directories under `templates/`.
2. `validate`: run `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`, and a plan-check pass.
3. `push`: on `main`, push changed templates to Coder.

### Required GitLab CI variables

- `CODER_URL`: `https://dev.zambruhni.com`
- `CODER_SESSION_TOKEN`: session token with template push permissions
- `CODER_ORG`: target Coder org (defaults to `default`)
- `AUTO_ACTIVATE`: `true`/`false` (defaults to `false`)

Optional:

- `TF_PLAN_CHECK_STRICT`: `true` forces provider-connectivity plan failures to fail the pipeline.

## Local Validation

```bash
python3 ci/discover_templates.py --deployment-dir templates --list-all --text-output changed_templates.txt
while IFS= read -r d; do
  (cd "$d" && terraform fmt -check && terraform init -backend=false && terraform validate)
done < changed_templates.txt
```

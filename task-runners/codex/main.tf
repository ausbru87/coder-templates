# =============================================================================
# Codex Tasks — Kubernetes Task Runner Template
# =============================================================================
# Ephemeral task runner for OpenAI Codex on Kubernetes. Receives prompts from
# the Coder Tasks UI and executes them via the Codex agent.
#
# Included tools:
#   - Codex (via registry module — handles install, AgentAPI, web UI)
#   - code-server (VS Code in the browser)
#   - mux (terminal multiplexer with AI provider UI)
#   - Preview app (authenticated subdomain proxy)
#
# AI access:
#   All AI tools authenticate through Coder's AI Bridge, which proxies
#   requests to Anthropic/OpenAI using the workspace owner's Coder session
#   token. No external API keys are needed.
#
# Task runner resources:
#   - data.coder_task.me   — provides .prompt from Tasks UI
#   - coder_ai_task        — wires the task to the codex module
# =============================================================================

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

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "coder" {}

variable "use_kubeconfig" {
  type        = bool
  description = "Use host kubeconfig instead of in-cluster config"
  default     = false
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for workspaces"
  default     = "coder-workspaces"
}

provider "kubernetes" {
  config_path = var.use_kubeconfig ? "~/.kube/config" : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
data "coder_task" "me" {}

data "coder_external_auth" "github" {
  id       = "github"
  optional = true
}

# -----------------------------------------------------------------------------
# Parameters — workspace sizing and optional features
# -----------------------------------------------------------------------------

data "coder_parameter" "system_prompt" {
  name         = "system_prompt"
  display_name = "System Prompt"
  description  = "Instructions for Codex (optional)."
  type         = "string"
  default      = ""
  mutable      = false
  icon         = "/icon/openai.svg"
}

data "coder_parameter" "setup_script" {
  name         = "setup_script"
  display_name = "Setup Script"
  description  = "Shell script to run before Codex starts (optional)."
  type         = "string"
  default      = ""
  mutable      = false
  icon         = "/icon/terminal.svg"
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "Port for the app preview."
  type         = "number"
  default      = "3000"
  mutable      = false
  icon         = "/icon/widgets.svg"
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "CPU limit for the workspace pod"
  type         = "number"
  default      = "4"
  mutable      = true
  icon         = "/icon/memory.svg"

  option {
    name  = "2 Cores"
    value = "2"
  }
  option {
    name  = "4 Cores"
    value = "4"
  }
  option {
    name  = "8 Cores"
    value = "8"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Memory allocation for the workspace pod"
  type         = "number"
  default      = "8"
  mutable      = true
  icon         = "/icon/memory.svg"

  option {
    name  = "4 GB"
    value = "4"
  }
  option {
    name  = "8 GB"
    value = "8"
  }
  option {
    name  = "12 GB"
    value = "12"
  }
  option {
    name  = "16 GB"
    value = "16"
  }
  option {
    name  = "24 GB"
    value = "24"
  }
}

data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size (GB)"
  description  = "Persistent volume size — cannot be changed after creation"
  type         = "number"
  default      = "20"
  mutable      = false
  icon         = "/icon/database.svg"

  option {
    name  = "10 GB"
    value = "10"
  }
  option {
    name  = "20 GB"
    value = "20"
  }
  option {
    name  = "50 GB"
    value = "50"
  }
}

data "coder_parameter" "git_repo" {
  name         = "git_repo"
  display_name = "Git Repository"
  description  = "Repository to clone on workspace start (optional)."
  type         = "string"
  default      = ""
  mutable      = false
  icon         = "/icon/git.svg"
}

# -----------------------------------------------------------------------------
# Locals — AI Bridge URLs and tool configuration
# -----------------------------------------------------------------------------

locals {
  # AI Bridge endpoints — proxied through Coder, authenticated via session token
  ai_bridge_anthropic_url = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
  ai_bridge_openai_url    = "${data.coder_workspace.me.access_url}/api/v2/aibridge/openai"

  # Mux provider configuration — written to ~/.mux/providers.jsonc
  mux_provider_settings = {
    "anthropic" = {
      "serviceTier" = "default"
      "models" = [
        "claude-haiku-4-5-20251001",
        "claude-opus-4-6-20250610"
      ]
      "baseUrl" = local.ai_bridge_anthropic_url
      "apiKey"  = data.coder_workspace_owner.me.session_token
    }
  }
}

# -----------------------------------------------------------------------------
# Agent — minimal startup (codex module handles its own install)
# -----------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    #!/bin/bash
    touch ~/.bashrc

    # Ensure npm global bin is in PATH
    export PATH="$PATH:$(npm config get prefix)/bin"
    NPM_BIN="$(npm config get prefix)/bin"
    grep -q "$NPM_BIN" ~/.bashrc 2>/dev/null || echo "export PATH=\"\$PATH:$NPM_BIN\"" >> ~/.bashrc

    # Mux AI provider configuration
    echo "Configuring Mux..."
    mkdir -p ~/.mux
    cat > ~/.mux/providers.jsonc << 'MUXEOF'
    ${jsonencode(local.mux_provider_settings)}
    MUXEOF

    echo "=== Task Runner Ready ==="
  EOT

  env = {
    ANTHROPIC_BASE_URL = local.ai_bridge_anthropic_url
    ANTHROPIC_API_BASE = local.ai_bridge_anthropic_url
    OPENAI_BASE_URL    = local.ai_bridge_openai_url
  }

  metadata {
    display_name = "CPU Usage"
    key          = "cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Disk Usage"
    key          = "disk_usage"
    script       = "coder stat disk --path /home/coder"
    interval     = 60
    timeout      = 1
  }
}

# -----------------------------------------------------------------------------
# Task Runner — wires Tasks UI prompt to codex module
# -----------------------------------------------------------------------------

resource "coder_ai_task" "task" {
  count  = data.coder_workspace.me.start_count
  app_id = module.codex[count.index].task_app_id
}

# -----------------------------------------------------------------------------
# Coder Registry Modules
# -----------------------------------------------------------------------------

# codex — handles install, AgentAPI, web UI, and task reporting
module "codex" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder-labs/codex/coder"
  version             = "4.3.0"
  agent_id            = coder_agent.main.id
  workdir             = "/home/coder"
  ai_prompt           = data.coder_task.me.prompt
  enable_aibridge     = true
  subdomain           = true
  codex_system_prompt = data.coder_parameter.system_prompt.value
  post_install_script = data.coder_parameter.setup_script.value
  order               = 1

  # Use danger-full-access sandbox to avoid interactive trust prompts in
  # containerized (K8s) workspaces. approval_policy=never ensures fully
  # autonomous operation. No [notice.model_migrations] section so Codex
  # auto-accepts model upgrades without prompting.
  base_config_toml = <<-EOT
    sandbox_mode = "danger-full-access"
    approval_policy = "never"
    preferred_auth_method = "apikey"
    profile = "aibridge"
  EOT
}

# code-server — VS Code in the browser, accessible via subdomain
module "code-server" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/code-server/coder"
  version   = "1.3.1"
  agent_id  = coder_agent.main.id
  folder    = "/home/coder"
  subdomain = true
  order     = 2
}

# mux — terminal multiplexer with built-in AI provider switching UI
module "mux" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/mux/coder"
  version   = "1.4.3"
  agent_id  = coder_agent.main.id
  subdomain = true
  order     = 3
}

# git-clone — clone a repo into /home/coder on workspace start
module "git-clone" {
  count    = data.coder_parameter.git_repo.value != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.0.22"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_repo.value
  base_dir = "/home/coder"
}

# -----------------------------------------------------------------------------
# Preview App — authenticated subdomain proxy for app previews
# -----------------------------------------------------------------------------

resource "coder_app" "preview" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main.id
  slug         = "preview"
  display_name = "Preview"
  url          = "http://localhost:${data.coder_parameter.preview_port.value}"
  share        = "authenticated"
  subdomain    = true
  open_in      = "tab"
  order        = 4
}

# -----------------------------------------------------------------------------
# Kubernetes Resources
# -----------------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.disk_size.value}Gi"
      }
    }
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "kubernetes_pod_v1" "workspace" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
    }
  }

  spec {
    security_context {
      run_as_user = 1000
      fs_group    = 1000
    }

    container {
      name              = "dev"
      image             = "codercom/enterprise-node:ubuntu"
      image_pull_policy = "Always"
      command           = ["sh", "-c", coder_agent.main.init_script]

      security_context {
        run_as_user = 1000
      }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      env {
        name  = "CODER_AGENT_URL"
        value = data.coder_workspace.me.access_url
      }

      resources {
        requests = {
          "cpu"    = "1"
          "memory" = "${max(2, floor(data.coder_parameter.memory.value / 2))}Gi"
        }
        limits = {
          "cpu"    = "${data.coder_parameter.cpu.value}"
          "memory" = "${data.coder_parameter.memory.value}Gi"
        }
      }

      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
      }
    }

    affinity {
      pod_anti_affinity {
        preferred_during_scheduling_ignored_during_execution {
          weight = 1
          pod_affinity_term {
            topology_key = "kubernetes.io/hostname"
            label_selector {
              match_expressions {
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["coder-workspace"]
              }
            }
          }
        }
      }
    }
  }
}

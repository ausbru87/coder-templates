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

data "coder_external_auth" "github" {
  id       = "github"
  optional = true
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Memory allocation for the workspace pod"
  type         = "number"
  default      = 8
  mutable      = true
  icon         = "/icon/memory.svg"

  option {
    name  = "6 GB"
    value = 6
  }

  option {
    name  = "8 GB"
    value = 8
  }

  option {
    name  = "12 GB"
    value = 12
  }

  option {
    name  = "16 GB"
    value = 16
  }
}

data "coder_parameter" "ai_prompt" {
  type         = "string"
  name         = "ai_prompt"
  display_name = "AI Task Prompt"
  description  = "The first task prompt for Claude Code"
  mutable      = true
  form_type    = "textarea"
  default      = "You are in /home/coder/repo. Analyze the project and propose actionable next steps."
  icon         = "/icon/terminal.svg"
}

data "coder_parameter" "system_prompt" {
  type         = "string"
  name         = "system_prompt"
  display_name = "AI System Prompt"
  description  = "Optional system-level constraints and context"
  mutable      = true
  form_type    = "textarea"
  default      = "You are a careful coding assistant. Make small, verifiable changes and explain tradeoffs. If a preview app is needed, run it on PREVIEW_PORT."
  icon         = "/icon/terminal.svg"
}

data "coder_parameter" "enable_preview_app" {
  name         = "enable_preview_app"
  display_name = "Enable Preview App"
  description  = "Expose localhost preview app"
  type         = "bool"
  default      = false
  mutable      = true
  icon         = "/icon/code.svg"
}

data "coder_parameter" "preview_port" {
  count        = tobool(data.coder_parameter.enable_preview_app.value) ? 1 : 0
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "Preview app port"
  type         = "number"
  default      = 3000
  mutable      = true
  icon         = "/icon/code.svg"
}

locals {
  preview_port = try(data.coder_parameter.preview_port[0].value, 3000)
  system_prompt = replace(
    data.coder_parameter.system_prompt.value,
    "PREVIEW_PORT",
    tostring(local.preview_port)
  )
  claude_settings = {
    env = {
      ANTHROPIC_BASE_URL   = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
      ANTHROPIC_AUTH_TOKEN = data.coder_workspace_owner.me.session_token
      OPENAI_BASE_URL              = "${data.coder_workspace.me.access_url}/api/v2/aibridge/openai"
      ANTHROPIC_MODEL              = "anthropic.claude-opus-4-5-20251101-v1:0"
      ANTHROPIC_SMALL_FAST_MODEL   = "anthropic.claude-haiku-4-5-20251001-v1:0"
      PREVIEW_PORT                 = tostring(local.preview_port)
      GH_TOKEN             = data.coder_external_auth.github.access_token
      GH_USERNAME          = data.coder_workspace_owner.me.name
      GIT_AUTHOR_NAME      = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_AUTHOR_EMAIL     = data.coder_workspace_owner.me.email
      GIT_COMMITTER_NAME   = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_COMMITTER_EMAIL  = data.coder_workspace_owner.me.email
    }
    autoUpdaterStatus             = "disabled"
    hasAcknowledgedCostThreshold  = true
    hasCompletedOnboarding        = true
    bypassPermissionsModeAccepted = true
  }

  mux_provider_settings = {
    "anthropic" = {
      "serviceTier" = "default"
      "models" = [
        "anthropic.claude-haiku-4-5-20251001-v1:0",
        "anthropic.claude-opus-4-5-20251101-v1:0"
      ]
      "baseUrl" = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
      "apiKey"  = data.coder_workspace_owner.me.session_token
    }
  }
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    set -e

    sudo apt-get update
    sudo apt-get install -y \
      curl \
      git \
      jq \
      vim \
      ca-certificates \
      openssh-client \
      ripgrep

    mkdir -p /home/coder/repo

    # Mux AI provider configuration
    mkdir -p ~/.mux
    echo '${replace(jsonencode(local.mux_provider_settings), "'", "'\\''")}' > ~/.mux/providers.jsonc

    echo "ai-task-runner-generic workspace ready"
  EOT

  env = {
    PREVIEW_PORT         = tostring(local.preview_port)
    GIT_AUTHOR_NAME      = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL     = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME   = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL  = data.coder_workspace_owner.me.email
    GH_TOKEN             = data.coder_external_auth.github.access_token
    ANTHROPIC_BASE_URL   = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
    ANTHROPIC_API_BASE   = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
    OPENAI_BASE_URL      = "${data.coder_workspace.me.access_url}/api/v2/aibridge/openai"
    ANTHROPIC_AUTH_TOKEN          = data.coder_workspace_owner.me.session_token
    ANTHROPIC_MODEL              = "anthropic.claude-opus-4-5-20251101-v1:0"
    ANTHROPIC_SMALL_FAST_MODEL   = "anthropic.claude-haiku-4-5-20251001-v1:0"
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "2_home_disk"
    script       = "coder stat disk --path /home/coder"
    interval     = 60
    timeout      = 1
  }
}

resource "coder_env" "anthropic_api_key" {
  agent_id = coder_agent.main.id
  name     = "ANTHROPIC_API_KEY"
  value    = data.coder_workspace_owner.me.session_token
}

resource "coder_env" "openai_api_key" {
  agent_id = coder_agent.main.id
  name     = "OPENAI_API_KEY"
  value    = data.coder_workspace_owner.me.session_token
}

module "claude-code" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder/claude-code/coder"
  version             = "4.4.2"
  agent_id            = coder_agent.main.id
  workdir             = "/home/coder/repo"
  subdomain           = true
  report_tasks        = true
  system_prompt       = local.system_prompt
  ai_prompt           = data.coder_parameter.ai_prompt.value
  install_agentapi    = true
  install_claude_code = true
  post_install_script = templatefile("scripts/claude/install.sh", {
    HOME_FOLDER = "/home/coder"
    SETTINGS    = jsonencode(local.claude_settings)
  })
}

resource "coder_ai_task" "this" {
  app_id = try(module.claude-code[0].task_app_id, "00000000-0000-0000-0000-000000000000")
}

module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.0.15"
  agent_id = coder_agent.main.id
}

module "mux" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/mux/coder"
  version   = "1.0.7"
  agent_id  = coder_agent.main.id
  subdomain = true
}

module "code-server" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/code-server/coder"
  version   = "1.3.1"
  agent_id  = coder_agent.main.id
  folder    = "/home/coder/repo"
  subdomain = true
}

resource "coder_app" "preview" {
  count        = tobool(data.coder_parameter.enable_preview_app.value) ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "preview"
  display_name = "Preview"
  icon         = "/icon/code.svg"
  url          = "http://localhost:${local.preview_port}"
  share        = "owner"
  subdomain    = true
  open_in      = "tab"

  healthcheck {
    url       = "http://localhost:${local.preview_port}/"
    interval  = 10
    threshold = 30
  }
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"   = "coder-workspace"
      "workspace.coder.com/type" = "ai-task-runner-generic"
    }
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "20Gi"
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
      "app.kubernetes.io/name"   = "coder-workspace"
      "workspace.coder.com/type" = "ai-task-runner-generic"
    }
  }

  spec {
    security_context {
      run_as_user = 1000
      fs_group    = 1000
    }

    container {
      name              = "dev"
      image             = "codercom/enterprise-base:ubuntu"
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
          cpu    = "1"
          memory = "${max(2, floor(data.coder_parameter.memory.value / 2))}Gi"
        }
        limits = {
          cpu    = "4"
          memory = "${data.coder_parameter.memory.value}Gi"
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
  }
}

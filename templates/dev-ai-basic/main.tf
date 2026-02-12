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

data "coder_external_auth" "gitlab" {
  id       = "gitlab"
  optional = true
}

data "coder_parameter" "dotfiles_url" {
  name         = "dotfiles_url"
  display_name = "Dotfiles URL"
  description  = "Git repository URL for your dotfiles (optional)."
  type         = "string"
  default      = ""
  mutable      = true
  icon         = "/icon/dotfiles.svg"
}

data "coder_parameter" "git_repo" {
  name         = "git_repo"
  display_name = "Git Repository"
  description  = "Repository to clone on workspace start (optional)."
  type         = "string"
  default      = ""
  mutable      = true
  icon         = "/icon/git.svg"
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

data "coder_parameter" "enable_roo" {
  name         = "enable_roo"
  display_name = "Enable Roo Code setup"
  description  = "Preconfigure Roo Code to use AI Bridge settings"
  type         = "bool"
  default      = true
  mutable      = true
  icon         = "/icon/code.svg"
}

locals {
  enable_roo = tobool(data.coder_parameter.enable_roo.value)

  code_server_extensions = local.enable_roo ? [
    "RooVeterinaryInc.roo-cline"
  ] : []

  code_server_machine_settings = local.enable_roo ? {
    "roo-cline.autoImportSettingsPath" = "/home/coder/.config/roo-code/ai-bridge-settings.json"
  } : {}
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
      htop \
      unzip \
      zip \
      ca-certificates \
      openssh-client \
      ripgrep \
      fd-find \
      python3 \
      python3-pip

    sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

    if ! command -v gh >/dev/null 2>&1; then
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update
      sudo apt-get install -y gh
    fi

    if ! command -v glab >/dev/null 2>&1; then
      curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash || true
      sudo apt-get install -y glab || true
    fi

    # Best-effort Codex CLI install fallback in case module registry is unavailable.
    if ! command -v codex >/dev/null 2>&1; then
      sudo npm install -g @openai/codex || true
    fi

    if ${local.enable_roo}; then
      ROOCODE_STORAGE="/home/coder/.local/share/code-server/User/globalStorage/rooveterinaryinc.roo-cline"
      mkdir -p "$ROOCODE_STORAGE/settings"
      cat > "$ROOCODE_STORAGE/settings/provider_profiles.json" << ROOCONFIG
{
  "currentApiConfigName": "AI Bridge (Anthropic)",
  "apiConfigs": {
    "AI Bridge (Anthropic)": {
      "apiProvider": "anthropic",
      "anthropicBaseUrl": "https://dev.zambruhni.com/api/v2/aibridge/anthropic",
      "anthropicApiKey": "$ANTHROPIC_API_KEY"
    }
  }
}
ROOCONFIG

      mkdir -p /home/coder/.config/roo-code
      cat > /home/coder/.config/roo-code/ai-bridge-settings.json << ROOCONFIG2
{
  "providerProfiles": {
    "currentApiConfigName": "AI Bridge (Anthropic)",
    "apiConfigs": {
      "AI Bridge (Anthropic)": {
        "apiProvider": "anthropic",
        "anthropicBaseUrl": "https://dev.zambruhni.com/api/v2/aibridge/anthropic",
        "anthropicApiKey": "$ANTHROPIC_API_KEY"
      }
    }
  }
}
ROOCONFIG2
    fi

    echo "dev-ai-basic workspace ready"
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
    ANTHROPIC_BASE_URL  = "https://dev.zambruhni.com/api/v2/aibridge/anthropic"
    ANTHROPIC_API_BASE  = "https://dev.zambruhni.com/api/v2/aibridge/anthropic"
    OPENAI_BASE_URL     = "https://dev.zambruhni.com/api/v2/aibridge/openai"
    EDITOR              = "code"
    VISUAL              = "code"
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

module "code-server" {
  count            = data.coder_workspace.me.start_count
  source           = "registry.coder.com/coder/code-server/coder"
  version          = "1.3.1"
  agent_id         = coder_agent.main.id
  folder           = "/home/coder"
  subdomain        = true
  extensions       = local.code_server_extensions
  machine-settings = local.code_server_machine_settings
}

module "mux" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/mux/coder"
  version   = "1.0.7"
  agent_id  = coder_agent.main.id
  subdomain = true
}

module "claude-code" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/claude-code/coder"
  version   = "4.4.2"
  agent_id  = coder_agent.main.id
  workdir   = "/home/coder"
  subdomain = true
}

module "codex" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder-labs/codex/coder"
  agent_id  = coder_agent.main.id
  workdir   = "/home/coder"
  subdomain = true
}

module "dotfiles" {
  count        = data.coder_parameter.dotfiles_url.value != "" ? data.coder_workspace.me.start_count : 0
  source       = "registry.coder.com/coder/dotfiles/coder"
  version      = "1.0.23"
  agent_id     = coder_agent.main.id
  dotfiles_uri = data.coder_parameter.dotfiles_url.value
}

module "git-clone" {
  count    = data.coder_parameter.git_repo.value != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.0.22"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_repo.value
  base_dir = "/home/coder"
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"   = "coder-workspace"
      "workspace.coder.com/type" = "dev-ai-basic"
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
      "workspace.coder.com/type" = "dev-ai-basic"
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

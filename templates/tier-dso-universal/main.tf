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
  default      = 12
  mutable      = true
  icon         = "/icon/memory.svg"

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

  option {
    name  = "24 GB"
    value = 24
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
      htop \
      unzip \
      zip \
      ca-certificates \
      openssh-client \
      ripgrep \
      fd-find \
      python3 \
      python3-pip \
      gnupg \
      lsb-release

    sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

    if ! command -v gh >/dev/null 2>&1; then
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update
      sudo apt-get install -y gh
    fi

    # Core cloud/devsecops toolchain (best effort where package availability differs).
    sudo apt-get install -y terraform awscli kubectl helm || true

    if ! command -v az >/dev/null 2>&1; then
      curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash || true
    fi

    if ! command -v gcloud >/dev/null 2>&1; then
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
      sudo apt-get update
      sudo apt-get install -y google-cloud-cli || true
    fi

    sudo npm install -g aws-cdk || true

    if ! command -v k9s >/dev/null 2>&1; then
      K9S_VERSION="v0.32.5"
      curl -fsSL "https://github.com/derailed/k9s/releases/download/$${K9S_VERSION}/k9s_Linux_amd64.tar.gz" -o /tmp/k9s.tar.gz || true
      sudo tar -C /usr/local/bin -xzf /tmp/k9s.tar.gz k9s 2>/dev/null || true
    fi

    if ! command -v yq >/dev/null 2>&1; then
      sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 || true
      sudo chmod +x /usr/local/bin/yq || true
    fi

    if ! command -v trivy >/dev/null 2>&1; then
      sudo apt-get install -y trivy || true
    fi

    if ! command -v syft >/dev/null 2>&1; then
      curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /tmp || true
      sudo mv /tmp/syft /usr/local/bin/syft 2>/dev/null || true
    fi

    if ! command -v grype >/dev/null 2>&1; then
      curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /tmp || true
      sudo mv /tmp/grype /usr/local/bin/grype 2>/dev/null || true
    fi

    if ! command -v glab >/dev/null 2>&1; then
      curl -fsSL https://gitlab.com/gitlab-org/cli/-/releases/permalink/latest/downloads/glab_$(dpkg --print-architecture).deb -o /tmp/glab.deb || true
      sudo apt-get install -y /tmp/glab.deb || true
    fi

    if ! command -v codex >/dev/null 2>&1; then
      sudo npm install -g @openai/codex || true
    fi

    echo "tier-dso-universal workspace ready"
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
    ANTHROPIC_BASE_URL  = "https://dev.zambruhni.com/api/v2/aibridge/anthropic"
    ANTHROPIC_API_BASE  = "https://dev.zambruhni.com/api/v2/aibridge/anthropic"
    OPENAI_BASE_URL     = "https://dev.zambruhni.com/api/v2/aibridge/openai"
    GH_TOKEN            = data.coder_external_auth.github.access_token
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
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/code-server/coder"
  version   = "1.3.1"
  agent_id  = coder_agent.main.id
  folder    = "/home/coder"
  subdomain = true
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

module "aider" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/aider/coder"
  version     = "2.0.1"
  agent_id    = coder_agent.main.id
  workdir     = "/home/coder"
  ai_provider = "anthropic"
  model       = "claude-opus-4-5-20251101"
  subdomain   = true
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

module "filebrowser" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/filebrowser/coder"
  version   = "1.0.21"
  agent_id  = coder_agent.main.id
  folder    = "/home/coder"
  subdomain = true
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"   = "coder-workspace"
      "workspace.coder.com/type" = "tier-dso-universal"
    }
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "30Gi"
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
      "workspace.coder.com/type" = "tier-dso-universal"
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
          cpu    = "2"
          memory = "${max(4, floor(data.coder_parameter.memory.value / 2))}Gi"
        }
        limits = {
          cpu    = "6"
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

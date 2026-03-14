# =============================================================================
# Universal Kubernetes Development Template
# =============================================================================
# Single consolidated template for all workspace types. Feature toggles control
# which tools, languages, and capabilities are installed.
#
# Features (all conditional):
# - IDEs: code-server (always), VS Code Desktop, Cursor
# - AI Tools: Claude Code, mux, codex, coder-login
# - Desktop GUI: XFCE via KasmVNC with Chrome + Terminator
# - DevSecOps: terraform, kubectl, helm, cloud CLIs, trivy, syft, grype
# - Languages: Python, Node.js, Java, Go, Rust
# - Utilities: filebrowser, dotfiles, git-clone, starship
#
# All AI tools are pre-configured to use AI Bridge for Anthropic/OpenAI access.
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

# External auth — both GitHub and GitLab
data "coder_external_auth" "github" {
  id       = "github"
  optional = true
}

data "coder_external_auth" "gitlab" {
  id       = "gitlab"
  optional = true
}

# -----------------------------------------------------------------------------
# Parameters
# -----------------------------------------------------------------------------

data "coder_parameter" "dotfiles_url" {
  name         = "dotfiles_url"
  display_name = "Dotfiles URL"
  description  = "Git repository URL for your dotfiles (optional)."
  type         = "string"
  default      = ""
  mutable      = false
  icon         = "/icon/dotfiles.svg"
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

data "coder_parameter" "enable_ai_tools" {
  name         = "enable_ai_tools"
  display_name = "Enable AI Tools"
  description  = "Claude Code, mux, codex, coder-login (all use AI Bridge)"
  type         = "bool"
  default      = "true"
  mutable      = false
  icon         = "/emojis/1f916.png"
}

data "coder_parameter" "enable_desktop" {
  name         = "enable_desktop"
  display_name = "Enable Desktop GUI"
  description  = "XFCE desktop via KasmVNC with Chrome and Terminator"
  type         = "bool"
  default      = "false"
  mutable      = false
  icon         = "/icon/desktop.svg"
}

data "coder_parameter" "enable_devsecops" {
  name         = "enable_devsecops"
  display_name = "Enable DevSecOps Tools"
  description  = "Terraform, kubectl, helm, cloud CLIs, k9s, trivy, syft, grype"
  type         = "bool"
  default      = "false"
  mutable      = false
  icon         = "/icon/widgets.svg"
}

data "coder_parameter" "install_python" {
  name         = "install_python"
  display_name = "Install Python"
  description  = "Python 3, pip, poetry, and common dev tools"
  type         = "bool"
  default      = "true"
  mutable      = false
  icon         = "/icon/python.svg"
}

data "coder_parameter" "install_node" {
  name         = "install_node"
  display_name = "Install Node.js Tools"
  description  = "Global npm packages (pnpm, typescript, eslint). Node.js is pre-installed."
  type         = "bool"
  default      = "true"
  mutable      = false
  icon         = "/icon/nodejs.svg"
}

data "coder_parameter" "install_java" {
  name         = "install_java"
  display_name = "Install Java"
  description  = "OpenJDK 21, Maven, and Gradle"
  type         = "bool"
  default      = "false"
  mutable      = false
  icon         = "/icon/java.svg"
}

data "coder_parameter" "install_go" {
  name         = "install_go"
  display_name = "Install Go"
  description  = "Go with gopls, delve, and golangci-lint"
  type         = "bool"
  default      = "false"
  mutable      = false
  icon         = "/icon/go.svg"
}

data "coder_parameter" "install_rust" {
  name         = "install_rust"
  display_name = "Install Rust"
  description  = "Rust via rustup with rust-analyzer, clippy, and rustfmt"
  type         = "bool"
  default      = "false"
  mutable      = false
  icon         = "/icon/rust.svg"
}

data "coder_parameter" "enable_filebrowser" {
  name         = "enable_filebrowser"
  display_name = "Enable File Browser"
  description  = "Web-based file manager"
  type         = "bool"
  default      = "false"
  mutable      = false
  icon         = "/icon/folder.svg"
}

data "coder_parameter" "enable_vscode_desktop" {
  name         = "enable_vscode_desktop"
  display_name = "Enable VS Code Desktop"
  description  = "VS Code Desktop connector (via Coder Desktop or SSH)"
  type         = "bool"
  default      = "false"
  mutable      = false
  icon         = "/icon/code.svg"
}

data "coder_parameter" "enable_cursor" {
  name         = "enable_cursor"
  display_name = "Enable Cursor"
  description  = "Cursor IDE connector"
  type         = "bool"
  default      = "false"
  mutable      = false
  icon         = "/icon/cursor.svg"
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  enable_ai        = data.coder_parameter.enable_ai_tools.value == "true"
  enable_desktop   = data.coder_parameter.enable_desktop.value == "true"
  enable_devsecops = data.coder_parameter.enable_devsecops.value == "true"

  container_image = "codercom/enterprise-node:ubuntu"

  ai_bridge_anthropic_url = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
  ai_bridge_openai_url    = "${data.coder_workspace.me.access_url}/api/v2/aibridge/openai"

  claude_settings = {
    env = {
      ANTHROPIC_BASE_URL         = local.ai_bridge_anthropic_url
      ANTHROPIC_AUTH_TOKEN       = data.coder_workspace_owner.me.session_token
      OPENAI_BASE_URL            = local.ai_bridge_openai_url
      ANTHROPIC_MODEL            = "anthropic.claude-opus-4-5-20251101-v1:0"
      ANTHROPIC_SMALL_FAST_MODEL = "anthropic.claude-haiku-4-5-20251001-v1:0"
      GH_TOKEN                   = data.coder_external_auth.github.access_token
      GH_USERNAME                = data.coder_workspace_owner.me.name
      GIT_AUTHOR_NAME            = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_AUTHOR_EMAIL           = data.coder_workspace_owner.me.email
      GIT_COMMITTER_NAME         = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_COMMITTER_EMAIL        = data.coder_workspace_owner.me.email
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
      "baseUrl" = local.ai_bridge_anthropic_url
      "apiKey"  = data.coder_workspace_owner.me.session_token
    }
  }

  # Desktop mode: install XFCE before starting the agent so KasmVNC finds a desktop
  container_command = local.enable_desktop ? join("\n", [
    "sudo rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null || true",
    "sudo apt-get update -y",
    "sudo apt-get install -y --no-install-recommends xfce4 dbus-x11",
    coder_agent.main.init_script,
  ]) : coder_agent.main.init_script
}

# -----------------------------------------------------------------------------
# Agent
# -----------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e

    echo "=== Universal Workspace Setup ==="

    # Ensure .bashrc exists (fresh PVC won't have one; modules like codex source it)
    touch ~/.bashrc

    # Non-interactive apt to avoid debconf prompts (e.g. VS Code installer)
    export DEBIAN_FRONTEND=noninteractive

    # Remove stale Yarn apt repo (expired GPG key in enterprise-node image)
    sudo rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null || true

    # Helper: apt-get with retry on dpkg lock (parallel coder_script resources)
    apt_get() {
      local retries=0
      while ! sudo apt-get "$@"; do
        if [ $retries -ge 15 ]; then
          echo "apt-get failed after $retries retries, giving up."
          return 1
        fi
        echo "apt-get failed (likely dpkg lock), retrying in 5s... ($retries)"
        retries=$((retries + 1))
        sleep 5
      done
    }

    # ----------------------------- Base packages ------------------------------
    apt_get update
    apt_get install -y \
      wget \
      vim \
      nano \
      htop \
      tree \
      unzip \
      zip \
      gnupg \
      lsb-release \
      apt-transport-https \
      software-properties-common \
      build-essential \
      make \
      cmake \
      pkg-config \
      libssl-dev \
      openssh-client \
      rsync \
      fzf \
      ripgrep \
      fd-find \
      bat \
      direnv

    sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true
    sudo ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true

    # ----------------------------- GitHub CLI --------------------------------
    if ! command -v gh &> /dev/null; then
      echo "Installing GitHub CLI..."
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update
      apt_get install -y gh
    fi

    # ----------------------------- AI Tools Config ----------------------------
    %{if local.enable_ai}
    # Roo Code settings for code-server
    ROOCODE_STORAGE="/home/coder/.local/share/code-server/User/globalStorage/rooveterinaryinc.roo-cline"
    mkdir -p "$ROOCODE_STORAGE/settings"
    cat > "$ROOCODE_STORAGE/settings/provider_profiles.json" << 'ROOCONFIG'
    {
      "currentApiConfigName": "AI Bridge (Anthropic)",
      "apiConfigs": {
        "AI Bridge (Anthropic)": {
          "apiProvider": "anthropic",
          "anthropicBaseUrl": "${local.ai_bridge_anthropic_url}",
          "anthropicApiKey": "$ANTHROPIC_API_KEY",
          "apiModelId": "claude-opus-4-5-20251101"
        }
      }
    }
    ROOCONFIG

    mkdir -p /home/coder/.config/roo-code
    cat > /home/coder/.config/roo-code/ai-bridge-settings.json << 'ROOCONFIG2'
    {
      "providerProfiles": {
        "currentApiConfigName": "AI Bridge (Anthropic)",
        "apiConfigs": {
          "AI Bridge (Anthropic)": {
            "apiProvider": "anthropic",
            "anthropicBaseUrl": "${local.ai_bridge_anthropic_url}",
            "anthropicApiKey": "$ANTHROPIC_API_KEY",
            "apiModelId": "claude-opus-4-5-20251101"
          }
        }
      }
    }
    ROOCONFIG2

    # Mux AI provider configuration
    mkdir -p ~/.mux
    echo '${replace(jsonencode(local.mux_provider_settings), "'", "'\\''")}' > ~/.mux/providers.jsonc
    %{endif}

    # ----------------------------- Python ------------------------------------
    %{if data.coder_parameter.install_python.value == "true"}
    echo "Installing Python tools..."
    apt_get install -y python3 python3-pip python3-venv pipx
    pip3 install --user --break-system-packages --upgrade pip
    pip3 install --user --break-system-packages poetry black ruff mypy pytest ipython
    pipx ensurepath
    %{endif}

    # ----------------------------- Node.js -----------------------------------
    %{if data.coder_parameter.install_node.value == "true"}
    echo "Installing Node.js global packages..."
    sudo npm install -g pnpm typescript ts-node eslint prettier || true
    %{endif}

    # ----------------------------- Java --------------------------------------
    %{if data.coder_parameter.install_java.value == "true"}
    echo "Installing Java tools..."
    apt_get install -y openjdk-21-jdk maven gradle
    %{endif}

    # ----------------------------- Go ----------------------------------------
    %{if data.coder_parameter.install_go.value == "true"}
    if ! command -v go &> /dev/null; then
      echo "Installing Go..."
      GO_VERSION="1.23.4"
      wget -q "https://go.dev/dl/go$${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
      sudo rm -rf /usr/local/go
      sudo tar -C /usr/local -xzf /tmp/go.tar.gz
      rm /tmp/go.tar.gz
      export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
      echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
      go install golang.org/x/tools/gopls@latest
      go install github.com/go-delve/delve/cmd/dlv@latest
      go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    fi
    %{endif}

    # ----------------------------- Rust --------------------------------------
    %{if data.coder_parameter.install_rust.value == "true"}
    if ! command -v rustc &> /dev/null; then
      echo "Installing Rust..."
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      source "$HOME/.cargo/env"
      rustup component add rust-analyzer clippy rustfmt
    fi
    %{endif}

    # ----------------------------- DevSecOps ---------------------------------
    %{if local.enable_devsecops}
    echo "Installing DevSecOps tools..."

    # Terraform
    if ! command -v terraform &> /dev/null; then
      wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
      sudo apt-get update
      apt_get install -y terraform || true
    fi

    # kubectl
    if ! command -v kubectl &> /dev/null; then
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key \
        | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" \
        | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
      sudo apt-get update
      apt_get install -y kubectl || true
    fi

    # helm
    if ! command -v helm &> /dev/null; then
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || true
    fi

    # AWS CLI
    if ! command -v aws &> /dev/null; then
      curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscli.zip
      unzip -qo /tmp/awscli.zip -d /tmp
      sudo /tmp/aws/install || true
      rm -rf /tmp/aws /tmp/awscli.zip
    fi

    # Azure CLI
    if ! command -v az &> /dev/null; then
      curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash || true
    fi

    # GCP CLI
    if ! command -v gcloud &> /dev/null; then
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
        | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
      sudo apt-get update
      apt_get install -y google-cloud-cli || true
    fi

    # AWS CDK
    sudo npm install -g aws-cdk || true

    # k9s
    if ! command -v k9s &> /dev/null; then
      K9S_VERSION="v0.32.5"
      curl -fsSL "https://github.com/derailed/k9s/releases/download/$${K9S_VERSION}/k9s_Linux_amd64.tar.gz" -o /tmp/k9s.tar.gz
      sudo tar -C /usr/local/bin -xzf /tmp/k9s.tar.gz k9s 2>/dev/null || true
      rm -f /tmp/k9s.tar.gz
    fi

    # yq
    if ! command -v yq &> /dev/null; then
      sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 || true
      sudo chmod +x /usr/local/bin/yq || true
    fi

    # trivy
    if ! command -v trivy &> /dev/null; then
      wget -qO- https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
      echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
        | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null
      sudo apt-get update
      apt_get install -y trivy || true
    fi

    # syft
    if ! command -v syft &> /dev/null; then
      curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /tmp || true
      sudo mv /tmp/syft /usr/local/bin/syft 2>/dev/null || true
    fi

    # grype
    if ! command -v grype &> /dev/null; then
      curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /tmp || true
      sudo mv /tmp/grype /usr/local/bin/grype 2>/dev/null || true
    fi

    # GitLab CLI
    if ! command -v glab &> /dev/null; then
      GLAB_VERSION=$(curl -fsSL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases" | head -c 4096 | grep -o '"tag_name":"v[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
      if [ -n "$GLAB_VERSION" ]; then
        curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v$${GLAB_VERSION}/downloads/glab_$${GLAB_VERSION}_linux_$(dpkg --print-architecture).deb" -o /tmp/glab.deb || true
        sudo apt-get install -y /tmp/glab.deb || true
        rm -f /tmp/glab.deb
      fi
    fi
    %{endif}

    # ----------------------------- Desktop Apps ------------------------------
    %{if local.enable_desktop}
    echo "Installing desktop applications..."

    # Google Chrome
    if ! command -v google-chrome &> /dev/null; then
      wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
      apt_get install -y /tmp/google-chrome.deb
      rm -f /tmp/google-chrome.deb
    fi

    # Terminator
    if ! dpkg -s terminator &> /dev/null 2>&1; then
      apt_get install -y terminator
    fi

    # VS Code Desktop (inside XFCE session)
    if ! command -v code &> /dev/null; then
      wget -q -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
      apt_get install -y /tmp/vscode.deb
      rm -f /tmp/vscode.deb
    fi
    %{endif}

    # ----------------------------- Starship Prompt ---------------------------
    if ! command -v starship &> /dev/null; then
      echo "Installing starship prompt..."
      curl -sS https://starship.rs/install.sh | sh -s -- -y
      echo 'eval "$(starship init bash)"' >> ~/.bashrc
    fi

    echo "=== Universal Workspace Ready ==="
  EOT

  # Environment variables — AI Bridge vars set conditionally
  env = merge(
    {
      EDITOR = "code"
      VISUAL = "code"
    },
    local.enable_ai ? {
      ANTHROPIC_BASE_URL         = local.ai_bridge_anthropic_url
      ANTHROPIC_API_BASE         = local.ai_bridge_anthropic_url
      OPENAI_BASE_URL            = local.ai_bridge_openai_url
      ANTHROPIC_MODEL            = "anthropic.claude-opus-4-5-20251101-v1:0"
      ANTHROPIC_SMALL_FAST_MODEL = "anthropic.claude-haiku-4-5-20251001-v1:0"
    } : {}
  )

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

  metadata {
    display_name = "Git Branch"
    key          = "git_branch"
    script       = "cd /home/coder && git branch --show-current 2>/dev/null || echo 'N/A'"
    interval     = 30
    timeout      = 1
  }
}

# -----------------------------------------------------------------------------
# AI Bridge API Keys (conditional on enable_ai_tools)
# -----------------------------------------------------------------------------

resource "coder_env" "anthropic_api_key" {
  count    = local.enable_ai ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "ANTHROPIC_API_KEY"
  value    = data.coder_workspace_owner.me.session_token
}

resource "coder_env" "openai_api_key" {
  count    = local.enable_ai ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "OPENAI_API_KEY"
  value    = data.coder_workspace_owner.me.session_token
}

# -----------------------------------------------------------------------------
# IDE Modules
# -----------------------------------------------------------------------------

# code-server (always enabled)
module "code-server" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/code-server/coder"
  version   = "1.3.1"
  agent_id  = coder_agent.main.id
  folder    = "/home/coder"
  subdomain = true

  extensions = local.enable_ai ? ["RooVeterinaryInc.roo-cline"] : []

  machine-settings = local.enable_ai ? {
    "roo-cline.autoImportSettingsPath" = "/home/coder/.config/roo-code/ai-bridge-settings.json"
  } : {}
}

# VS Code Desktop (optional)
module "vscode-desktop" {
  count    = data.coder_parameter.enable_vscode_desktop.value == "true" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/vscode-desktop/coder"
  version  = "1.1.1"
  agent_id = coder_agent.main.id
  folder   = "/home/coder"
}

# Cursor (optional)
module "cursor" {
  count    = data.coder_parameter.enable_cursor.value == "true" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.0.22"
  agent_id = coder_agent.main.id
  folder   = "/home/coder"
}

# -----------------------------------------------------------------------------
# AI Tools (conditional on enable_ai_tools)
# -----------------------------------------------------------------------------

module "claude-code" {
  count               = local.enable_ai ? data.coder_workspace.me.start_count : 0
  source              = "registry.coder.com/coder/claude-code/coder"
  version             = "4.4.2"
  agent_id            = coder_agent.main.id
  workdir             = "/home/coder"
  subdomain           = true
  report_tasks        = true
  install_agentapi    = true
  install_claude_code = true
  post_install_script = templatefile("scripts/claude/install.sh", {
    HOME_FOLDER = "/home/coder"
    SETTINGS    = jsonencode(local.claude_settings)
  })
}

module "mux" {
  count     = local.enable_ai ? data.coder_workspace.me.start_count : 0
  source    = "registry.coder.com/coder/mux/coder"
  version   = "1.4.3"
  agent_id  = coder_agent.main.id
  subdomain = true
}

module "codex" {
  count     = local.enable_ai ? data.coder_workspace.me.start_count : 0
  source    = "registry.coder.com/coder-labs/codex/coder"
  agent_id  = coder_agent.main.id
  workdir   = "/home/coder"
  subdomain = true
}

module "coder-login" {
  count    = local.enable_ai ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.0.15"
  agent_id = coder_agent.main.id
}

# -----------------------------------------------------------------------------
# Desktop GUI (conditional on enable_desktop)
# -----------------------------------------------------------------------------

module "kasmvnc" {
  count               = local.enable_desktop ? data.coder_workspace.me.start_count : 0
  source              = "registry.coder.com/coder/kasmvnc/coder"
  version             = "1.2.7"
  agent_id            = coder_agent.main.id
  desktop_environment = "xfce"
  subdomain           = true
}

# -----------------------------------------------------------------------------
# Utility Modules
# -----------------------------------------------------------------------------

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
  count     = data.coder_parameter.enable_filebrowser.value == "true" ? data.coder_workspace.me.start_count : 0
  source    = "registry.coder.com/coder/filebrowser/coder"
  version   = "1.0.21"
  agent_id  = coder_agent.main.id
  folder    = "/home/coder"
  subdomain = true
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
      "workspace.coder.com/type"   = "universal"
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
      "workspace.coder.com/type"   = "universal"
    }
  }

  spec {
    security_context {
      run_as_user = 1000
      fs_group    = 1000
    }

    container {
      name              = "dev"
      image             = local.container_image
      image_pull_policy = "Always"
      command           = ["sh", "-c", local.container_command]

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

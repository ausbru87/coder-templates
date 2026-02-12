# =============================================================================
# Universal Kubernetes Development Template
# =============================================================================
# Full-featured Kubernetes-based workspace with desktop GUI for general development.
# Includes all IDEs, AI tools, and common development utilities.
# Deployed to Kubernetes cluster in the coder-workspaces namespace.
#
# Features:
# - Desktop GUI: XFCE desktop via KasmVNC (browser-accessible)
# - Desktop Apps: Google Chrome, Terminator, VS Code Desktop
# - IDEs: code-server (web), VS Code Desktop, Cursor
# - AI Tools: Claude Code (configured via AI Bridge)
# - Terminal: mux (tmux/screen multiplexer)
# - Utilities: filebrowser, dotfiles, git-clone
# - Languages: Multi-language support via runtime installation
#
# All AI tools are pre-configured to use the AI Bridge for Anthropic/OpenAI access.
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

# GitHub external auth
data "coder_external_auth" "github" {
  id       = "github"
  optional = true
}

# GitLab external auth
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
  description  = "Git repository URL for your dotfiles (optional). Applied on workspace start."
  type         = "string"
  default      = ""
  mutable      = true
  icon         = "/icon/dotfiles.svg"
}

data "coder_parameter" "git_repo" {
  name         = "git_repo"
  display_name = "Git Repository"
  description  = "Repository to clone on workspace start (optional)"
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
  default      = "8"
  mutable      = true
  icon         = "/icon/memory.svg"

  option {
    name  = "8 GB (Standard)"
    value = "8"
  }
  option {
    name  = "16 GB (Heavy)"
    value = "16"
  }
  option {
    name  = "32 GB (Extreme)"
    value = "32"
  }
}

data "coder_parameter" "install_node" {
  name         = "install_node"
  display_name = "Install Node.js Tools"
  description  = "Install global npm packages (yarn, pnpm, typescript, eslint). Node.js is pre-installed."
  type         = "bool"
  default      = "true"
  mutable      = true
  icon         = "/icon/nodejs.svg"
}

data "coder_parameter" "install_python" {
  name         = "install_python"
  display_name = "Install Python Tools"
  description  = "Install Python with pip, poetry, and common dev tools"
  type         = "bool"
  default      = "true"
  mutable      = true
  icon         = "/icon/python.svg"
}

data "coder_parameter" "install_go" {
  name         = "install_go"
  display_name = "Install Go"
  description  = "Install Go programming language with tools"
  type         = "bool"
  default      = "false"
  mutable      = true
  icon         = "/icon/go.svg"
}

data "coder_parameter" "install_rust" {
  name         = "install_rust"
  display_name = "Install Rust"
  description  = "Install Rust programming language via rustup"
  type         = "bool"
  default      = "false"
  mutable      = true
  icon         = "/icon/rust.svg"
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

    # Remove stale Yarn apt repo shipped in the enterprise-node image.
    # Its GPG key (62D54FD4003F6525) is expired and breaks apt-get update.
    # Yarn is available via corepack (ships with Node.js) — the repo is unnecessary.
    sudo rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null || true

    # Helper: run apt-get with automatic retry on dpkg lock conflict.
    # Coder runs all coder_script resources in parallel, so the KasmVNC module
    # may be holding the dpkg lock while installing its dependencies.
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

    # Base packages (packages already in enterprise-node are omitted:
    # git, curl, jq, ca-certificates, sudo, iproute2, node, npm)
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
      build-essential \
      make \
      cmake \
      pkg-config \
      openssh-client \
      rsync \
      fzf \
      ripgrep \
      fd-find \
      bat \
      direnv

    # Symlink fd and bat (Ubuntu uses different names)
    sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true
    sudo ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true

    # -----------------------------
    # Desktop Applications (available in XFCE via KasmVNC)
    # -----------------------------

    # Google Chrome
    if ! command -v google-chrome &> /dev/null; then
      echo "Installing Google Chrome..."
      wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
      apt_get install -y /tmp/google-chrome.deb
      rm -f /tmp/google-chrome.deb
    fi

    # Terminator (advanced terminal emulator)
    if ! dpkg -s terminator &> /dev/null 2>&1; then
      echo "Installing Terminator..."
      apt_get install -y terminator
    fi

    # VS Code Desktop (runs inside the XFCE desktop session)
    if ! command -v code &> /dev/null; then
      echo "Installing VS Code Desktop..."
      wget -q -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
      apt_get install -y /tmp/vscode.deb
      rm -f /tmp/vscode.deb
    fi

    # -----------------------------
    # GitHub CLI
    # -----------------------------
    if ! command -v gh &> /dev/null; then
      echo "Installing GitHub CLI..."
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update
      apt_get install -y gh
    fi

    # -----------------------------
    # Node.js global packages (Node pre-installed in enterprise-node image)
    # -----------------------------
    %{if data.coder_parameter.install_node.value == "true"}
    echo "Installing Node.js global packages..."
    # Skip yarn (pre-installed in enterprise-node), install others
    sudo npm install -g pnpm typescript ts-node eslint prettier || true
    %{endif}

    # -----------------------------
    # Python Tools
    # -----------------------------
    %{if data.coder_parameter.install_python.value == "true"}
    echo "Installing Python tools..."
    apt_get install -y python3 python3-pip python3-venv pipx
    # Use --break-system-packages since this is an isolated container (PEP 668)
    pip3 install --user --break-system-packages --upgrade pip
    pip3 install --user --break-system-packages poetry black ruff mypy pytest ipython
    # Ensure pipx bin is in PATH
    pipx ensurepath
    %{endif}

    # -----------------------------
    # Go
    # -----------------------------
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

    # -----------------------------
    # Rust
    # -----------------------------
    %{if data.coder_parameter.install_rust.value == "true"}
    if ! command -v rustc &> /dev/null; then
      echo "Installing Rust..."
      # libssl-dev is needed for crates that link against OpenSSL.
      # Installed here (not globally) to avoid version conflicts with the desktop image.
      apt_get install -y libssl-dev || true
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      source "$HOME/.cargo/env"
      rustup component add rust-analyzer clippy rustfmt
    fi
    %{endif}

    # -----------------------------
    # Roo Code AI Bridge Configuration
    # -----------------------------
    # Create Roo Code settings in code-server's globalStorage location
    # This pre-configures the extension to use AI Bridge
    ROOCODE_STORAGE="/home/coder/.local/share/code-server/User/globalStorage/rooveterinaryinc.roo-cline"
    mkdir -p "$ROOCODE_STORAGE/settings"

    # Write provider profiles directly to globalStorage
    cat > "$ROOCODE_STORAGE/settings/provider_profiles.json" << ROOCONFIG
{
  "currentApiConfigName": "AI Bridge (Anthropic)",
  "apiConfigs": {
    "AI Bridge (Anthropic)": {
      "apiProvider": "anthropic",
      "anthropicBaseUrl": "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic",
      "anthropicApiKey": "$ANTHROPIC_API_KEY",
      "apiModelId": "claude-opus-4-5-20251101"
    }
  }
}
ROOCONFIG

    # Also create auto-import file with correct structure
    mkdir -p /home/coder/.config/roo-code
    cat > /home/coder/.config/roo-code/ai-bridge-settings.json << ROOCONFIG2
{
  "providerProfiles": {
    "currentApiConfigName": "AI Bridge (Anthropic)",
    "apiConfigs": {
      "AI Bridge (Anthropic)": {
        "apiProvider": "anthropic",
        "anthropicBaseUrl": "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic",
        "anthropicApiKey": "$ANTHROPIC_API_KEY",
        "apiModelId": "claude-opus-4-5-20251101"
      }
    }
  }
}
ROOCONFIG2
    echo "Roo Code AI Bridge configuration created"

    # -----------------------------
    # Shell Configuration
    # -----------------------------
    # Set up starship prompt if not present
    if ! command -v starship &> /dev/null; then
      echo "Installing starship prompt..."
      curl -sS https://starship.rs/install.sh | sh -s -- -y
      echo 'eval "$(starship init bash)"' >> ~/.bashrc
    fi

    # Mux AI provider configuration
    mkdir -p ~/.mux
    echo '${replace(jsonencode(local.mux_provider_settings), "'", "'\\''")}' > ~/.mux/providers.jsonc

    echo "=== Universal Workspace Ready ==="
    echo ""
    echo "Installed tools:"
    echo "  - gh: $(gh --version | head -1)"
    %{if data.coder_parameter.install_node.value == "true"}
    echo "  - node: $(node --version 2>/dev/null || echo 'pending')"
    echo "  - npm: $(npm --version 2>/dev/null || echo 'pending')"
    %{endif}
    %{if data.coder_parameter.install_python.value == "true"}
    echo "  - python: $(python3 --version)"
    %{endif}
    %{if data.coder_parameter.install_go.value == "true"}
    echo "  - go: $(go version 2>/dev/null || echo 'pending')"
    %{endif}
    %{if data.coder_parameter.install_rust.value == "true"}
    echo "  - rust: $(rustc --version 2>/dev/null || echo 'pending')"
    %{endif}
    echo ""
    echo "Desktop GUI:"
    echo "  - XFCE Desktop: Available via KasmVNC in the Coder dashboard"
    echo "  - Google Chrome: $(google-chrome --version 2>/dev/null || echo 'pending')"
    echo "  - Terminator: $(terminator --version 2>/dev/null || echo 'pending')"
    echo "  - VS Code Desktop: $(code --version 2>/dev/null | head -1 || echo 'pending')"
    echo ""
    echo "AI Tools configured:"
    echo "  - Claude Code: Available via 'claude' command"
    echo "  - Aider: Available via 'aider' command (AI Bridge pre-configured)"
    echo "  - Roo Code: VS Code extension (requires one-time API key entry)"
    echo "  - AI Bridge: ANTHROPIC_BASE_URL/API_BASE and OPENAI_BASE_URL configured"
  EOT

  # AI Bridge environment variables - routes AI requests through Coder's AI Bridge
  env = {
    # Anthropic API access via AI Bridge
    ANTHROPIC_BASE_URL = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
    # OpenAI API access via AI Bridge
    OPENAI_BASE_URL = "${data.coder_workspace.me.access_url}/api/v2/aibridge/openai"
    # Aider/LiteLLM uses ANTHROPIC_API_BASE instead of ANTHROPIC_BASE_URL
    ANTHROPIC_API_BASE = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
    # GitHub token for git operations (set via external auth if configured)
    # GITHUB_TOKEN = data.coder_external_auth.github.access_token
    # Editor configuration
    EDITOR = "code"
    VISUAL = "code"
  }

  # Workspace metadata displayed in Coder UI
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

locals {
  claude_settings = {
    env = {
      ANTHROPIC_BASE_URL   = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
      ANTHROPIC_AUTH_TOKEN  = data.coder_workspace_owner.me.session_token
      OPENAI_BASE_URL      = "${data.coder_workspace.me.access_url}/api/v2/aibridge/openai"
      ANTHROPIC_MODEL              = "anthropic.claude-opus-4-5-20251101-v1:0"
      ANTHROPIC_SMALL_FAST_MODEL   = "anthropic.claude-haiku-4-5-20251001-v1:0"
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

# -----------------------------------------------------------------------------
# AI Bridge API Keys (uses Coder session token for authentication)
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# IDE Modules
# -----------------------------------------------------------------------------

# Web-based VS Code (code-server)
module "code-server" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/code-server/coder"
  version   = "1.3.1"
  agent_id  = coder_agent.main.id
  folder    = "/home/coder"
  subdomain = true # Enforce subdomain apps for security (XSS prevention)

  # Install Roo Code extension for AI-assisted development
  extensions = [
    "RooVeterinaryInc.roo-cline"
  ]

  # Configure Roo Code to auto-import AI Bridge settings
  machine-settings = {
    "roo-cline.autoImportSettingsPath" = "/home/coder/.config/roo-code/ai-bridge-settings.json"
  }
}

# VS Code Desktop (connects via Coder Desktop or SSH)
module "vscode-desktop" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/vscode-desktop/coder"
  version  = "1.1.1"
  agent_id = coder_agent.main.id
  folder   = "/home/coder"
}

# Cursor Desktop (AI-native code editor)
module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.0.22"
  agent_id = coder_agent.main.id
  folder   = "/home/coder"
}

# -----------------------------------------------------------------------------
# Terminal Multiplexer
# -----------------------------------------------------------------------------

# Coder Mux - web-based terminal multiplexer for persistent sessions
module "mux" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/mux/coder"
  version   = "1.0.7"
  agent_id  = coder_agent.main.id
  subdomain = true # Enforce subdomain apps for security (XSS prevention)
}

# -----------------------------------------------------------------------------
# AI Tools
# -----------------------------------------------------------------------------

# Claude Code - AI coding assistant
# Automatically configured to use AI Bridge via ANTHROPIC_BASE_URL env var
module "claude-code" {
  count               = data.coder_workspace.me.start_count
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

resource "coder_ai_task" "this" {
  app_id = try(module.claude-code[0].task_app_id, "00000000-0000-0000-0000-000000000000")
}

module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.0.15"
  agent_id = coder_agent.main.id
}

# Aider - AI pair programming in your terminal
# Uses ANTHROPIC_API_KEY and ANTHROPIC_API_BASE env vars for AI Bridge
module "aider" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/aider/coder"
  version     = "2.0.1"
  agent_id    = coder_agent.main.id
  workdir     = "/home/coder"
  ai_provider = "anthropic"
  model       = "claude-opus-4-5-20251101"
  subdomain   = true # Enforce subdomain apps for security (XSS prevention)
}

# Codex - OpenAI coding agent
module "codex" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder-labs/codex/coder"
  agent_id  = coder_agent.main.id
  workdir   = "/home/coder"
  subdomain = true
}

# -----------------------------------------------------------------------------
# Desktop GUI
# -----------------------------------------------------------------------------

# KasmVNC - browser-accessible desktop (XFCE)
# Requires a pre-installed desktop environment in the container image.
# See https://registry.coder.com/modules/coder/kasmvnc
module "kasmvnc" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder/kasmvnc/coder"
  version             = "1.2.7"
  agent_id            = coder_agent.main.id
  desktop_environment = "xfce"
  subdomain           = true # Enforce subdomain apps for security (XSS prevention)
}

# -----------------------------------------------------------------------------
# Utility Modules
# -----------------------------------------------------------------------------

# Apply user's dotfiles on workspace start
module "dotfiles" {
  count        = data.coder_parameter.dotfiles_url.value != "" ? data.coder_workspace.me.start_count : 0
  source       = "registry.coder.com/coder/dotfiles/coder"
  version      = "1.0.23"
  agent_id     = coder_agent.main.id
  dotfiles_uri = data.coder_parameter.dotfiles_url.value
}

# Clone a git repository on workspace start
module "git-clone" {
  count    = data.coder_parameter.git_repo.value != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.0.22"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_repo.value
  base_dir = "/home/coder"
}

# Web-based file browser
module "filebrowser" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/filebrowser/coder"
  version   = "1.0.21"
  agent_id  = coder_agent.main.id
  folder    = "/home/coder"
  subdomain = true # Enforce subdomain apps for security (XSS prevention)
}

# -----------------------------------------------------------------------------
# Kubernetes Resources
# -----------------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
      "app.kubernetes.io/part-of"  = "coder"
      "workspace.coder.com/type"   = "universal"
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
    name      = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
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
      image             = "codercom/enterprise-node:ubuntu"
      image_pull_policy = "Always"
      command = ["sh", "-c", <<-EOF
        # Install desktop environment before starting the Coder agent.
        # Must run before init_script so KasmVNC finds a working desktop.
        sudo rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null || true
        sudo apt-get update -y
        sudo apt-get install -y --no-install-recommends xfce4 dbus-x11
        ${coder_agent.main.init_script}
      EOF
      ]

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
          "memory" = "${data.coder_parameter.memory.value / 2}Gi"
        }
        limits = {
          "cpu"    = "4"
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
    }
        }
      }
    }
  }
}

# =============================================================================
# TrailCrawlr Dev — Kubernetes Development Template
# =============================================================================
# Fullstack dev workspace for the TrailCrawlr web application.
# All services run as containers inside a single Kubernetes pod.
#
# Services:
#   - Dev container (Node.js + pnpm) — main workspace
#   - PostGIS sidecar (PostgreSQL 16 + PostGIS 3.4)
#   - Redis sidecar (Redis 7 Alpine with AOF persistence)
#
# Web IDEs:
#   - code-server (VS Code in the browser)
#   - mux (terminal multiplexer)
# Desktop IDEs:
#   - Cursor IDE (AI-powered VS Code fork)
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

data "coder_external_auth" "gitlab" {
  id       = "gitlab"
  optional = true
}

data "coder_external_auth" "github" {
  id       = "github"
  optional = true
}

# -----------------------------------------------------------------------------
# Parameters — workspace sizing and optional features
# -----------------------------------------------------------------------------

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

data "coder_parameter" "postgres_password" {
  name         = "postgres_password"
  display_name = "PostgreSQL Password"
  description  = "PostgreSQL password for the trailcrawlr database"
  type         = "string"
  default      = "trailcrawlr"
  mutable      = true
  icon         = "/icon/database.svg"
}

# -----------------------------------------------------------------------------
# Agent — startup script sets up TrailCrawlr dev environment
# -----------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # The startup script runs on every workspace start. It:
  #   1. Sets up PATH for npm global bin, ~/.local/bin
  #   2. Installs common development packages via apt
  #   3. Installs pnpm via corepack
  #   4. Clones the TrailCrawlr repository
  #   5. Waits for PostGIS and Redis sidecars
  #   6. Creates the PostGIS extension
  #   7. Generates a .env file and installs dependencies
  startup_script = <<-EOT
    #!/bin/bash
    touch ~/.bashrc

    # Set up PATH (npm global bin + ~/.local/bin)
    NPM_BIN="$(npm config get prefix)/bin"
    export PATH="$HOME/.local/bin:$NPM_BIN:$PATH"

    # Persist PATH additions in .profile (sourced by login shells / Coder terminal)
    for P in "$HOME/.local/bin" "$NPM_BIN"; do
      grep -qF "$P" ~/.profile 2>/dev/null || echo "export PATH=\"$P:\$PATH\"" >> ~/.profile
    done

    # Remove stale Yarn apt repo (expired GPG key causes apt-get update warnings)
    sudo rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null || true

    # Install common development tools
    echo "Installing development tools..."
    sudo apt-get update -qq

    # Critical — needed for the agent to operate reliably
    sudo apt-get install -y -qq \
      git \
      curl \
      wget \
      ca-certificates \
      openssh-client \
      jq \
      ripgrep \
      fd-find \
      build-essential \
      pkg-config \
      python3 \
      python3-pip \
      unzip \
      tar \
      gzip \
      procps \
      lsof \
      sed \
      gawk \
      postgresql-client \
      redis-tools \
      > /dev/null 2>&1 || true

    # Nice-to-have — improve agent speed and output quality
    sudo apt-get install -y -qq \
      tree \
      shellcheck \
      diffutils \
      inotify-tools \
      netcat-openbsd \
      dnsutils \
      > /dev/null 2>&1 || true

    # Create fd symlink (Debian/Ubuntu packages fd-find as fdfind)
    if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
      sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
    fi

    # Install pnpm via corepack (sudo required — symlinks into /usr/bin/)
    sudo corepack enable && corepack prepare pnpm@9.15.0 --activate

    # Clone TrailCrawlr repository
    git clone https://gitlab.zambruhni.com/trailcrawlr/trailcrawlr.git /home/coder/trailcrawlr || true

    # Wait for PostgreSQL sidecar to be ready
    # First boot is slow: image pull + initdb + PostGIS extension creation
    # can take 2–3 minutes, so we allow up to 90 × 2s = 180s.
    echo "Waiting for PostgreSQL..."
    PG_READY=false
    for i in $(seq 1 90); do
      if pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
        echo "PostgreSQL is ready."
        PG_READY=true
        break
      fi
      echo "  ...waiting ($i/90)"
      sleep 2
    done
    if [ "$PG_READY" != "true" ]; then
      echo "ERROR: PostgreSQL sidecar did not become ready within 180s."
    fi

    # Wait for Redis sidecar to be ready
    echo "Waiting for Redis..."
    for i in $(seq 1 90); do
      if nc -z localhost 6379 > /dev/null 2>&1; then
        echo "Redis is ready."
        break
      fi
      echo "  ...waiting ($i/90)"
      sleep 2
    done

    # Create PostGIS extension (only if PostgreSQL came up)
    if [ "$PG_READY" = "true" ]; then
      PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U trailcrawlr -d trailcrawlr -c "CREATE EXTENSION IF NOT EXISTS postgis;" || true
    fi

    # Set up .env if it does not already exist
    mkdir -p /home/coder/trailcrawlr
    if [ ! -f /home/coder/trailcrawlr/.env ]; then
      {
        echo "DATABASE_URL=$DATABASE_URL"
        echo "REDIS_URL=$REDIS_URL"
        echo "PORT=3001"
        echo "NODE_ENV=development"
      } > /home/coder/trailcrawlr/.env
    fi

    # Install dependencies
    if [ -f /home/coder/trailcrawlr/package.json ]; then
      cd /home/coder/trailcrawlr && pnpm install
    fi

    echo "=== Workspace Ready ==="
  EOT

  env = {
    EDITOR                     = "code"
    VISUAL                     = "code"
    DATABASE_URL               = "postgresql://trailcrawlr:${data.coder_parameter.postgres_password.value}@localhost:5432/trailcrawlr"
    REDIS_URL                  = "redis://localhost:6379"
    POSTGRES_PASSWORD          = data.coder_parameter.postgres_password.value
    COREPACK_DEFAULT_TO_LATEST = "0"
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
# Coder Apps — TrailCrawlr services
# -----------------------------------------------------------------------------

resource "coder_app" "frontend" {
  agent_id     = coder_agent.main.id
  slug         = "frontend"
  display_name = "Frontend"
  url          = "http://localhost:5173"
  icon         = "/icon/widgets.svg"
  subdomain    = true
}

resource "coder_app" "api" {
  agent_id     = coder_agent.main.id
  slug         = "api"
  display_name = "API"
  url          = "http://localhost:3001"
  icon         = "/icon/database.svg"
  subdomain    = true
}

# -----------------------------------------------------------------------------
# Coder Registry Modules
# -----------------------------------------------------------------------------

# --- Web IDEs ---

# code-server — VS Code in the browser, accessible via subdomain
module "code-server" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/code-server/coder"
  version   = "1.3.1"
  agent_id  = coder_agent.main.id
  folder    = "/home/coder"
  subdomain = true
  group     = "Web IDEs"
  order     = 1
}

# mux — terminal multiplexer
module "mux" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/mux/coder"
  version   = "1.4.3"
  agent_id  = coder_agent.main.id
  subdomain = true
  group     = "Web IDEs"
  order     = 2
}

# --- Desktop IDEs ---

# cursor — Cursor Desktop IDE connection (external app)
module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.4.1"
  agent_id = coder_agent.main.id
  folder   = "/home/coder"
  group    = "Desktop IDEs"
  order    = 3
}

# --- Utilities ---

# dotfiles — clone and apply user dotfiles on workspace start
module "dotfiles" {
  count        = data.coder_parameter.dotfiles_url.value != "" ? data.coder_workspace.me.start_count : 0
  source       = "registry.coder.com/coder/dotfiles/coder"
  version      = "1.0.23"
  agent_id     = coder_agent.main.id
  dotfiles_uri = data.coder_parameter.dotfiles_url.value
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

resource "kubernetes_persistent_volume_claim_v1" "pgdata" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-pgdata"
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
        storage = "10Gi"
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

    # ----- Dev container (main workspace) -----
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

    # ----- PostGIS sidecar -----
    container {
      name              = "postgres"
      image             = "postgis/postgis:16-3.4"
      image_pull_policy = "IfNotPresent"

      security_context {
        run_as_user = 999
      }

      env {
        name  = "POSTGRES_USER"
        value = "trailcrawlr"
      }

      env {
        name  = "POSTGRES_PASSWORD"
        value = data.coder_parameter.postgres_password.value
      }

      env {
        name  = "POSTGRES_DB"
        value = "trailcrawlr"
      }

      port {
        container_port = 5432
        protocol       = "TCP"
      }

      resources {
        requests = {
          "cpu"    = "250m"
          "memory" = "256Mi"
        }
        limits = {
          "cpu"    = "1"
          "memory" = "2Gi"
        }
      }

      # Mount PVC at the parent directory so fsGroup ownership (GID 1000)
      # is applied correctly. PGDATA defaults to /var/lib/postgresql/data
      # inside the image, so postgres creates the data/ subdirectory itself.
      # Do NOT use sub_path here — Kubernetes skips fsGroup for sub_path
      # mounts, which causes permission-denied crashes for UID 999.
      volume_mount {
        mount_path = "/var/lib/postgresql"
        name       = "pgdata"
        read_only  = false
      }
    }

    # ----- Redis sidecar -----
    container {
      name              = "redis"
      image             = "redis:7-alpine"
      image_pull_policy = "IfNotPresent"
      command           = ["redis-server", "--appendonly", "yes"]

      security_context {
        run_as_user = 999
      }

      port {
        container_port = 6379
        protocol       = "TCP"
      }

      resources {
        requests = {
          "cpu"    = "100m"
          "memory" = "128Mi"
        }
        limits = {
          "cpu"    = "500m"
          "memory" = "512Mi"
        }
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
      }
    }

    volume {
      name = "pgdata"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.pgdata.metadata[0].name
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

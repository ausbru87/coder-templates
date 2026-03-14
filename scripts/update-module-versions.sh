#!/usr/bin/env bash
# Update module versions in versions.json and main.tf files, then open a GitLab MR.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_FILE="$REPO_ROOT/versions.json"
GITLAB_API="${GITLAB_API_URL:-https://gitlab.zambruhni.com/api/v4}"
GITLAB_PROJECT="${GITLAB_PROJECT_ID:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"

if [ ! -f "$VERSIONS_FILE" ]; then
  echo "ERROR: versions.json not found at $VERSIONS_FILE"
  exit 1
fi

UPDATED_MODULES=""

echo "Checking for module updates..."

for MODULE in $(jq -r 'keys[]' "$VERSIONS_FILE"); do
  CURRENT=$(jq -r ".[\"$MODULE\"]" "$VERSIONS_FILE")

  case "$MODULE" in
    codex) ORG="coder-labs" ;;
    *)     ORG="coder" ;;
  esac

  REGISTRY_URL="https://registry.coder.com/api/v2/modules/${ORG}/${MODULE}/versions"
  RESPONSE=$(curl -sf "$REGISTRY_URL" 2>/dev/null || echo "")

  if [ -z "$RESPONSE" ]; then
    echo "  WARN: Could not fetch versions for $MODULE"
    continue
  fi

  LATEST=$(echo "$RESPONSE" | jq -r '.[0].version // empty' 2>/dev/null || echo "")
  if [ -z "$LATEST" ]; then
    LATEST=$(echo "$RESPONSE" | jq -r '.versions[0].version // empty' 2>/dev/null || echo "")
  fi
  if [ -z "$LATEST" ]; then
    continue
  fi

  if [ "$CURRENT" != "$LATEST" ]; then
    echo "  Updating $MODULE: $CURRENT -> $LATEST"

    # Update versions.json
    TMP=$(mktemp)
    jq ".[\"$MODULE\"] = \"$LATEST\"" "$VERSIONS_FILE" > "$TMP" && mv "$TMP" "$VERSIONS_FILE"

    # Update main.tf files: match version line that follows a source line for this module
    # Pattern: source = "registry.coder.com/coder/<module>/coder" (or coder-labs)
    find "$REPO_ROOT/templates" "$REPO_ROOT/task-runners" -name "main.tf" 2>/dev/null | while read -r TF_FILE; do
      # Use sed to replace version on the line following the matching source line
      sed -i.bak -E \
        "/source[[:space:]]*=[[:space:]]*\"registry\.coder\.com\/${ORG//\//\\/}\/${MODULE}\/coder\"/{n;s/version[[:space:]]*=[[:space:]]*\"[^\"]+\"/version   = \"${LATEST}\"/;}" \
        "$TF_FILE"
      rm -f "${TF_FILE}.bak"
    done

    UPDATED_MODULES="${UPDATED_MODULES}${MODULE}: ${CURRENT} -> ${LATEST}\n"
  fi
done

if [ -z "$UPDATED_MODULES" ]; then
  echo ""
  echo "All modules are already up to date."
  exit 0
fi

echo ""
echo "Updated modules:"
echo -e "$UPDATED_MODULES"

# Run terraform init to update lock files
for TF_DIR in "$REPO_ROOT"/templates/*/ "$REPO_ROOT"/task-runners/*/; do
  if [ -f "$TF_DIR/main.tf" ]; then
    echo "Running terraform init in $TF_DIR..."
    (cd "$TF_DIR" && terraform init -upgrade -backend=false) || true
  fi
done

# Create branch, commit, and open MR
BRANCH="auto/update-module-versions-$(date +%Y%m%d-%H%M%S)"
cd "$REPO_ROOT"

git checkout -b "$BRANCH"
git add versions.json "templates/*/main.tf" "templates/*/.terraform.lock.hcl" "task-runners/*/main.tf" "task-runners/*/.terraform.lock.hcl"
git commit -m "chore: update module versions

$(echo -e "$UPDATED_MODULES")"

git push origin "$BRANCH"

# Open GitLab MR if credentials are available
if [ -n "$GITLAB_PROJECT" ] && [ -n "$GITLAB_TOKEN" ]; then
  echo "Creating GitLab merge request..."
  MR_BODY=$(printf 'Auto-generated module version update.\n\n```\n%s```' "$(echo -e "$UPDATED_MODULES")")

  curl -sf --request POST "$GITLAB_API/projects/$GITLAB_PROJECT/merge_requests" \
    --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    --header "Content-Type: application/json" \
    --data "$(jq -n \
      --arg source "$BRANCH" \
      --arg target "main" \
      --arg title "chore: update module versions" \
      --arg desc "$MR_BODY" \
      '{source_branch: $source, target_branch: $target, title: $title, description: $desc}')" \
    | jq '{web_url, iid}'
else
  echo "GITLAB_PROJECT_ID and GITLAB_TOKEN not set — skipping MR creation."
  echo "Push the branch manually: git push origin $BRANCH"
fi

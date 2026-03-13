#!/usr/bin/env bash
# Wipe all workspaces and templates from a Coder instance, then push the fresh universal template.
set -euo pipefail

CODER_URL="${CODER_URL:-https://dev.zambruhni.com}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/templates/universal"

echo "=== Coder Cleanup ==="
echo "Target: $CODER_URL"
echo ""

# Verify coder CLI is available and authenticated
if ! command -v coder &> /dev/null; then
  echo "ERROR: 'coder' CLI not found. Install from https://coder.com/docs/install"
  exit 1
fi

if ! coder whoami &> /dev/null 2>&1; then
  echo "Not authenticated. Run: coder login $CODER_URL"
  exit 1
fi

echo "Authenticated as: $(coder whoami 2>/dev/null | head -1)"
echo ""

# Confirmation prompt
read -rp "This will DELETE all workspaces and templates on $CODER_URL. Continue? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""

# Delete all workspaces
echo "--- Deleting workspaces ---"
WORKSPACES=$(coder list --output json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "")
if [ -z "$WORKSPACES" ]; then
  echo "No workspaces found."
else
  echo "$WORKSPACES" | while read -r WS; do
    [ -z "$WS" ] && continue
    echo "  Deleting workspace: $WS"
    coder delete "$WS" --orphan --yes 2>/dev/null || true
  done
fi

echo ""

# Delete all templates
echo "--- Deleting templates ---"
TEMPLATES=$(coder templates list --output json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "")
if [ -z "$TEMPLATES" ]; then
  echo "No templates found."
else
  echo "$TEMPLATES" | while read -r TPL; do
    [ -z "$TPL" ] && continue
    echo "  Deleting template: $TPL"
    coder templates delete "$TPL" --yes 2>/dev/null || true
  done
fi

echo ""

# Push fresh universal template
echo "--- Pushing universal template ---"
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "ERROR: Template directory not found: $TEMPLATE_DIR"
  exit 1
fi

coder templates push universal \
  --directory "$TEMPLATE_DIR" \
  --yes

echo ""
echo "=== Cleanup complete ==="
echo "Template 'universal' is now the only template on $CODER_URL"

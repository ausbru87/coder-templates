#!/usr/bin/env bash
# Check Coder registry modules for newer versions than versions.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_FILE="$REPO_ROOT/versions.json"

if [ ! -f "$VERSIONS_FILE" ]; then
  echo "ERROR: versions.json not found at $VERSIONS_FILE"
  exit 1
fi

OUTDATED=0

echo "Checking module versions..."
echo ""

for MODULE in $(jq -r 'keys[]' "$VERSIONS_FILE"); do
  CURRENT=$(jq -r ".[\"$MODULE\"]" "$VERSIONS_FILE")

  # Determine the registry org
  # codex, gemini → coder-labs; kiro-cli → harleylrn; all others → coder
  case "$MODULE" in
    codex|gemini) ORG="coder-labs" ;;
    kiro-cli)     ORG="harleylrn" ;;
    *)            ORG="coder" ;;
  esac

  # Query the Coder module registry API
  REGISTRY_URL="https://registry.coder.com/api/v2/modules/${ORG}/${MODULE}/versions"
  RESPONSE=$(curl -sf "$REGISTRY_URL" 2>/dev/null || echo "")

  if [ -z "$RESPONSE" ]; then
    echo "  WARN: Could not fetch versions for $MODULE ($REGISTRY_URL)"
    continue
  fi

  # The API returns an array of version objects; grab the latest
  LATEST=$(echo "$RESPONSE" | jq -r '.[0].version // empty' 2>/dev/null || echo "")

  if [ -z "$LATEST" ]; then
    # Try alternate response shape: { versions: [...] }
    LATEST=$(echo "$RESPONSE" | jq -r '.versions[0].version // empty' 2>/dev/null || echo "")
  fi

  if [ -z "$LATEST" ]; then
    echo "  WARN: Could not parse latest version for $MODULE"
    continue
  fi

  if [ "$CURRENT" = "$LATEST" ]; then
    echo "  OK: $MODULE $CURRENT (up to date)"
  else
    echo "  UPDATE: $MODULE $CURRENT -> $LATEST"
    OUTDATED=1
  fi
done

echo ""
if [ "$OUTDATED" -eq 1 ]; then
  echo "Some modules are outdated. Run scripts/update-module-versions.sh to update."
  exit 1
else
  echo "All modules are up to date."
  exit 0
fi

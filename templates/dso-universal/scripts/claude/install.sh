#!/usr/bin/env bash
set -euo pipefail

mkdir -p '${HOME_FOLDER}/.claude'
echo '${SETTINGS}' | jq | tee '${HOME_FOLDER}/.claude/settings.json' >/dev/null

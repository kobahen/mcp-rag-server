#!/bin/bash
set -euo pipefail

SRC="$HOME/Dropbox/ObsidianVault_REFACTOR/"
DST="$HOME/mcp-rag-server/data/source/"

rsync -avh --delete \
  --include="*/" \
  --include="*.md" \
  --exclude="*" \
  "$SRC" "$DST"

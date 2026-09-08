#!/usr/bin/env bash
set -euo pipefail

# bash環境によっては HISTTIMEFORMAT が未定義で落ちるので保険
export HISTTIMEFORMAT="${HISTTIMEFORMAT-}"

# ===== パス（確定）=====
RAG_ROOT="/Users/kobayashihiroto/mcp-rag-server"

# ログ
LOG_DIR="$RAG_ROOT/_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/sync_$(date +%Y%m%d).log"

echo "=== $(date) reindex start ===" | tee -a "$LOG_FILE"

cd "$RAG_ROOT"
uv run python -m src.cli index 2>&1 | tee -a "$LOG_FILE"

echo "=== $(date) reindex done ===" | tee -a "$LOG_FILE"

#!/usr/bin/env bash
set -euo pipefail

# bash環境によっては HISTTIMEFORMAT が未定義で落ちるので保険
export HISTTIMEFORMAT="${HISTTIMEFORMAT-}"

# launchd PATH may be minimal even with bash -lc; keep uv reachable
export PATH="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

# ===== パス（確定）=====
RAG_ROOT="${HOME}/mcp-rag-server"
LOCK_ROOT="${RAG_ROOT}/.locks"
LOCK_DIR="${LOCK_ROOT}/rag-index.lock"
PID_FILE="${LOCK_DIR}/pid"

# ログ
LOG_DIR="${RAG_ROOT}/_logs"
mkdir -p "${LOG_DIR}" "${LOCK_ROOT}"
LOG_FILE="${LOG_DIR}/sync_$(date +%Y%m%d).log"

release_lock() {
  if [[ -d "${LOCK_DIR}" ]]; then
    if [[ ! -f "${PID_FILE}" ]] || [[ "$(cat "${PID_FILE}" 2>/dev/null || true)" == "$$" ]]; then
      rm -rf "${LOCK_DIR}"
    fi
  fi
}

acquire_lock() {
  local other_pid=""
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    echo "$$" > "${PID_FILE}"
    return 0
  fi

  other_pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${other_pid}" ]] && kill -0 "${other_pid}" 2>/dev/null; then
    echo "rag-index lock held by live pid ${other_pid}; skipping weekly clear/index" | tee -a "${LOG_FILE}"
    exit 0
  fi

  echo "stale rag-index lock (pid='${other_pid:-none}'); reclaiming" | tee -a "${LOG_FILE}"
  rm -rf "${LOCK_DIR}"
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    echo "$$" > "${PID_FILE}"
    return 0
  fi

  echo "failed to acquire rag-index lock; skipping weekly clear/index" | tee -a "${LOG_FILE}"
  exit 0
}

acquire_lock
trap release_lock EXIT INT TERM

echo "=== $(date) weekly clear→full index start ===" | tee -a "${LOG_FILE}"

cd "${RAG_ROOT}"

echo "=== $(date) clear start ===" | tee -a "${LOG_FILE}"
uv run python -m src.cli clear 2>&1 | tee -a "${LOG_FILE}"
echo "=== $(date) clear done ===" | tee -a "${LOG_FILE}"

echo "=== $(date) full index start ===" | tee -a "${LOG_FILE}"
uv run python -m src.cli index 2>&1 | tee -a "${LOG_FILE}"
echo "=== $(date) full index done ===" | tee -a "${LOG_FILE}"

echo "=== $(date) weekly clear→full index complete ===" | tee -a "${LOG_FILE}"

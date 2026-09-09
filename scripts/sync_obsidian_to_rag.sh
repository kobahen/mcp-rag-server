#!/bin/bash
set -euo pipefail

# launchd PATH is minimal; ensure uv is reachable (2h job uses bash -lc instead)
export PATH="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

RAG_ROOT="${HOME}/mcp-rag-server"
SRC="${HOME}/Dropbox/ObsidianVault_REFACTOR/"
DST="${RAG_ROOT}/data/source/"
LOCK_ROOT="${RAG_ROOT}/.locks"
LOCK_DIR="${LOCK_ROOT}/rag-index.lock"
PID_FILE="${LOCK_DIR}/pid"

mkdir -p "${LOCK_ROOT}"

release_lock() {
  if [[ -d "${LOCK_DIR}" ]]; then
    # Only remove if we own it (our pid), or pid file missing after we created the dir.
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
    echo "rag-index lock held by live pid ${other_pid}; skipping"
    exit 0
  fi

  echo "stale rag-index lock (pid='${other_pid:-none}'); reclaiming"
  rm -rf "${LOCK_DIR}"
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    echo "$$" > "${PID_FILE}"
    return 0
  fi

  echo "failed to acquire rag-index lock; skipping"
  exit 0
}

acquire_lock
trap release_lock EXIT INT TERM

RSYNC_OUT="$(mktemp)"
cleanup_tmp() {
  rm -f "${RSYNC_OUT}"
  release_lock
}
trap cleanup_tmp EXIT INT TERM

# md-only mirror with itemize for change detection
rsync -ai --delete \
  --include="*/" \
  --include="*.md" \
  --exclude="*" \
  "${SRC}" "${DST}" | tee "${RSYNC_OUT}"

# Change if md transferred/updated or deleted (ignore directory-only lines like cd++++++)
if grep -E '(^\*deleting)|(^>f)|(^\.f)' "${RSYNC_OUT}" >/dev/null 2>&1; then
  echo "source changes detected; running incremental index"
  cd "${RAG_ROOT}"
  uv run python -m src.cli index --incremental
  echo "incremental index done"
else
  echo "no markdown content changes; skipping incremental index"
fi

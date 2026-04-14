#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/hermes-agent [--with-skill-loader-fix]" >&2
  exit 1
fi

REPO_DIR="$1"
shift || true

WITH_SKILL_LOADER_FIX="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-skill-loader-fix)
      WITH_SKILL_LOADER_FIX="true"
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="${SCRIPT_DIR%/scripts}/patches"

if ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository or worktree: $REPO_DIR" >&2
  exit 1
fi

apply_patch_file() {
  local patch_file="$1"
  echo "Checking ${patch_file##*/}"
  git -C "$REPO_DIR" apply --check "$patch_file"
  echo "Applying ${patch_file##*/}"
  git -C "$REPO_DIR" apply "$patch_file"
}

apply_patch_file "$PATCH_DIR/0001-custom-codex-runtime-detection.patch"
apply_patch_file "$PATCH_DIR/0002-codex-proxy-cache-compat.patch"

if [[ "$WITH_SKILL_LOADER_FIX" == "true" ]]; then
  apply_patch_file "$PATCH_DIR/0003-external-skills-permission-guard.patch"
fi

cat <<'EOF'

Patch application completed.

Suggested verification:
  python3 -m pytest -q -o addopts='' tests/hermes_cli/test_runtime_provider_resolution.py
  PYTHONPATH=/tmp/hermes_test_stubs python3 -m pytest -q -o addopts='' tests/run_agent/test_run_agent_codex_responses.py
  python3 -m pytest -q -o addopts='' tests/test_hermes_state.py

EOF

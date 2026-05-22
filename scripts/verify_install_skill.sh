#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-skill-install.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

run_and_check() {
  local home_path="$1"
  shift

  "$@" >/dev/null
  "$@" >/dev/null

  python3 - "$home_path" <<'PY'
import sys
from pathlib import Path

import yaml

home = Path(sys.argv[1]).resolve()
skill_file = home / "shared-skills" / "codex-proxy-cache-compat" / "SKILL.md"
config_path = home / "config.yaml"

if not skill_file.exists():
    raise SystemExit(f"skill was not copied: {skill_file}")
if not config_path.exists():
    raise SystemExit(f"config was not written: {config_path}")

data = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
dirs = data.get("skills", {}).get("external_dirs")
if isinstance(dirs, str):
    dirs = [dirs]
if not isinstance(dirs, list):
    raise SystemExit(f"skills.external_dirs is not a list/string: {dirs!r}")

config_root = config_path.parent

def canonical(value: object) -> str:
    candidate = Path(str(value)).expanduser()
    if not candidate.is_absolute():
        candidate = config_root / candidate
    return str(candidate.resolve())

expected = str((home / "shared-skills").resolve())
matches = [entry for entry in dirs if canonical(entry) == expected]
if len(matches) != 1:
    raise SystemExit(
        "expected exactly one canonical shared-skills entry; "
        f"got {len(matches)} in {dirs!r}"
    )
PY
}

# Case 1: embedded/WebUI-style runtime should honor HERMES_HOME when no
# explicit install target is passed.
HERMES_HOME_CASE="$TMP_ROOT/hermes-home-env"
mkdir -p "$HERMES_HOME_CASE"
run_and_check "$HERMES_HOME_CASE" env HERMES_HOME="$HERMES_HOME_CASE" bash "$SCRIPT_DIR/install_skill.sh"

# Case 2: if a config already has a relative equivalent path, installation
# should not append a duplicate absolute path.
RELATIVE_CASE="$TMP_ROOT/hermes-home-relative"
mkdir -p "$RELATIVE_CASE"
cat > "$RELATIVE_CASE/config.yaml" <<'YAML'
skills:
  external_dirs:
    - ./shared-skills
YAML
run_and_check "$RELATIVE_CASE" bash "$SCRIPT_DIR/install_skill.sh" "$RELATIVE_CASE"

echo "install_skill verification OK"

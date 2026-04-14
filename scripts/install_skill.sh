#!/usr/bin/env bash
set -euo pipefail

HERMES_HOME_PATH="${1:-$HOME/.hermes}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/scripts}"
SKILL_SOURCE_DIR="$REPO_ROOT/skills/codex-proxy-cache-compat"
SHARED_SKILL_ROOT="$HERMES_HOME_PATH/shared-skills"
SKILL_DEST_DIR="$SHARED_SKILL_ROOT/codex-proxy-cache-compat"
CONFIG_PATH="$HERMES_HOME_PATH/config.yaml"

mkdir -p "$SHARED_SKILL_ROOT"
rm -rf "$SKILL_DEST_DIR"
cp -R "$SKILL_SOURCE_DIR" "$SKILL_DEST_DIR"

python3 - "$CONFIG_PATH" "$SHARED_SKILL_ROOT" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except Exception as exc:  # pragma: no cover
    print(f"PyYAML is required to edit config.yaml automatically: {exc}", file=sys.stderr)
    sys.exit(2)

config_path = Path(sys.argv[1])
shared_root = sys.argv[2]
data = {}

if config_path.exists():
    loaded = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    if isinstance(loaded, dict):
        data = loaded

skills = data.get("skills")
if not isinstance(skills, dict):
    skills = {}
    data["skills"] = skills

external_dirs = skills.get("external_dirs")
if isinstance(external_dirs, str):
    external_dirs = [external_dirs]
elif not isinstance(external_dirs, list):
    external_dirs = []

if shared_root not in external_dirs:
    external_dirs.append(shared_root)

skills["external_dirs"] = external_dirs
config_path.write_text(
    yaml.safe_dump(data, sort_keys=False, allow_unicode=True),
    encoding="utf-8",
)
PY

cat <<EOF
Skill installed to:
  $SKILL_DEST_DIR

Config updated:
  $CONFIG_PATH

Next step:
  Restart the relevant Hermes gateway / profile so the skill becomes visible.
EOF

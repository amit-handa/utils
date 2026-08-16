#!/usr/bin/env bash
set -u
export PYTHONDONTWRITEBYTECODE=1

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PACKAGE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

OS=''
PROFILE=''
UTILS_INPUT=${HOME:-}/utils

usage_error() {
  ws_die 'invalid check arguments'
  exit 2
}

while [ "$#" -gt 0 ]; do
  case $1 in
    --os|--profile|--utils-path)
      [ "$#" -ge 2 ] || usage_error
      case $1 in
        --os) OS=$2 ;;
        --profile) PROFILE=$2 ;;
        --utils-path) UTILS_INPUT=$2 ;;
      esac
      shift 2
      ;;
    --help)
      printf '%s\n' 'usage: check.sh --os macos|linux --profile base|work|mobile [--utils-path PATH]' >&2
      exit 0
      ;;
    *) usage_error ;;
  esac
done

case $OS in macos|linux) ;; *) usage_error ;; esac
case $PROFILE in base|work|mobile) ;; *) usage_error ;; esac
ws_command_exists python3 || { ws_die 'python3 is required for read-only checks'; exit 1; }

realpath_any() {
  python3 - "$1" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

realpath_parent() {
  python3 - "$1" <<'PY'
import os
import sys
path = os.path.abspath(sys.argv[1])
parent = os.path.dirname(path)
while not os.path.lexists(parent):
    next_parent = os.path.dirname(parent)
    if next_parent == parent:
        break
    parent = next_parent
print(os.path.realpath(parent))
PY
}

has_symlink_component() {
  python3 - "$1" <<'PY'
import os
import sys
path = os.path.abspath(sys.argv[1])
current = os.sep
for part in path.split(os.sep):
    if not part:
        continue
    current = os.path.join(current, part)
    if os.path.islink(current):
        raise SystemExit(0)
raise SystemExit(1)
PY
}

path_is_within() {
  local path=$1 root=$2
  case $path in "$root"|"$root"/*) return 0 ;; *) return 1 ;; esac
}

valid_profile_tokens() {
  local tokens=$1 token profile platform old_ifs=$IFS
  [ -n "$tokens" ] || return 1
  IFS='|'
  for token in $tokens; do
    [ -n "$token" ] || { IFS=$old_ifs; return 1; }
    profile=${token%@*}
    platform=''
    case $token in *@*) platform=${token#*@} ;; esac
    case $profile in base|work|mobile) ;; *) IFS=$old_ifs; return 1 ;; esac
    case $platform in ''|macos|linux) ;; *) IFS=$old_ifs; return 1 ;; esac
    case $token in *@*@*) IFS=$old_ifs; return 1 ;; esac
  done
  IFS=$old_ifs
  return 0
}

safe_mapping_relative() {
  case $1 in .|./*|*/./*|*/.) return 1 ;; esac
  ws_safe_relative_path "$1"
}

HOME_CANONICAL=$(realpath_any "${HOME:-}") || { ws_die 'cannot canonicalize HOME'; exit 1; }
UTILS_CANONICAL=$(realpath_any "$UTILS_INPUT") || { ws_die 'cannot canonicalize utils path'; exit 1; }
[ -d "$HOME_CANONICAL" ] && [ -d "$UTILS_CANONICAL" ] || { ws_die 'check source is unavailable'; exit 1; }
case $HOME_CANONICAL in
  "$UTILS_CANONICAL"|"$UTILS_CANONICAL"/*) ws_die 'HOME and utils paths overlap unsafely'; exit 1 ;;
esac
WS_HOME_CANONICAL=$HOME_CANONICAL

CONFIG_SOURCES="$PACKAGE_DIR/references/config-sources.tsv"
[ -r "$CONFIG_SOURCES" ] || { ws_die 'check metadata is unavailable'; exit 1; }

source_preflight() {
  local source_rel=$1 source_path canonical
  safe_mapping_relative "$source_rel" || return 1
  source_path="$UTILS_CANONICAL/$source_rel"
  [ -e "$source_path" ] || [ -L "$source_path" ] || return 1
  [ ! -L "$source_path" ] || return 1
  has_symlink_component "$source_path" && return 1
  canonical=$(realpath_any "$source_path") || return 1
  path_is_within "$canonical" "$UTILS_CANONICAL" || return 1
  [ -f "$canonical" ] || [ -d "$canonical" ] || return 1
  SOURCE_PATH=$source_path
  SOURCE_CANONICAL=$canonical
  return 0
}

destination_preflight() {
  local destination_rel destination_path parent canonical_relative
  safe_mapping_relative "$1" || return 1
  destination_rel=$1
  destination_path="$HOME_CANONICAL/$destination_rel"
  parent=$(realpath_parent "$destination_path") || return 1
  path_is_within "$parent" "$HOME_CANONICAL" || return 1
  canonical_relative=${parent#"$HOME_CANONICAL"/}
  if [ "$parent" = "$HOME_CANONICAL" ]; then
    canonical_relative=''
  else
    canonical_relative="$canonical_relative/${destination_path##*/}"
  fi
  ws_forbidden_relative_path "$canonical_relative" && return 1
  DESTINATION_PATH=$destination_path
  return 0
}

git_config_is_safe() {
  python3 - "$1" <<'PY'
import re
import sys

path = sys.argv[1]
section = ''
try:
    source = open(path, encoding='utf-8', errors='replace')
except OSError:
    raise SystemExit(1)
with source:
    for raw_line in source:
        stripped = raw_line.strip()
        if not stripped or stripped.startswith(('#', ';')):
            continue
        if stripped.startswith('['):
            close = stripped.find(']')
            if close < 0:
                raise SystemExit(1)
            header = stripped[1:close].strip()
            match = re.match(r'([A-Za-z0-9.-]+)(?:\s+.*)?$', header)
            if not match:
                raise SystemExit(1)
            section = match.group(1).lower()
            if section == 'credential' or section.startswith('credential.'):
                raise SystemExit(1)
            continue
        key = stripped.split('=', 1)[0].strip().lower().replace(' ', '')
        value = stripped.split('=', 1)[1].strip() if '=' in stripped else ''
        if section == 'user' and key in {'name', 'email', 'signingkey'}:
            raise SystemExit(1)
        if key in {'user.name', 'user.email', 'user.signingkey', 'credential.helper'}:
            raise SystemExit(1)
        if key.endswith('helper') and value.startswith('/'):
            raise SystemExit(1)
raise SystemExit(0)
PY
}

agent_preference_is_safe() {
  # Args: <id> <source_canonical>
  # Read-only mirror of bootstrap's validate_agent_preference_source: parses
  # the curated JSON source with O_NOFOLLOW and checks it against the strict
  # per-tool key allowlist. Exits nonzero on malformed or disallowed data.
  python3 - "$1" "$2" <<'PY' || return 1
import json
import os
import stat
import sys

pref_id = sys.argv[1]
source = sys.argv[2]


def fail():
    sys.stderr.write('invalid agent preference source %s\n' % pref_id)
    sys.exit(1)


CLAUDE_KEYS = {
    "model", "autoCompactEnabled", "autoCompactWindow",
    "tui", "voice", "voiceEnabled",
}
OMP_KEYS = {
    "defaultThinkingLevel", "theme.dark", "theme.light",
    "symbolPreset", "colorBlindMode",
    "statusLine.preset", "statusLine.separator",
    "statusLine.sessionAccent", "statusLine.compactThinkingLevel",
    "terminal.showProgress", "tui.renderMermaid", "tui.titleState",
    "display.smoothStreaming", "display.showTokenUsage",
}


def is_bytes(value):
    return isinstance(value, bytes)


def is_path_like(value):
    if not isinstance(value, str):
        return False
    return value.startswith("/") or value.startswith("~")


def is_shell_command(value):
    if not isinstance(value, str):
        return False
    return any(ch in value for ch in (";", "|", "`", "$", "&&", "(", ")"))


def is_credential_shaped(value):
    if isinstance(value, bytes):
        return True
    if isinstance(value, str):
        low = value.lower()
        if any(w in low for w in ("secret", "password", "token", "apikey",
                                   "api_key", "credential", "private_key",
                                   "bearer", "authorization")):
            return True
        if is_path_like(value) or is_shell_command(value):
            return True
    if isinstance(value, dict):
        return any(is_credential_shaped(v) for v in value.values())
    if isinstance(value, list):
        return any(is_credential_shaped(v) for v in value)
    return False


def validate_claude(data):
    if not isinstance(data, dict):
        fail()
    for key in data:
        if key not in CLAUDE_KEYS:
            fail()
    for key, value in data.items():
        if is_bytes(value) or is_credential_shaped(value):
            fail()
        if key == "model":
            if not isinstance(value, str):
                fail()
        elif key == "tui":
            if not isinstance(value, str):
                fail()
        elif key == "autoCompactEnabled":
            if not isinstance(value, bool):
                fail()
        elif key == "voiceEnabled":
            if not isinstance(value, bool):
                fail()
        elif key == "autoCompactWindow":
            if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                fail()
        elif key == "voice":
            if not isinstance(value, dict):
                fail()
            if set(value) - {"enabled", "mode"}:
                fail()
            if "enabled" in value and not isinstance(value["enabled"], bool):
                fail()
            if "mode" in value and not isinstance(value["mode"], str):
                fail()
            if is_credential_shaped(value):
                fail()


def validate_omp(data):
    if not isinstance(data, dict):
        fail()
    if set(data) != OMP_KEYS:
        fail()
    for key, value in data.items():
        if is_bytes(value) or is_credential_shaped(value):
            fail()
        if isinstance(value, bool) or isinstance(value, (int, float, str)):
            continue
        if isinstance(value, list):
            for item in value:
                if is_bytes(item) or is_credential_shaped(item):
                    fail()
                if not isinstance(item, (bool, int, float, str)):
                    fail()
            continue
        fail()


try:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    fd = os.open(source, flags)
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode):
            fail()
        chunks = []
        while True:
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        raw = b"".join(chunks)
    finally:
        os.close(fd)
    data = json.loads(raw.decode("utf-8"))
except Exception:
    fail()
if pref_id == "claude-preferences":
    validate_claude(data)
elif pref_id == "omp-preferences":
    validate_omp(data)
else:
    fail()
sys.exit(0)
PY
}

report() {
  printf '%s %s\n' "$1" "$2"
  [ "$1" = OK ] || [ "$1" = MANUAL_REVIEW ] || CHECK_FAILED=1
}

CHECK_FAILED=0
ROW_COUNT=0
while IFS=$'\034' read -r id source destination mode profiles; do
  [ "$id" = id ] && continue
  ROW_COUNT=$((ROW_COUNT + 1))
  if ! ws_safe_tsv_field "$id" || ! ws_safe_tsv_field "$destination" || ! ws_safe_tsv_field "$mode" || ! ws_safe_tsv_field "$profiles" || { [ -n "$source" ] && ! ws_safe_tsv_field "$source"; }; then
    report UNSAFE configuration-catalog
    continue
  fi
  if ! ws_safe_token "$id" || ! valid_profile_tokens "$profiles"; then
    report UNSAFE configuration-catalog
    continue
  fi
  ws_profile_matches "$profiles" "$PROFILE" "$OS" || continue
  if ! destination_preflight "$destination"; then
    report UNSAFE "$id"
    continue
  fi
  case $mode in
    symlink)
      if ! source_preflight "$source"; then
        report UNSAFE "$id"
        continue
      fi
      if [ ! -e "$DESTINATION_PATH" ] && [ ! -L "$DESTINATION_PATH" ]; then
        report DRIFT "$id"
      elif [ -L "$DESTINATION_PATH" ]; then
        target=$(realpath_any "$DESTINATION_PATH")
        if [ "$target" = "$SOURCE_CANONICAL" ]; then
          report OK "$id"
        else
          report DRIFT "$id"
        fi
      else
        report DRIFT "$id"
      fi
      ;;
    manual-review)
      if ! source_preflight "$source" || ! git_config_is_safe "$SOURCE_CANONICAL"; then
        report UNSAFE "$id"
      else
        report MANUAL_REVIEW "$id"
      fi
      ;;
    local)
      if [ -L "$DESTINATION_PATH" ] || [ -d "$DESTINATION_PATH" ]; then
        report UNSAFE "$id"
      elif [ ! -e "$DESTINATION_PATH" ]; then
        report MISSING "$id"
      elif [ ! -f "$DESTINATION_PATH" ]; then
        report UNSAFE "$id"
      else
        canonical=$(realpath_any "$DESTINATION_PATH")
        if path_is_within "$canonical" "$UTILS_CANONICAL"; then
          report UNSAFE "$id"
        else
          report OK "$id"
        fi
      fi
      ;;
    json-merge|omp-merge)
      if ! source_preflight "$source"; then
        report UNSAFE "$id"
        continue
      fi
      if ! agent_preference_is_safe "$id" "$SOURCE_CANONICAL"; then
        report UNSAFE "$id"
        continue
      fi
      # An absent destination is managed state — the tool may not be
      # installed yet. This is not a failure; report OK so check does
      # not fail on a fresh machine before bootstrap --apply.
      if [ ! -e "$DESTINATION_PATH" ] && [ ! -L "$DESTINATION_PATH" ]; then
        report OK "$id"
      elif [ -L "$DESTINATION_PATH" ]; then
        report UNSAFE "$id"
      elif [ ! -f "$DESTINATION_PATH" ]; then
        report UNSAFE "$id"
      else
        report OK "$id"
      fi
      ;;
    *)
      report UNSAFE "$id"
      ;;
  esac
done < <(tr '\t' '\034' <"$CONFIG_SOURCES")
KICKSTART_ROOT="$HOME_CANONICAL/.config/nvim"
if ! source_preflight 'nvim-custom/kickstart.patch'; then
  report UNSAFE kickstart
elif [ ! -d "$KICKSTART_ROOT/.git" ] || [ ! -f "$KICKSTART_ROOT/init.lua" ]; then
  report MISSING kickstart
elif ! ws_command_exists git; then
  report UNSAFE kickstart
elif git -C "$KICKSTART_ROOT" apply --reverse --check "$SOURCE_CANONICAL" >/dev/null 2>&1; then
  report OK kickstart
else
  report DRIFT kickstart
fi

[ "$ROW_COUNT" -gt 0 ] || { ws_die 'check metadata is empty'; exit 1; }
if [ "$CHECK_FAILED" -ne 0 ]; then
  printf 'CHECK FAILED\n' >&2
  exit 1
fi
printf 'CHECK PASS\n'

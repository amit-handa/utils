#!/usr/bin/env bash
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PACKAGE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)
CHECK="$PACKAGE_DIR/scripts/check.sh"
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/check-test.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT HUP INT TERM
HOME_DIR="$FIXTURE/home"
UTILS_DIR="$FIXTURE/utils"
OUTSIDE_DIR="$FIXTURE/outside"
BIN_DIR="$FIXTURE/bin"
mkdir -p "$HOME_DIR/.config/ghostty" "$HOME_DIR/.config/nvim/.git" \
  "$HOME_DIR/.config/nvim/lua" "$HOME_DIR/.config/gh" "$HOME_DIR/.local/bin" \
  "$HOME_DIR/Library/Application Support/com.mitchellh.ghostty" \
  "$HOME_DIR/Library/Application Support/Code/User" \
  "$HOME_DIR/Library/Application Support/Cursor/User" \
  "$UTILS_DIR/nvim-custom/lua/custom/plugins" "$UTILS_DIR/.config/gh" \
  "$UTILS_DIR/.local/bin" "$UTILS_DIR/.hammerspoon" "$UTILS_DIR/ide/vscode" \
  "$UTILS_DIR/ide/cursor" "$OUTSIDE_DIR" "$BIN_DIR" \
  "$UTILS_DIR/ai/claude" "$UTILS_DIR/ai/omp"

printf '%s\n' '# safe zshrc' >"$UTILS_DIR/.zshrc"
printf '%s\n' '# safe work zshrc' >"$UTILS_DIR/.zshrc.work"
printf '%s\n' '# safe herdr title watcher' >"$UTILS_DIR/.local/bin/herdr-title-watch"
chmod +x "$UTILS_DIR/.local/bin/herdr-title-watch"
printf '%s\n' '# safe bashrc' >"$UTILS_DIR/.bashrc"
printf '%s\n' '# safe tmux' >"$UTILS_DIR/.tmux.conf"
printf '%s\n' '# safe ghostty' >"$UTILS_DIR/ghostty.config"
printf '%s\n' '{"editor.minimap.enabled": false}' >"$UTILS_DIR/ide/vscode/settings.json"
printf '%s\n' '{"workbench.colorTheme": "Cursor Dark"}' >"$UTILS_DIR/ide/cursor/settings.json"
printf '%s\n' '[]' >"$UTILS_DIR/ide/cursor/keybindings.json"
printf '%s\n' '-- nvim custom' >"$UTILS_DIR/nvim-custom/lua/custom/plugins/init.lua"
printf '%s\n' '# safe vimrc' >"$UTILS_DIR/.vimrc"
printf '%s\n' '[core]' '    editor = nvim' >"$UTILS_DIR/.config/gh/config.yml"
cat >"$UTILS_DIR/nvim-custom/kickstart.patch" <<'PATCH'
diff --git a/init.lua b/init.lua
--- a/init.lua
+++ b/init.lua
@@ -1 +1 @@
--- require 'custom.plugins'
+require 'custom.plugins'
PATCH
printf '%s\n' '# safe aliases' >"$UTILS_DIR/.kubectlAliases"
printf '%s\n' '-- safe hammerspoon' >"$UTILS_DIR/.hammerspoon/init.lua"
cat >"$UTILS_DIR/.gitconfig" <<'GITCONFIG'
[include]
    path = ~/.gitconfig.local
GITCONFIG
cat >"$UTILS_DIR/ai/claude/settings.json" <<'JSON'
{
  "model": "opusplan",
  "autoCompactEnabled": false,
  "autoCompactWindow": 100000,
  "tui": "fullscreen",
  "voice": {"enabled": true, "mode": "hold"},
  "voiceEnabled": true
}
JSON
cat >"$UTILS_DIR/ai/omp/preferences.json" <<'JSON'
{
  "defaultThinkingLevel": "auto",
  "theme.dark": "titanium",
  "theme.light": "light",
  "symbolPreset": "nerd",
  "colorBlindMode": false,
  "statusLine.preset": "nerd",
  "statusLine.separator": "powerline-thin",
  "statusLine.sessionAccent": true,
  "statusLine.compactThinkingLevel": false,
  "terminal.showProgress": false,
  "tui.renderMermaid": true,
  "tui.titleState": true,
  "display.smoothStreaming": true,
  "display.showTokenUsage": false
}
JSON
git -C "$HOME_DIR/.config/nvim" init -q
printf '%s\n' "-- require 'custom.plugins'" >"$HOME_DIR/.config/nvim/init.lua"
git -C "$HOME_DIR/.config/nvim" apply "$UTILS_DIR/nvim-custom/kickstart.patch"

link_all_macos() {
  ln -s "$UTILS_DIR/.zshrc" "$HOME_DIR/.zshrc"
  ln -s "$UTILS_DIR/.zshrc.work" "$HOME_DIR/.zshrc.work"
  ln -s "$UTILS_DIR/.bashrc" "$HOME_DIR/.bashrc"
  ln -s "$UTILS_DIR/.tmux.conf" "$HOME_DIR/.tmux.conf"
  ln -s "$UTILS_DIR/ghostty.config" "$HOME_DIR/.config/ghostty/config"
  ln -s "$UTILS_DIR/ghostty.config" "$HOME_DIR/Library/Application Support/com.mitchellh.ghostty/config"
  ln -s "$UTILS_DIR/nvim-custom/lua/custom" "$HOME_DIR/.config/nvim/lua/custom"
  ln -s "$UTILS_DIR/.kubectlAliases" "$HOME_DIR/.kubectlAliases"
  ln -s "$UTILS_DIR/.local/bin/herdr-title-watch" "$HOME_DIR/.local/bin/herdr-title-watch"
  ln -s "$UTILS_DIR/.vimrc" "$HOME_DIR/.vimrc"
  ln -s "$UTILS_DIR/.config/gh/config.yml" "$HOME_DIR/.config/gh/config.yml"
  ln -s "$UTILS_DIR/.hammerspoon" "$HOME_DIR/.hammerspoon"
  ln -s "$UTILS_DIR/ide/vscode/settings.json" "$HOME_DIR/Library/Application Support/Code/User/settings.json"
  ln -s "$UTILS_DIR/ide/cursor/settings.json" "$HOME_DIR/Library/Application Support/Cursor/User/settings.json"
  ln -s "$UTILS_DIR/ide/cursor/keybindings.json" "$HOME_DIR/Library/Application Support/Cursor/User/keybindings.json"
  : >"$HOME_DIR/.gitconfig.local"
  chmod 600 "$HOME_DIR/.gitconfig.local"
}
link_all_macos
printf '%s\n' 'secret-placeholder-value' >"$HOME_DIR/sentinel"

assert_contains() {
  case $1 in *"$2"*) ;; *) printf 'missing expected text: %s\n' "$2" >&2; exit 1 ;; esac
}
assert_not_contains() {
  case $1 in *"$2"*) printf 'found unexpected text: %s\n' "$2" >&2; exit 1 ;; *) ;; esac
}

SAFE_OUTPUT=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$CHECK" --os macos --profile work --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$SAFE_OUTPUT" 'OK zshrc'
assert_contains "$SAFE_OUTPUT" 'OK zshrc-work'
assert_contains "$SAFE_OUTPUT" 'OK kickstart'
assert_contains "$SAFE_OUTPUT" 'OK herdr-title-watch'
assert_contains "$SAFE_OUTPUT" 'OK nvim-custom'
assert_contains "$SAFE_OUTPUT" 'OK vimrc'
assert_contains "$SAFE_OUTPUT" 'OK gh-config'
assert_contains "$SAFE_OUTPUT" 'OK vscode-settings-macos'
assert_contains "$SAFE_OUTPUT" 'OK cursor-settings-macos'
assert_contains "$SAFE_OUTPUT" 'OK cursor-keybindings-macos'
assert_contains "$SAFE_OUTPUT" 'OK gitconfig-local'
assert_contains "$SAFE_OUTPUT" 'MANUAL_REVIEW gitconfig'
assert_contains "$SAFE_OUTPUT" 'OK claude-preferences'
assert_contains "$SAFE_OUTPUT" 'OK omp-preferences'
assert_not_contains "$SAFE_OUTPUT" 'secret-placeholder-value'
[ -f "$HOME_DIR/sentinel" ] || exit 1

rm "$HOME_DIR/.zshrc"
ln -s "$OUTSIDE_DIR/missing" "$HOME_DIR/.zshrc"
if DRIFT_OUTPUT=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$CHECK" --os macos --profile work --utils-path "$UTILS_DIR" 2>&1); then
  printf 'wrong symlink unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$DRIFT_OUTPUT" 'DRIFT zshrc'
rm "$HOME_DIR/.zshrc"
ln -s "$UTILS_DIR/.zshrc" "$HOME_DIR/.zshrc"

rm "$HOME_DIR/.gitconfig.local"
if MISSING_OUTPUT=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$CHECK" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1); then
  printf 'missing local state unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$MISSING_OUTPUT" 'MISSING gitconfig-local'
ln -s "$UTILS_DIR/.zshrc" "$HOME_DIR/.gitconfig.local"
if LOCAL_OUTPUT=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$CHECK" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1); then
  printf 'unsafe local state unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$LOCAL_OUTPUT" 'UNSAFE gitconfig-local'
rm "$HOME_DIR/.gitconfig.local"
: >"$HOME_DIR/.gitconfig.local"
chmod 600 "$HOME_DIR/.gitconfig.local"

printf '%s\n' '[credential]' 'username = placeholder' >"$UTILS_DIR/.gitconfig"
if GIT_OUTPUT=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$CHECK" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1); then
  printf 'credential section unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$GIT_OUTPUT" 'UNSAFE gitconfig'
assert_not_contains "$GIT_OUTPUT" 'placeholder'
cat >"$UTILS_DIR/.gitconfig" <<'GITCONFIG'
[include]
    path = ~/.gitconfig.local
GITCONFIG

mv "$UTILS_DIR/.zshrc" "$UTILS_DIR/.zshrc.real"
ln -s "$OUTSIDE_DIR" "$UTILS_DIR/.zshrc"
if SOURCE_OUTPUT=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$CHECK" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1); then
  printf 'source escape unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$SOURCE_OUTPUT" 'UNSAFE zshrc'
rm "$UTILS_DIR/.zshrc"
mv "$UTILS_DIR/.zshrc.real" "$UTILS_DIR/.zshrc"

rm -rf "$HOME_DIR/.config"
mkdir -p "$OUTSIDE_DIR/config"
ln -s "$OUTSIDE_DIR/config" "$HOME_DIR/.config"
if PARENT_OUTPUT=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$CHECK" --os linux --profile base --utils-path "$UTILS_DIR" 2>&1); then
  printf 'destination parent escape unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$PARENT_OUTPUT" 'UNSAFE'
assert_not_contains "$PARENT_OUTPUT" 'secret-placeholder-value'

if HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$CHECK" --os macos --profile base --unknown >/dev/null 2>"$FIXTURE/args.err"; then
  exit 1
fi
assert_not_contains "$(cat "$FIXTURE/args.err")" '--unknown'

# Real-source privacy check: the curated utils ai/ files must parse as JSON,
# carry only the approved allowlisted keys, and contain no credential/path/
# runtime-shaped content. When WORKSTATION_UTILS_PATH is set, the real
# committed templates are copied from that directory; otherwise equivalent
# sanitized templates are created inside the fixture. Never reads live user
# config files.
REAL_AI_DIR="$FIXTURE/real-ai-check"
mkdir -p "$REAL_AI_DIR/ai/claude" "$REAL_AI_DIR/ai/omp"
if [ -n "${WORKSTATION_UTILS_PATH:-}" ]; then
  if [ ! -f "$WORKSTATION_UTILS_PATH/ai/claude/settings.json" ] || \
     [ ! -f "$WORKSTATION_UTILS_PATH/ai/omp/preferences.json" ]; then
    printf 'WORKSTATION_UTILS_PATH is missing curated AI templates\n' >&2
    exit 1
  fi
  cp "$WORKSTATION_UTILS_PATH/ai/claude/settings.json" "$REAL_AI_DIR/ai/claude/settings.json"
  cp "$WORKSTATION_UTILS_PATH/ai/omp/preferences.json" "$REAL_AI_DIR/ai/omp/preferences.json"
else
  cat >"$REAL_AI_DIR/ai/claude/settings.json" <<'JSON'
{
  "model": "opusplan",
  "autoCompactEnabled": false,
  "autoCompactWindow": 100000,
  "tui": "fullscreen",
  "voice": {"enabled": true, "mode": "hold"},
  "voiceEnabled": true
}
JSON
  cat >"$REAL_AI_DIR/ai/omp/preferences.json" <<'JSON'
{
  "defaultThinkingLevel": "auto",
  "theme.dark": "titanium",
  "theme.light": "light",
  "symbolPreset": "nerd",
  "colorBlindMode": false,
  "statusLine.preset": "nerd",
  "statusLine.separator": "powerline-thin",
  "statusLine.sessionAccent": true,
  "statusLine.compactThinkingLevel": false,
  "terminal.showProgress": false,
  "tui.renderMermaid": true,
  "tui.titleState": true,
  "display.smoothStreaming": true,
  "display.showTokenUsage": false
}
JSON
fi
python3 - "$REAL_AI_DIR/ai/claude/settings.json" "$REAL_AI_DIR/ai/omp/preferences.json" <<'PY' || exit 1
import json, sys

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

def is_path_like(v):
    return isinstance(v, str) and (v.startswith("/") or v.startswith("~"))

def is_shell_command(v):
    return isinstance(v, str) and any(ch in v for ch in (";", "|", "`", "$", "&&", "(", ")"))

def is_credential_shaped(v):
    if isinstance(v, bytes):
        return True
    if isinstance(v, str):
        low = v.lower()
        if any(w in low for w in ("secret", "password", "token", "apikey",
                                   "api_key", "credential", "private_key",
                                   "bearer", "authorization")):
            return True
        if is_path_like(v) or is_shell_command(v):
            return True
    if isinstance(v, dict):
        return any(is_credential_shaped(x) for x in v.values())
    if isinstance(v, list):
        return any(is_credential_shaped(x) for x in v)
    return False

with open(sys.argv[1]) as f:
    claude = json.load(f)
assert isinstance(claude, dict), "claude root not dict"
assert set(claude.keys()) == CLAUDE_KEYS, f"claude keys {set(claude.keys())} != {CLAUDE_KEYS}"
for k, v in claude.items():
    assert not is_credential_shaped(v), f"claude credential/path/runtime at {k}"
assert isinstance(claude["model"], str)
assert isinstance(claude["tui"], str)
assert isinstance(claude["autoCompactEnabled"], bool)
assert isinstance(claude["voiceEnabled"], bool)
assert isinstance(claude["autoCompactWindow"], int) and not isinstance(claude["autoCompactWindow"], bool) and claude["autoCompactWindow"] > 0
assert isinstance(claude["voice"], dict)
assert set(claude["voice"].keys()) <= {"enabled", "mode"}
assert isinstance(claude["voice"]["enabled"], bool)
assert isinstance(claude["voice"]["mode"], str)

with open(sys.argv[2]) as f:
    omp = json.load(f)
assert isinstance(omp, dict), "omp root not dict"
assert set(omp.keys()) == OMP_KEYS, f"omp keys {set(omp.keys())} != {OMP_KEYS}"
for k, v in omp.items():
    assert not is_credential_shaped(v), f"omp credential/path/runtime at {k}"
    if isinstance(v, bool) or isinstance(v, (int, float, str)):
        continue
    if isinstance(v, list):
        for item in v:
            assert not is_credential_shaped(item), f"omp list credential/path/runtime at {k}"
            assert isinstance(item, (bool, int, float, str)), f"omp list item bad type at {k}"
        continue
    raise AssertionError(f"omp value bad type at {k}: {type(v)}")
PY
printf 'agent preference privacy check: PASS\n'
if [ "${EXPECT_MISSING_AI_SOURCE_FAILURE:-0}" != 1 ]; then
  INCOMPLETE_REAL="$FIXTURE/incomplete-real"
  mkdir -p "$INCOMPLETE_REAL/ai/claude"
  if EXPECT_MISSING_AI_SOURCE_FAILURE=1 \
     WORKSTATION_UTILS_PATH="$INCOMPLETE_REAL" \
     bash "$SCRIPT_DIR/test_check.sh" >"$FIXTURE/missing-ai-output" 2>&1; then
    printf 'incomplete WORKSTATION_UTILS_PATH unexpectedly passed\n' >&2
    cat "$FIXTURE/missing-ai-output" >&2
    exit 1
  fi
  assert_contains "$(cat "$FIXTURE/missing-ai-output")" \
    'WORKSTATION_UTILS_PATH is missing curated AI templates'
fi


printf 'check fixture tests: PASS\n'

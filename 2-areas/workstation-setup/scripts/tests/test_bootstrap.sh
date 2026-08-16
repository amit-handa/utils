#!/usr/bin/env bash
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PACKAGE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)
BOOTSTRAP="$PACKAGE_DIR/scripts/bootstrap.sh"
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-test.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT HUP INT TERM

HOME_DIR="$FIXTURE/home"
UTILS_DIR="$FIXTURE/utils"
OUTSIDE_DIR="$FIXTURE/outside"
BIN_DIR="$FIXTURE/bin"
REAL_GIT=$(command -v git)
mkdir -p "$HOME_DIR/.config/nvim/.git" "$HOME_DIR/.config/nvim/lua/custom" \
  "$HOME_DIR" "$HOME_DIR/Library/Application Support/Code/User" \
  "$HOME_DIR/Library/Application Support/Cursor/User" \
  "$HOME_DIR/Library/Application Support/JetBrains/IntelliJIdea2026.2/options" \
  "$HOME_DIR/Library/Preferences" \
  "$UTILS_DIR/nvim-custom/lua/custom/plugins" \
  "$UTILS_DIR/.config/gh" "$UTILS_DIR/.hammerspoon" "$UTILS_DIR/.config" \
  "$UTILS_DIR/.local/bin" "$UTILS_DIR/ide/vscode" "$UTILS_DIR/ide/cursor" \
  "$UTILS_DIR/ide/intellij/options" "$OUTSIDE_DIR" "$BIN_DIR" \
  "$UTILS_DIR/macos/menu-bar/alt-tab" "$UTILS_DIR/macos/menu-bar/maccy" \
  "$UTILS_DIR/ai/claude" "$UTILS_DIR/ai/omp" \
  "$UTILS_DIR/4-archives" \
  "$HOME_DIR/.claude" "$HOME_DIR/.omp/agent"
printf '%s\n' "-- require 'custom.plugins'" >"$HOME_DIR/.config/nvim/init.lua"
"$REAL_GIT" -C "$HOME_DIR/.config/nvim" init -q

printf '%s\n' '# safe zshrc' >"$UTILS_DIR/.zshrc"
printf '%s\n' '# safe work zshrc' >"$UTILS_DIR/.zshrc.work"
printf '%s\n' '# safe herdr title watcher' >"$UTILS_DIR/.local/bin/herdr-title-watch"
chmod +x "$UTILS_DIR/.local/bin/herdr-title-watch"
printf '%s\n' '# safe bashrc' >"$UTILS_DIR/.bashrc"
echo '# safe bashrc legacy' >"$UTILS_DIR/4-archives/.bashrc0"
echo '# safe bashrc mac legacy' >"$UTILS_DIR/4-archives/.bashrc0.mac"
printf '%s\n' '# safe tmux' >"$UTILS_DIR/.tmux.conf"
printf '%s\n' '# safe ghostty' >"$UTILS_DIR/ghostty.config"
printf '%s\n' '{"editor.minimap.enabled": false}' >"$UTILS_DIR/ide/vscode/settings.json"
printf '%s\n' '{"workbench.colorTheme": "Cursor Dark"}' >"$UTILS_DIR/ide/cursor/settings.json"
printf '%s\n' '<application><component name="EditorSettings"/></application>' >"$UTILS_DIR/ide/intellij/options/editor.xml"
printf '%s\n' '<application><component name="UISettings"/></application>' >"$UTILS_DIR/ide/intellij/options/ui.lnf.xml"
printf '%s\n' '<application><component name="TerminalOptionsProvider"/></application>' >"$UTILS_DIR/ide/intellij/options/terminal.xml"
printf '%s\n' 'existing editor option' >"$HOME_DIR/Library/Application Support/JetBrains/IntelliJIdea2026.2/options/editor.xml"
printf '%s\n' '[]' >"$UTILS_DIR/ide/cursor/keybindings.json"
printf '%s\n' 'anthropic.claude-code' >"$UTILS_DIR/ide/vscode/extensions.txt"
printf '%s\n' 'anthropic.claude-code' >"$UTILS_DIR/ide/cursor/extensions.txt"
printf '%s\n' 'return {}' >"$UTILS_DIR/nvim-custom/lua/custom/lsp.lua"
printf '%s\n' 'require("custom.plugins")' >"$UTILS_DIR/nvim-custom/lua/custom/plugins/init.lua"
cat >"$UTILS_DIR/nvim-custom/kickstart.patch" <<'PATCH'
diff --git a/init.lua b/init.lua
--- a/init.lua
+++ b/init.lua
@@ -1 +1 @@
--- require 'custom.plugins'
+require 'custom.plugins'
PATCH
cat >"$UTILS_DIR/.gitconfig" <<'GITCONFIG'
[include]
    path = ~/.gitconfig.local
GITCONFIG
printf '%s\n' '# safe aliases' >"$UTILS_DIR/.kubectlAliases"
printf '%s\n' '# safe vimrc' >"$UTILS_DIR/.vimrc"
printf '%s\n' '[core]' '    editor = nvim' >"$UTILS_DIR/.config/gh/config.yml"
printf '%s\n' '-- safe hammerspoon' >"$UTILS_DIR/.hammerspoon/init.lua"
cat >"$UTILS_DIR/macos/menu-bar/alt-tab/preferences.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0//EN">
<plist version="1.0"><dict>
  <key>appearanceSize</key><integer>1</integer>
  <key>nextWindowGesture</key><integer>4</integer>
  <key>previewFocusedWindow</key><false/>
  <key>showFullscreenWindows</key><string>1</string>
  <key>showHiddenWindows</key><string>1</string>
  <key>showMinimizedWindows</key><string>1</string>
  <key>spacesToShow</key><string>1</string>
  <key>windowOrder10</key><string>0</string>
</dict></plist>
PLIST

cat >"$UTILS_DIR/macos/menu-bar/maccy/preferences.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0//EN">
<plist version="1.0"><dict>
  <key>enabledPasteboardTypes</key><array><string>public.utf8-plain-text</string></array>
  <key>pasteByDefault</key><true/>
  <key>previewWidth</key><integer>400</integer>
  <key>removeFormattingByDefault</key><true/>
  <key>showFooter</key><true/>
  <key>showSearch</key><true/>
  <key>showTitle</key><true/>
</dict></plist>
PLIST

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

printf '%s\n' 'existing local zshrc' >"$HOME_DIR/.zshrc"
printf '%s\n' 'unchanged source' >"$UTILS_DIR/source-sentinel"

cat >"$HOME_DIR/.claude/settings.json" <<'JSON'
{
  "model": "local-model",
  "customLocalKey": "preserve-me",
  "permissions": {"defaultMode": "ask"}
}
JSON
printf '%s\n' 'customLocal: preserve-me' >"$HOME_DIR/.omp/agent/config.yml"

cat >"$BIN_DIR/brew" <<'SH'
#!/bin/sh
printf 'brew %s\n' "$*" >>"$BOOTSTRAP_LOG"
if [ "${1:-}" = bundle ]; then
    file=''
    for arg in "$@"; do
        case $arg in --file=*) file=${arg#--file=} ;; esac
    done
    [ -n "$file" ] && cp "$file" "$BREWFILE_USED"
fi
SH
cat >"$BIN_DIR/sudo" <<'SH'
#!/bin/sh
printf 'sudo %s\n' "$*" >>"$PACKAGE_LOG"
exec "$@"
SH
cat >"$BIN_DIR/apt-get" <<'SH'
#!/bin/sh
printf 'apt-get %s\n' "$*" >>"$PACKAGE_LOG"
exit 0
SH
cat >"$BIN_DIR/git" <<'SH'
#!/bin/sh
if [ "${1:-}" = clone ] && [ "$#" -eq 3 ]; then
    url=$2
    destination=$3
    printf 'git clone %s %s\n' "$url" "$destination" >>"$CLONE_LOG"
    case $url in
      *kickstart.nvim*)
        mkdir -p "$destination/lua/custom/plugins"
        "$REAL_GIT" -C "$destination" init -q
        printf '%s\n' "-- require 'custom.plugins'" >"$destination/init.lua"
        printf '%s\n' '-- stock custom placeholder' >"$destination/lua/custom/plugins/init.lua"
        ;;
      *ohmyzsh*)
        mkdir -p "$destination/custom/plugins"
        printf '%s\n' '# oh-my-zsh' >"$destination/oh-my-zsh.sh"
        ;;
      *zsh-autosuggestions*)
        mkdir -p "$destination"
        printf '%s\n' '# autosuggestions' >"$destination/plugin.zsh"
        ;;
      *zsh-completions*)
        mkdir -p "$destination"
        printf '%s\n' '# completions' >"$destination/init.zsh"
        ;;
      *Vundle.vim*)
        mkdir -p "$destination"
        printf '%s\n' '# vundle' >"$destination/plugin.vim"
        ;;
      *) exit 1 ;;
    esac
    exit 0
fi
exec "$REAL_GIT" "$@"
SH
cat >"$BIN_DIR/vim" <<'SH'
#!/bin/sh
printf 'vim %s\n' "$*" >>"$VIM_LOG"
exit 0
SH
for editor in code cursor; do
  cat >"$BIN_DIR/$editor" <<'SH'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >>"$IDE_EXTENSION_LOG"
exit 0
SH
done
cat >"$BIN_DIR/defaults" <<'SH'
#!/bin/sh
cmd=${1:-}
domain=${2:-}
arg=${3:-}
alttab_store="$HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist"
maccy_store="$HOME/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist"
case "$cmd" in
  read|export|import|domains) ;;
  *)
    printf 'unsupported defaults command: %s\n' "$cmd" >&2
    exit 1
    ;;
esac
case "$cmd" in
  domains)
    if [ $# -ne 1 ]; then
      printf 'defaults domains requires exactly 1 argument, got %d\n' "$#" >&2
      exit 1
    fi
    if [ "${DEFAULTS_DOMAINS_FAIL:-0}" = 1 ]; then
      printf 'defaults domains: synthetic failure\n' >>"$DEFAULTS_LOG"
      printf 'defaults domains failed\n' >&2
      exit 1
    fi
    printf 'defaults domains\n' >>"$DEFAULTS_LOG"
    domains=''
    [ -f "$alttab_store" ] && domains="$domains,com.lwouis.alt-tab-macos"
    [ -f "$maccy_store" ] && domains="$domains,org.p0deje.Maccy"
    domains=${domains#,}
    printf '%s\n' "$domains"
    exit 0
    ;;
esac
case "$domain" in
  com.lwouis.alt-tab-macos|org.p0deje.Maccy) ;;
  *)
    printf 'unsupported defaults domain: %s\n' "$domain" >&2
    exit 1
    ;;
esac
case "$domain" in
  com.lwouis.alt-tab-macos)
    store="$alttab_store" ;;
  org.p0deje.Maccy)
    store="$maccy_store" ;;
esac
case "$cmd" in
  read)
    if [ $# -ne 2 ]; then
      printf 'defaults read requires exactly 2 arguments, got %d\n' "$#" >&2
      exit 1
    fi
    printf 'defaults read %s\n' "$domain" >>"$DEFAULTS_LOG"
    [ -f "$store" ] || exit 1
    exit 0
    ;;
  export)
    if [ $# -ne 3 ]; then
      printf 'defaults export requires exactly 3 arguments, got %d\n' "$#" >&2
      exit 1
    fi
    printf 'defaults export %s %s\n' "$domain" "$arg" >>"$DEFAULTS_LOG"
    [ -f "$store" ] || { printf 'defaults export: no live store for %s\n' "$domain" >&2; exit 1; }
    mkdir -p "${arg%/*}"
    cp "$store" "$arg"
    exit 0
    ;;
  import)
    if [ $# -ne 3 ]; then
      printf 'defaults import requires exactly 3 arguments, got %d\n' "$#" >&2
      exit 1
    fi
    printf 'defaults import %s %s\n' "$domain" "$arg" >>"$DEFAULTS_LOG"
    [ -f "$arg" ] || { printf 'defaults import: missing source %s\n' "$arg" >&2; exit 1; }
    mkdir -p "${store%/*}"
    cp "$arg" "$store"
    exit 0
    ;;
esac
SH
cat >"$BIN_DIR/claude" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$BIN_DIR/omp" <<'SH'
#!/bin/sh
set -eu
root=${PI_CODING_AGENT_DIR:?PI_CODING_AGENT_DIR must be set for staged omp config}
live="$HOME/.omp/agent"
# The fake omp must never write the live destination; staging through
# PI_CODING_AGENT_DIR is the only safe path.
[ "$root" != "$live" ] || { printf 'omp refused to write live destination: %s\n' "$root" >&2; exit 1; }
if [ "${1:-}" = config ] && [ "${2:-}" = set ]; then
  [ "${OMP_CONFIG_SET_FAIL:-0}" != 1 ] || exit 1
  key=${3:?}
  value=${4:?}
  mkdir -p "$root"
  printf '%s=%s\n' "$key" "$value" >>"$root/config.yml"
  exit 0
fi
if [ "${1:-}" = config ] && [ "${2:-}" = list ] && [ "${3:-}" = "--json" ]; then
  [ -f "$root/config.yml" ] || { printf '{}\n'; exit 0; }
  python3 - "$root/config.yml" "${OMP_CONFIG_LIST_CORRUPT:-}" "${OMP_CONFIG_LIST_DESCRIPTOR:-}" "${OMP_CONFIG_LIST_WRONG_BOOL:-}" <<'PY'
import json, sys
result = {}
with open(sys.argv[1]) as f:
    for line in f:
        line = line.rstrip('\n')
        if not line or '=' not in line:
            continue
        k, v = line.split('=', 1)
        if v in ('true', 'false'):
            result[k] = (v == 'true')
        else:
            try:
                result[k] = int(v)
            except ValueError:
                try:
                    result[k] = float(v)
                except ValueError:
                    result[k] = v
if len(sys.argv) > 2 and sys.argv[2] == '1':
    result.pop(next(iter(result), ''), None)
if len(sys.argv) > 3 and sys.argv[3] == '1':
    result = {k: {"value": v, "type": "string"} for k, v in result.items()}
if len(sys.argv) > 4 and sys.argv[4] == '1':
    for k, v in result.items():
        if isinstance(v, bool):
            result[k] = "garbage"
            break
print(json.dumps(result))
PY
  exit 0
fi
exit 1
SH
chmod +x "$BIN_DIR/brew" "$BIN_DIR/sudo" "$BIN_DIR/apt-get" "$BIN_DIR/git" "$BIN_DIR/vim" "$BIN_DIR/code" "$BIN_DIR/cursor" "$BIN_DIR/defaults" "$BIN_DIR/claude" "$BIN_DIR/omp"
BOOTSTRAP_LOG="$FIXTURE/bootstrap.log"
PACKAGE_LOG="$FIXTURE/package.log"
BREWFILE_USED="$FIXTURE/brewfile-used"
CLONE_LOG="$FIXTURE/clone.log"
VIM_LOG="$FIXTURE/vim.log"
IDE_EXTENSION_LOG="$FIXTURE/ide-extensions.log"
DEFAULTS_LOG="$FIXTURE/defaults.log"
export BOOTSTRAP_LOG PACKAGE_LOG BREWFILE_USED CLONE_LOG VIM_LOG IDE_EXTENSION_LOG DEFAULTS_LOG REAL_GIT

assert_contains() {
    case $1 in *"$2"*) ;; *) printf 'missing expected text: %s\n' "$2" >&2; exit 1 ;; esac
}
assert_not_contains() {
    case $1 in *"$2"*) printf 'found unexpected text: %s\n' "$2" >&2; exit 1 ;; *) ;; esac
}
assert_file() { [ -f "$1" ] || { printf 'missing file: %s\n' "$1" >&2; exit 1; }; }
assert_link() {
    [ -L "$1" ] && [ "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1")" = "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$2")" ] || {
        printf 'wrong link: %s\n' "$1" >&2
        exit 1
    }
}

before_zsh=$(cat "$HOME_DIR/.zshrc")
before_source=$(cat "$UTILS_DIR/.zshrc")
before_claude=$(cat "$HOME_DIR/.claude/settings.json")
before_omp=$(cat "$HOME_DIR/.omp/agent/config.yml")
DRY_RUN=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" BOOTSTRAP_TIMESTAMP=20260101T000000Z \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$DRY_RUN" 'DRY_RUN'
assert_contains "$DRY_RUN" 'zshrc'
assert_contains "$DRY_RUN" 'PLAN PREREQ oh-my-zsh'
assert_contains "$DRY_RUN" 'PLAN PREREQ Vundle'
assert_contains "$DRY_RUN" 'PLAN MENU_BAR alt-tab'
assert_contains "$DRY_RUN" 'PLAN MENU_BAR maccy'
assert_contains "$DRY_RUN" 'PLAN AGENT_CONFIG claude-preferences'
assert_contains "$DRY_RUN" 'PLAN AGENT_CONFIG omp-preferences'
[ "$(cat "$HOME_DIR/.zshrc")" = "$before_zsh" ] || exit 1
[ "$(cat "$UTILS_DIR/.zshrc")" = "$before_source" ] || exit 1
[ "$(cat "$HOME_DIR/.claude/settings.json")" = "$before_claude" ] || exit 1
[ "$(cat "$HOME_DIR/.omp/agent/config.yml")" = "$before_omp" ] || exit 1
[ ! -e "$HOME_DIR/.gitconfig.local" ] || exit 1
[ ! -e "$HOME_DIR/.workstation-setup-backups" ] || exit 1
[ ! -e "$PACKAGE_LOG" ] || exit 1
[ ! -e "$BOOTSTRAP_LOG" ] || exit 1
[ ! -e "$CLONE_LOG" ] || exit 1

BASE_PACKAGES=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$BOOTSTRAP" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$BASE_PACKAGES" 'git'
assert_contains "$BASE_PACKAGES" 'cask "alt-tab"'
assert_contains "$BASE_PACKAGES" 'cask "maccy"'
assert_not_contains "$BASE_PACKAGES" 'android-studio'
WORK_PACKAGES=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$BOOTSTRAP" --os macos --profile work --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$WORK_PACKAGES" 'git'
assert_contains "$WORK_PACKAGES" 'kubectl'
MOBILE_PACKAGES=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$BOOTSTRAP" --os macos --profile mobile --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$MOBILE_PACKAGES" 'android-studio'
PERSONAL_DRY=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  WORKSTATION_PROFILE=personal \
  bash "$BOOTSTRAP" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$PERSONAL_DRY" 'PLAN LINK $HOME/.zshrc <- $UTILS/.zshrc'
assert_contains "$PERSONAL_DRY" 'PLAN LINK $HOME/Library/Application Support/Code/User/settings.json'
assert_not_contains "$PERSONAL_DRY" '$HOME/.kubectlAliases'

SERVER_DRY=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  WORKSTATION_PROFILE=server \
  bash "$BOOTSTRAP" --os linux --profile base --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$SERVER_DRY" 'PLAN LINK $HOME/.zshrc <- $UTILS/.zshrc'
assert_contains "$SERVER_DRY" 'PLAN LINK $HOME/.tmux.conf <- $UTILS/.tmux.conf'
assert_not_contains "$SERVER_DRY" '$HOME/.hammerspoon'
assert_not_contains "$SERVER_DRY" '$HOME/.claude/settings.json'
assert_not_contains "$SERVER_DRY" '$HOME/.kubectlAliases'

WORK_DRY=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  WORKSTATION_PROFILE=work \
  bash "$BOOTSTRAP" --os macos --profile work --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$WORK_DRY" '$HOME/.kubectlAliases'
assert_contains "$WORK_DRY" '$HOME/.config/gh/config.yml'
assert_contains "$WORK_DRY" '$HOME/.local/bin/herdr-title-watch'

if HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" WORKSTATION_PROFILE=unknown \
  bash "$BOOTSTRAP" --os linux --profile base --utils-path "$UTILS_DIR" \
  >"$FIXTURE/invalid-profile.out" 2>&1; then
  printf 'invalid WORKSTATION_PROFILE unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$(cat "$FIXTURE/invalid-profile.out")" 'invalid bootstrap arguments'

SERVER_MAC_DRY=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  WORKSTATION_PROFILE=server \
  bash "$BOOTSTRAP" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1)
assert_not_contains "$SERVER_MAC_DRY" '$HOME/.config/Code/User/settings.json'
assert_not_contains "$SERVER_MAC_DRY" '$HOME/Library/Application Support/Code/User/settings.json'
assert_not_contains "$SERVER_MAC_DRY" 'PLAN MENU_BAR'
assert_not_contains "$SERVER_MAC_DRY" 'PLAN IDE'
assert_not_contains "$SERVER_MAC_DRY" 'PLAN PREREQ code extensions'
assert_not_contains "$SERVER_MAC_DRY" 'PLAN PREREQ cursor extensions'

printf '%s\n' 'pre-existing alt-tab preference' \
  >"$HOME_DIR/Library/Preferences/com.lwouis.alt-tab-macos.plist"
mkdir -p "$HOME_DIR/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences"
printf '%s\n' 'pre-existing maccy preference' \
  >"$HOME_DIR/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist"

BOOTSTRAP_TIMESTAMP=20260101T000000Z HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile work --utils-path "$UTILS_DIR" --apply >"$FIXTURE/apply.out"
assert_link "$HOME_DIR/Library/Application Support/Code/User/settings.json" "$UTILS_DIR/ide/vscode/settings.json"
assert_link "$HOME_DIR/Library/Application Support/Cursor/User/settings.json" "$UTILS_DIR/ide/cursor/settings.json"
assert_link "$HOME_DIR/Library/Application Support/Cursor/User/keybindings.json" "$UTILS_DIR/ide/cursor/keybindings.json"
assert_file "$HOME_DIR/Library/Application Support/JetBrains/IntelliJIdea2026.2/options/editor.xml"
assert_file "$HOME_DIR/Library/Application Support/JetBrains/IntelliJIdea2026.2/options/ui.lnf.xml"
assert_file "$HOME_DIR/Library/Application Support/JetBrains/IntelliJIdea2026.2/options/terminal.xml"
[ "$(cat "$HOME_DIR/Library/Application Support/JetBrains/IntelliJIdea2026.2/options/editor.xml")" = "$(cat "$UTILS_DIR/ide/intellij/options/editor.xml")" ] || exit 1
assert_file "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/JetBrains/IntelliJIdea2026.2/options/editor.xml"
assert_contains "$(cat "$IDE_EXTENSION_LOG")" 'code --install-extension anthropic.claude-code'
assert_contains "$(cat "$IDE_EXTENSION_LOG")" 'cursor --install-extension anthropic.claude-code'
assert_link "$HOME_DIR/.vimrc" "$UTILS_DIR/.vimrc"
assert_link "$HOME_DIR/.config/gh/config.yml" "$UTILS_DIR/.config/gh/config.yml"
assert_file "$HOME_DIR/.oh-my-zsh/oh-my-zsh.sh"
assert_file "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-autosuggestions/plugin.zsh"
assert_file "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-completions/init.zsh"
assert_file "$HOME_DIR/.vim/bundle/Vundle.vim/plugin.vim"
assert_contains "$(cat "$VIM_LOG")" 'PluginInstall'
assert_link "$HOME_DIR/.zshrc.work" "$UTILS_DIR/.zshrc.work"
assert_link "$HOME_DIR/.local/bin/herdr-title-watch" "$UTILS_DIR/.local/bin/herdr-title-watch"
assert_link "$HOME_DIR/.zshrc" "$UTILS_DIR/.zshrc"
assert_link "$HOME_DIR/.bashrc" "$UTILS_DIR/.bashrc"
assert_link "$HOME_DIR/.bashrc0" "$UTILS_DIR/4-archives/.bashrc0.mac"
assert_link "$HOME_DIR/.tmux.conf" "$UTILS_DIR/.tmux.conf"
assert_link "$HOME_DIR/.config/nvim/lua/custom" "$UTILS_DIR/nvim-custom/lua/custom"
assert_contains "$(cat "$HOME_DIR/.config/nvim/init.lua")" "require 'custom.plugins'"
assert_not_contains "$(cat "$HOME_DIR/.config/nvim/init.lua")" "-- require 'custom.plugins'"
assert_link "$HOME_DIR/.kubectlAliases" "$UTILS_DIR/.kubectlAliases"
[ ! -e "$HOME_DIR/.gitconfig" ] || exit 1
assert_file "$HOME_DIR/.gitconfig.local"
mode=$(stat -c '%a' "$HOME_DIR/.gitconfig.local" 2>/dev/null || stat -f '%Lp' "$HOME_DIR/.gitconfig.local")
[ "$mode" = 600 ] || { printf 'local mode: %s\n' "$mode" >&2; exit 1; }
assert_file "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/.zshrc"
[ "$(cat "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/.zshrc")" = "$before_zsh" ] || exit 1
[ "$(cat "$UTILS_DIR/.zshrc")" = "$before_source" ] || exit 1
assert_contains "$(cat "$FIXTURE/apply.out")" 'MANUAL_REVIEW'
assert_file "$HOME_DIR/Library/Preferences/com.lwouis.alt-tab-macos.plist"
assert_file "$HOME_DIR/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist"
[ "$(cat "$HOME_DIR/Library/Preferences/com.lwouis.alt-tab-macos.plist")" = "$(cat "$UTILS_DIR/macos/menu-bar/alt-tab/preferences.plist")" ] || exit 1
[ "$(cat "$HOME_DIR/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist")" = "$(cat "$UTILS_DIR/macos/menu-bar/maccy/preferences.plist")" ] || exit 1
assert_contains "$(cat "$DEFAULTS_LOG")" 'import com.lwouis.alt-tab-macos'
assert_contains "$(cat "$DEFAULTS_LOG")" 'import org.p0deje.Maccy'
assert_file "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/Library/Preferences/com.lwouis.alt-tab-macos.plist"
[ "$(cat "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/Library/Preferences/com.lwouis.alt-tab-macos.plist")" = 'pre-existing alt-tab preference' ] || exit 1
assert_file "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist"
[ "$(cat "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist")" = 'pre-existing maccy preference' ] || exit 1
assert_contains "$(cat "$FIXTURE/apply.out")" 'AGENT_CONFIG RESTORED claude-preferences'
assert_contains "$(cat "$FIXTURE/apply.out")" 'AGENT_CONFIG RESTORED omp-preferences'
assert_file "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/.claude/settings.json"
[ "$(cat "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/.claude/settings.json")" = "$before_claude" ] || exit 1
assert_file "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/.omp/agent/config.yml"
[ "$(cat "$HOME_DIR/.workstation-setup-backups/20260101T000000Z/.omp/agent/config.yml")" = "$before_omp" ] || exit 1
# Programmatic check: every curated Claude source key matches the
# applied value (including voice sub-object nested keys), and every
# unknown local key is preserved -- independent of key ordering or
# whitespace formatting, so compact JSON is accepted.
python3 - "$UTILS_DIR/ai/claude/settings.json" "$HOME_DIR/.claude/settings.json" <<'PY' || exit 1
import json, sys
with open(sys.argv[1]) as f: src = json.load(f)
with open(sys.argv[2]) as f: dst = json.load(f)
for k, v in src.items():
    if k not in dst or dst[k] != v:
        sys.exit(f'claude curated key mismatch: {k}')
if dst.get('customLocalKey') != 'preserve-me':
    sys.exit('claude unknown key customLocalKey lost')
if dst.get('permissions', {}).get('defaultMode') != 'ask':
    sys.exit('claude unknown key permissions.defaultMode lost')
PY
# Every approved OMP dotted key must appear as exactly one complete
# key=value line whose value matches the curated source, with no
# conflicting or duplicate lines for that key, plus the preserved
# unknown local key.
python3 - "$UTILS_DIR/ai/omp/preferences.json" "$HOME_DIR/.omp/agent/config.yml" <<'PY' || exit 1
import json, sys
with open(sys.argv[1]) as f: src = json.load(f)
expected = {}
for k, v in src.items():
    if isinstance(v, bool):
        s = 'true' if v else 'false'
    else:
        s = str(v)
    expected[k] = s
if len(expected) != 14:
    sys.exit(f'OMP expected 14 curated keys, source has {len(expected)}')
with open(sys.argv[2]) as f:
    live = [ln.rstrip('\n') for ln in f]
for key, want in expected.items():
    matches = [ln for ln in live if ln.split('=', 1)[0] == key]
    if len(matches) != 1:
        sys.exit(f'OMP key {key} has {len(matches)} lines (expected 1): {matches}')
    if matches[0] != f'{key}={want}':
        sys.exit(f'OMP key {key} conflicting value: {matches[0]}')
if 'customLocal: preserve-me' not in live:
    sys.exit('OMP unknown key customLocal lost')
PY
# Staging invariant: the fake omp refuses to write the live destination
# (it fails if PI_CODING_AGENT_DIR equals $HOME/.omp/agent), so the live
# config could only have changed via the atomic move. The backup at
# .workstation-setup-backups/.../.omp/agent/config.yml still equals the
# pre-apply live state (asserted above), and the live config now carries
# the curated values (asserted above) -- together proving the live file
# was untouched until the atomic replacement.

[ -f "$BREWFILE_USED" ] || {
    BOOTSTRAP_TIMESTAMP=20260101T000000Z HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
        bash "$BOOTSTRAP" --os macos --profile base --utils-path "$UTILS_DIR" --apply >/dev/null
}
assert_file "$BREWFILE_USED"
assert_contains "$(cat "$BREWFILE_USED")" 'brew "git"'
CLONE_HOME="$FIXTURE/clone-home"
mkdir -p "$CLONE_HOME"
BOOTSTRAP_TIMESTAMP=20260102T000000Z HOME="$CLONE_HOME" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$UTILS_DIR" --apply >"$FIXTURE/clone.out"
assert_contains "$(cat "$CLONE_LOG")" 'git clone https://github.com/nvim-lua/kickstart.nvim.git'
assert_file "$CLONE_HOME/.config/nvim/.git/HEAD"
assert_contains "$(cat "$CLONE_HOME/.config/nvim/init.lua")" "require 'custom.plugins'"
assert_not_contains "$(cat "$CLONE_HOME/.config/nvim/init.lua")" "-- require 'custom.plugins'"
assert_link "$CLONE_HOME/.config/nvim/lua/custom" "$UTILS_DIR/nvim-custom/lua/custom"

LINUX_DRY=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" bash "$BOOTSTRAP" --os linux --profile base --utils-path "$UTILS_DIR" 2>&1)
for package in git tmux neovim vim curl python3 python3-pip nodejs npm golang-go openjdk-21-jdk; do
    assert_contains "$LINUX_DRY" "$package"
done
assert_not_contains "$LINUX_DRY" '# Packages available'
assert_not_contains "$LINUX_DRY" 'alt-tab'
assert_not_contains "$LINUX_DRY" 'maccy'
assert_not_contains "$LINUX_DRY" 'MENU_BAR'
assert_contains "$LINUX_DRY" 'PLAN LINK $HOME/.bashrc0 <- $UTILS/4-archives/.bashrc0'
assert_not_contains "$LINUX_DRY" '$UTILS/4-archives/.bashrc0.mac'

run_unsafe_git_case() {
    name=$1
    body=$2
    case_home="$FIXTURE/home-$name"
    case_utils="$FIXTURE/utils-$name"
    mkdir -p "$case_home/.config/nvim/.git" "$case_utils/nvim-custom/lua/custom/plugins" "$case_utils/.hammerspoon"
    printf '%s\n' "-- require 'custom.plugins'" >"$case_home/.config/nvim/init.lua"
    cp "$UTILS_DIR/.zshrc" "$case_utils/.zshrc"
    cp "$UTILS_DIR/.zshrc.work" "$case_utils/.zshrc.work"
    cp "$UTILS_DIR/.bashrc" "$case_utils/.bashrc"
    cp "$UTILS_DIR/.tmux.conf" "$case_utils/.tmux.conf"
    cp "$UTILS_DIR/ghostty.config" "$case_utils/ghostty.config"
    cp "$UTILS_DIR/nvim-custom/lua/custom/plugins/init.lua" "$case_utils/nvim-custom/lua/custom/plugins/init.lua"
    cp "$UTILS_DIR/nvim-custom/lua/custom/lsp.lua" "$case_utils/nvim-custom/lua/custom/lsp.lua"
    cp "$UTILS_DIR/.kubectlAliases" "$case_utils/.kubectlAliases"
    cp -R "$UTILS_DIR/.hammerspoon" "$case_utils/"
    printf '%s\n' "$body" >"$case_utils/.gitconfig"
    printf '%s\n' 'sentinel' >"$case_home/.zshrc"
    if HOME="$case_home" PATH="$BIN_DIR:$PATH" bash "$BOOTSTRAP" --os macos --profile work --utils-path "$case_utils" --apply >"$FIXTURE/$name.out" 2>&1; then
        printf 'unsafe case unexpectedly passed: %s\n' "$name" >&2
        exit 1
    fi
    assert_contains "$(cat "$FIXTURE/$name.out")" 'UNSAFE'
    [ "$(cat "$case_home/.zshrc")" = sentinel ] || exit 1
    [ ! -e "$case_home/.workstation-setup-backups" ] || exit 1
}
run_unsafe_git_case url-scoped '[credential "https://example.invalid"]
    helper = placeholder'
run_unsafe_git_case credential-section '[credential]
    username = placeholder'

LOCAL_HOME="$FIXTURE/local-home"
mkdir -p "$LOCAL_HOME"
ln -s "$UTILS_DIR/.zshrc" "$LOCAL_HOME/.gitconfig.local"
if HOME="$LOCAL_HOME" PATH="$BIN_DIR:$PATH" bash "$BOOTSTRAP" --os macos --profile base --utils-path "$UTILS_DIR" --apply >"$FIXTURE/local.out" 2>&1; then exit 1; fi
assert_contains "$(cat "$FIXTURE/local.out")" 'UNSAFE'

ESCAPE_UTILS="$FIXTURE/escape-utils"
mkdir -p "$ESCAPE_UTILS"
ln -s "$OUTSIDE_DIR" "$ESCAPE_UTILS/.zshrc"
if HOME="$FIXTURE/escape-home" PATH="$BIN_DIR:$PATH" bash "$BOOTSTRAP" --os macos --profile base --utils-path "$ESCAPE_UTILS" --apply >"$FIXTURE/escape.out" 2>&1; then exit 1; fi
assert_contains "$(cat "$FIXTURE/escape.out")" 'UNSAFE'

PARENT_HOME="$FIXTURE/parent-home"
mkdir -p "$PARENT_HOME" "$FIXTURE/parent-outside"
ln -s "$FIXTURE/parent-outside" "$PARENT_HOME/.config"
if HOME="$PARENT_HOME" PATH="$BIN_DIR:$PATH" bash "$BOOTSTRAP" --os linux --profile base --utils-path "$UTILS_DIR" --apply >"$FIXTURE/parent.out" 2>&1; then exit 1; fi
assert_contains "$(cat "$FIXTURE/parent.out")" 'UNSAFE'

MALFORMED_UTILS="$FIXTURE/malformed-utils"
MALFORMED_HOME="$FIXTURE/malformed-home"
mkdir -p "$MALFORMED_UTILS" "$MALFORMED_HOME/.config/nvim/.git"
printf '%s\n' "-- require 'custom.plugins'" >"$MALFORMED_HOME/.config/nvim/init.lua"
# Clone the complete valid utils fixture so the bootstrap clears preflight
# (config sources, kickstart patch, IDE settings, etc.) and reaches the
# malformed AltTab plist during menu-bar restore rather than failing early
# on an unrelated missing source.
cp -R "$UTILS_DIR/." "$MALFORMED_UTILS/"
printf '%s\n' 'not valid xml <<< broken' >"$MALFORMED_UTILS/macos/menu-bar/alt-tab/preferences.plist"
printf '%s\n' 'sentinel' >"$MALFORMED_HOME/.zshrc"
# Seed an existing AltTab destination so the malformed case also proves the
# restore aborts before mutating it.
mkdir -p "$MALFORMED_HOME/Library/Preferences"
printf '%s\n' 'malformed-case sentinel preference' \
  >"$MALFORMED_HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist"
if BOOTSTRAP_TIMESTAMP=20260101T000000Z HOME="$MALFORMED_HOME" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$MALFORMED_UTILS" --apply >"$FIXTURE/malformed.out" 2>&1; then
    printf 'malformed menu-bar source unexpectedly passed\n' >&2
    exit 1
fi
case "$(cat "$FIXTURE/malformed.out")" in
  *'invalid menu-bar plist'*|*'invalid plist'*) ;;
  *) printf 'malformed output missing invalid menu-bar plist or invalid plist diagnostic\n' >&2; exit 1 ;;
esac
[ ! -e "$MALFORMED_HOME/.workstation-setup-backups" ] || exit 1
assert_file "$MALFORMED_HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist"
[ "$(cat "$MALFORMED_HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist")" = 'malformed-case sentinel preference' ] || exit 1

# Allowlist regression: a syntactically valid plist that contains an
# unapproved key must fail closed. This proves syntax-valid unapproved
# keys are rejected by the allowlist parser, not just malformed XML.
BADKEY_UTILS="$FIXTURE/badkey-utils"
BADKEY_HOME="$FIXTURE/badkey-home"
mkdir -p "$BADKEY_UTILS" "$BADKEY_HOME/.config/nvim/.git"
printf '%s\n' "-- require 'custom.plugins'" >"$BADKEY_HOME/.config/nvim/init.lua"
cp -R "$UTILS_DIR/." "$BADKEY_UTILS/"
cat >"$BADKEY_UTILS/macos/menu-bar/alt-tab/preferences.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>appearanceSize</key><integer>1</integer>
  <key>secret</key><string>leak</string>
</dict></plist>
PLIST
printf '%s\n' 'sentinel' >"$BADKEY_HOME/.zshrc"
mkdir -p "$BADKEY_HOME/Library/Preferences"
printf '%s\n' 'badkey-case sentinel preference' \
  >"$BADKEY_HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist"
if BOOTSTRAP_TIMESTAMP=20260101T000000Z HOME="$BADKEY_HOME" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$BADKEY_UTILS" --apply >"$FIXTURE/badkey.out" 2>&1; then
    printf 'unapproved-key menu-bar source unexpectedly passed\n' >&2
    exit 1
fi
case "$(cat "$FIXTURE/badkey.out")" in
  *'invalid menu-bar plist'*) ;;
  *) printf 'badkey output missing invalid menu-bar plist diagnostic\n' >&2; exit 1 ;;
esac
[ ! -e "$BADKEY_HOME/.workstation-setup-backups" ] || exit 1
assert_file "$BADKEY_HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist"
[ "$(cat "$BADKEY_HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist")" = 'badkey-case sentinel preference' ] || exit 1

# AltTab exception-value privacy regression: JSON-encoded path-like values
# must fail closed even though the outer plist and exceptions JSON are valid.
BADEXCEPTION_UTILS="$FIXTURE/badexception-utils"
BADEXCEPTION_HOME="$FIXTURE/badexception-home"
mkdir -p "$BADEXCEPTION_UTILS" "$BADEXCEPTION_HOME/.config/nvim/.git"
printf '%s\n' "-- require 'custom.plugins'" >"$BADEXCEPTION_HOME/.config/nvim/init.lua"
cp -R "$UTILS_DIR/." "$BADEXCEPTION_UTILS/"
cat >"$BADEXCEPTION_UTILS/macos/menu-bar/alt-tab/preferences.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>appearanceSize</key><integer>1</integer>
  <key>exceptions</key>
  <string>[{"ignore":"/Users/private/path"}]</string>
</dict></plist>
PLIST
printf '%s\n' 'sentinel' >"$BADEXCEPTION_HOME/.zshrc"
mkdir -p "$BADEXCEPTION_HOME/Library/Preferences"
printf '%s\n' 'badexception-case sentinel preference' \
  >"$BADEXCEPTION_HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist"
if BOOTSTRAP_TIMESTAMP=20260101T000000Z HOME="$BADEXCEPTION_HOME" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$BADEXCEPTION_UTILS" --apply >"$FIXTURE/badexception.out" 2>&1; then
    printf 'unsafe exception value unexpectedly passed\n' >&2
    exit 1
fi
assert_contains "$(cat "$FIXTURE/badexception.out")" 'invalid menu-bar plist'
[ ! -e "$BADEXCEPTION_HOME/.workstation-setup-backups" ] || exit 1
assert_file "$BADEXCEPTION_HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist"
[ "$(cat "$BADEXCEPTION_HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist")" = 'badexception-case sentinel preference' ] || exit 1

# Clone the complete valid utils fixture and a minimal fresh home so a case
# clears preflight (config sources, kickstart patch, IDE settings, etc.) and
# reaches the menu-bar restore rather than failing early on an unrelated
# missing source. Sets CASE_UTILS/CASE_HOME for the caller.
clone_valid_case() {
    name=$1
    CASE_UTILS="$FIXTURE/$name-utils"
    CASE_HOME="$FIXTURE/$name-home"
    rm -rf "$CASE_UTILS" "$CASE_HOME"
    mkdir -p "$CASE_UTILS" "$CASE_HOME/.config/nvim/.git"
    cp -R "$UTILS_DIR/." "$CASE_UTILS/"
    printf '%s\n' "-- require 'custom.plugins'" >"$CASE_HOME/.config/nvim/init.lua"
    printf '%s\n' "$name sentinel" >"$CASE_HOME/.zshrc"
}
MACCY_STORE_REL="Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist"
ALTTAB_STORE_REL="Library/Preferences/com.lwouis.alt-tab-macos.plist"

# Focused: missing-domain import without export on a fresh clone-home.
# No live stores exist, so both domains are absent; import must proceed with
# no export and no menu-bar backup, yet content must equal the utils plist.
# (The .zshrc config backup IS expected here, so only the menu-bar backup
# paths are asserted absent, not the whole backups directory.)
clone_valid_case missing-domain
MISSING_DOMAINS_LOG="$FIXTURE/missing-domain-defaults.log"
MISSING_TS=20260103T000000Z
BOOTSTRAP_TIMESTAMP=$MISSING_TS HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    DEFAULTS_LOG="$MISSING_DOMAINS_LOG" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply >"$FIXTURE/missing-domain.out" 2>&1 || exit 1
assert_contains "$(cat "$MISSING_DOMAINS_LOG")" 'import com.lwouis.alt-tab-macos'
assert_contains "$(cat "$MISSING_DOMAINS_LOG")" 'import org.p0deje.Maccy'
assert_not_contains "$(cat "$MISSING_DOMAINS_LOG")" 'export'
[ ! -e "$CASE_HOME/.workstation-setup-backups/$MISSING_TS/Library/Preferences/com.lwouis.alt-tab-macos.plist" ] || exit 1
[ ! -e "$CASE_HOME/.workstation-setup-backups/$MISSING_TS/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist" ] || exit 1
assert_file "$CASE_HOME/$ALTTAB_STORE_REL"
assert_file "$CASE_HOME/$MACCY_STORE_REL"
[ "$(cat "$CASE_HOME/$ALTTAB_STORE_REL")" = "$(cat "$UTILS_DIR/macos/menu-bar/alt-tab/preferences.plist")" ] || exit 1
[ "$(cat "$CASE_HOME/$MACCY_STORE_REL")" = "$(cat "$UTILS_DIR/macos/menu-bar/maccy/preferences.plist")" ] || exit 1

# Focused: a `defaults domains` command failure must abort before import.
# The synthetic failure is env-controlled so only this run is affected.
clone_valid_case domains-fail
DOMAINS_FAIL_LOG="$FIXTURE/domains-fail-defaults.log"
if BOOTSTRAP_TIMESTAMP=20260103T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    DEFAULTS_LOG="$DOMAINS_FAIL_LOG" DEFAULTS_DOMAINS_FAIL=1 \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply >"$FIXTURE/domains-fail.out" 2>&1; then
    printf 'domains failure unexpectedly passed\n' >&2
    exit 1
fi
assert_contains "$(cat "$FIXTURE/domains-fail.out")" 'defaults domains failed'
assert_not_contains "$(cat "$DOMAINS_FAIL_LOG")" 'import'
[ ! -e "$CASE_HOME/$ALTTAB_STORE_REL" ] || exit 1
[ ! -e "$CASE_HOME/.workstation-setup-backups" ] || exit 1

# Focused: Maccy allowlist rejection with valid XML. Five sub-cases prove
# the allowlist parser rejects an unapproved key, bad/incomplete shortcut
# values, and a bad pasteboard value -- not just malformed XML. A sentinel
# Maccy store is seeded (AltTab is left absent) so we can prove the restore
# aborts before mutating Maccy; AltTab being absent means no backup dir is
# created either.
maccy_bad_case() {
    name=$1
    plist_body=$2
    clone_valid_case "maccy-$name"
    cat >"$CASE_UTILS/macos/menu-bar/maccy/preferences.plist" <<PLIST
$plist_body
PLIST
    mkdir -p "$CASE_HOME/$(dirname "$MACCY_STORE_REL")"
    printf '%s\n' "maccy-$name sentinel preference" >"$CASE_HOME/$MACCY_STORE_REL"
    if BOOTSTRAP_TIMESTAMP=20260103T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
        DEFAULTS_LOG="$FIXTURE/maccy-$name-defaults.log" \
        bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply >"$FIXTURE/maccy-$name.out" 2>&1; then
        printf 'maccy %s unexpectedly passed\n' "$name" >&2
        exit 1
    fi
    assert_contains "$(cat "$FIXTURE/maccy-$name.out")" 'invalid menu-bar plist'
    assert_not_contains "$(cat "$FIXTURE/maccy-$name-defaults.log")" 'import org.p0deje.Maccy'
    [ ! -e "$CASE_HOME/.workstation-setup-backups" ] || exit 1
    assert_file "$CASE_HOME/$MACCY_STORE_REL"
    [ "$(cat "$CASE_HOME/$MACCY_STORE_REL")" = "maccy-$name sentinel preference" ] || exit 1
}
maccy_bad_case badkey '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>enabledPasteboardTypes</key><array><string>public.utf8-plain-text</string></array>
  <key>secret</key><string>leak</string>
</dict></plist>'
maccy_bad_case badshortcut '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>KeyboardShortcuts_popup</key><string>{"badKey": 1}</string>
  <key>showSearch</key><true/>
</dict></plist>'
# Empty and incomplete shortcut JSON must fail closed as well.
maccy_bad_case emptyshortcut '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>KeyboardShortcuts_popup</key><string></string>
  <key>showSearch</key><true/>
</dict></plist>'
maccy_bad_case missingshortcut '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>KeyboardShortcuts_popup</key><string>{"carbonModifiers": 1}</string>
  <key>showSearch</key><true/>
</dict></plist>'

maccy_bad_case badpasteboard '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>enabledPasteboardTypes</key><array><string>invalid type with spaces</string></array>
  <key>showSearch</key><true/>
</dict></plist>'

# Focused partial-restore atomicity: an invalid Maccy source plist must
# leave the AltTab domain, live store, backup, and the defaults log
# completely untouched -- not just Maccy. This proves the preflight
# validates both records before mutating either, so a bad second record
# cannot partially restore the first. Unlike maccy_bad_case (which leaves
# AltTab absent), this seeds a LIVE AltTab store so a partial restore
# would have exported/backed-up AltTab before Maccy aborted.
clone_valid_case maccy-bad-alttab-live
mkdir -p "$CASE_HOME/Library/Preferences" "$CASE_HOME/$(dirname "$MACCY_STORE_REL")"
printf '%s\n' 'live alt-tab store sentinel' >"$CASE_HOME/$ALTTAB_STORE_REL"
cat >"$CASE_UTILS/macos/menu-bar/maccy/preferences.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>enabledPasteboardTypes</key><array><string>public.utf8-plain-text</string></array>
  <key>secret</key><string>leak</string>
</dict></plist>
PLIST
if BOOTSTRAP_TIMESTAMP=20260103T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    DEFAULTS_LOG="$FIXTURE/maccy-bad-alttab-live-defaults.log" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply >"$FIXTURE/maccy-bad-alttab-live.out" 2>&1; then
    printf 'maccy-bad-alttab-live unexpectedly passed\n' >&2
    exit 1
fi
assert_contains "$(cat "$FIXTURE/maccy-bad-alttab-live.out")" 'invalid menu-bar plist'
# No defaults export/import ran for EITHER domain.
ATLIVE_LOG=$(cat "$FIXTURE/maccy-bad-alttab-live-defaults.log")
assert_not_contains "$ATLIVE_LOG" 'export com.lwouis.alt-tab-macos'
assert_not_contains "$ATLIVE_LOG" 'import com.lwouis.alt-tab-macos'
assert_not_contains "$ATLIVE_LOG" 'import org.p0deje.Maccy'
# No backup directory was created at all.
[ ! -e "$CASE_HOME/.workstation-setup-backups" ] || exit 1
# The live AltTab store is byte-for-byte unchanged.
assert_file "$CASE_HOME/$ALTTAB_STORE_REL"
[ "$(cat "$CASE_HOME/$ALTTAB_STORE_REL")" = 'live alt-tab store sentinel' ] || exit 1

# Focused: logical destination symlink rejection. With the AltTab domain
# absent and a (dangling) symlink at the logical destination, apply must
# reject it as unsafe and abort before import, leaving the symlink untouched.
clone_valid_case symlink-reject
mkdir -p "$CASE_HOME/Library/Preferences"
ln -s "$FIXTURE/symlink-reject-missing-target" "$CASE_HOME/$ALTTAB_STORE_REL"
SYMLINK_LOG="$FIXTURE/symlink-reject-defaults.log"
    : >"$SYMLINK_LOG"
if BOOTSTRAP_TIMESTAMP=20260103T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    DEFAULTS_LOG="$SYMLINK_LOG" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply >"$FIXTURE/symlink-reject.out" 2>&1; then
    printf 'symlink destination unexpectedly passed\n' >&2
    exit 1
fi
assert_contains "$(cat "$FIXTURE/symlink-reject.out")" 'UNSAFE'
assert_not_contains "$(cat "$SYMLINK_LOG")" 'import'
[ -L "$CASE_HOME/$ALTTAB_STORE_REL" ] || { printf 'symlink was mutated\n' >&2; exit 1; }
[ ! -e "$CASE_HOME/.workstation-setup-backups" ] || exit 1

# Focused: logical destination symlink rejection even when the domain is
# present. Seed a live AltTab store by pointing the destination symlink at a
# real file so the faked `defaults domains` reports the domain present
# (status 0). The early symlink pre-scan must reject it as unsafe before
# `defaults domains` is ever probed, leaving the symlink untouched and
# emitting no export/import. The defaults log must stay empty (no domains
# probe, no export, no import), proving the rejection precedes the
# defaults-domain-status check.
clone_valid_case symlink-reject-present
mkdir -p "$CASE_HOME/Library/Preferences"
PRESENT_TARGET="$FIXTURE/symlink-reject-present-target"
printf '%s\n' 'present-domain live target' >"$PRESENT_TARGET"
ln -s "$PRESENT_TARGET" "$CASE_HOME/$ALTTAB_STORE_REL"
PRESENT_SYMLINK_LOG="$FIXTURE/symlink-reject-present-defaults.log"
    : >"$PRESENT_SYMLINK_LOG"
if BOOTSTRAP_TIMESTAMP=20260103T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    DEFAULTS_LOG="$PRESENT_SYMLINK_LOG" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply >"$FIXTURE/symlink-reject-present.out" 2>&1; then
    printf 'present-domain symlink destination unexpectedly passed\n' >&2
    exit 1
fi
assert_contains "$(cat "$FIXTURE/symlink-reject-present.out")" 'UNSAFE'
assert_not_contains "$(cat "$PRESENT_SYMLINK_LOG")" 'export com.lwouis.alt-tab-macos'
assert_not_contains "$(cat "$PRESENT_SYMLINK_LOG")" 'import com.lwouis.alt-tab-macos'
assert_not_contains "$(cat "$PRESENT_SYMLINK_LOG")" 'defaults domains'
[ -L "$CASE_HOME/$ALTTAB_STORE_REL" ] || { printf 'present-domain symlink was mutated\n' >&2; exit 1; }
[ ! -e "$CASE_HOME/.workstation-setup-backups" ] || exit 1

# Focused: dry-run must NOT abort when the logical destination is a symlink.
# Apply rejects the same symlink as unsafe, but dry-run must emit a
# PLAN REVIEW note plus the normal PLAN MENU_BAR line, then continue
# (processing the remaining maccy domain) without touching the symlink
# or creating any backups on disk.
clone_valid_case symlink-dryrun
mkdir -p "$CASE_HOME/Library/Preferences"
ln -s "$FIXTURE/symlink-dryrun-missing-target" "$CASE_HOME/$ALTTAB_STORE_REL"
SYMLINK_DRYRUN_OUT=$(BOOTSTRAP_TIMESTAMP=20260105T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" 2>&1) || { printf 'dry-run aborted on symlink\n' >&2; exit 1; }
assert_contains "$SYMLINK_DRYRUN_OUT" 'PLAN REVIEW $HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist is a symlink; resolve manually before apply'
assert_contains "$SYMLINK_DRYRUN_OUT" 'PLAN MENU_BAR alt-tab -> $HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist'
assert_contains "$SYMLINK_DRYRUN_OUT" 'PLAN MENU_BAR maccy -> $HOME/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist'
[ -L "$CASE_HOME/$ALTTAB_STORE_REL" ] || { printf 'dry-run symlink was mutated\n' >&2; exit 1; }
[ ! -e "$CASE_HOME/.workstation-setup-backups" ] || exit 1

# Focused: dry-run backup path when a domain exists. With a live AltTab
# store, dry-run must emit the actual timestamped backup path and create
# nothing on disk.
clone_valid_case dryrun-backup
mkdir -p "$CASE_HOME/Library/Preferences"
printf '%s\n' 'dryrun alt-tab live store' >"$CASE_HOME/$ALTTAB_STORE_REL"
DRYRUN_BACKUP_OUT=$(BOOTSTRAP_TIMESTAMP=20260104T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" 2>&1)
assert_contains "$DRYRUN_BACKUP_OUT" 'PLAN BACKUP $HOME/.workstation-setup-backups/20260104T000000Z/Library/Preferences/com.lwouis.alt-tab-macos.plist'
assert_contains "$DRYRUN_BACKUP_OUT" 'PLAN MENU_BAR alt-tab'
assert_contains "$DRYRUN_BACKUP_OUT" 'PLAN MENU_BAR maccy'
[ ! -e "$CASE_HOME/.workstation-setup-backups" ] || exit 1
[ "$(cat "$CASE_HOME/$ALTTAB_STORE_REL")" = 'dryrun alt-tab live store' ] || exit 1

# Focused: dry-run must not fail when the real macOS `defaults` is
# unreachable and must emit PLAN MENU_BAR without probing backups (no
# menu-bar PLAN BACKUP / PLAN REVIEW lines). Build a PATH with Python and the
# ordinary shell tools needed by the bootstrap, but no executable named
# `defaults`. On macOS `/bin` aliases `/usr/bin` and therefore exposes the
# real `defaults`, so retain `/bin` only where it is safe; the private bin
# supplies `dirname` and `bash` when `/bin` is omitted.
NODEFAULTS_BIN="$FIXTURE/nodefaults-bin"
mkdir -p "$NODEFAULTS_BIN"
ln -s "$(command -v dirname)" "$NODEFAULTS_BIN/dirname"
ln -s "$(command -v bash)" "$NODEFAULTS_BIN/bash"
PYBIN=$(dirname "$(command -v python3)")
NODEFAULTS_PATH="$NODEFAULTS_BIN:$PYBIN"
if [ ! -x /bin/defaults ]; then
    NODEFAULTS_PATH="$NODEFAULTS_PATH:/bin"
fi
# Guard in a fresh shell: this must fail, otherwise the defaults-absent
# dry-run branch is not being exercised.
if /bin/bash -c 'PATH=$1; command -v defaults >/dev/null 2>&1' \
    nodefaults "$NODEFAULTS_PATH"; then
    printf 'defaults unexpectedly resolved on nodefaults PATH\n' >&2
    exit 1
fi
clone_valid_case nodefaults-dryrun
NODEFAULTS_ZSH_BEFORE=$(cat "$CASE_HOME/.zshrc")
NODEFAULTS_SOURCE_BEFORE=$(cat "$CASE_UTILS/.zshrc")
NODEFAULTS_OUT=$(BOOTSTRAP_TIMESTAMP=20260106T000000Z HOME="$CASE_HOME" PATH="$NODEFAULTS_PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" 2>&1)
assert_contains "$NODEFAULTS_OUT" 'DRY_RUN'
assert_contains "$NODEFAULTS_OUT" 'PLAN MENU_BAR alt-tab'
assert_contains "$NODEFAULTS_OUT" 'PLAN MENU_BAR maccy'
assert_not_contains "$NODEFAULTS_OUT" 'PLAN BACKUP $HOME/.workstation-setup-backups'
assert_not_contains "$NODEFAULTS_OUT" 'PLAN REVIEW'
[ ! -e "$CASE_HOME/.workstation-setup-backups" ] || exit 1
[ "$(cat "$CASE_HOME/.zshrc")" = "$NODEFAULTS_ZSH_BEFORE" ] || exit 1
[ "$(cat "$CASE_UTILS/.zshrc")" = "$NODEFAULTS_SOURCE_BEFORE" ] || exit 1

# Focused: OMP staged-failure regression. When omp config set fails during
# staging, the live OMP config must be untouched and no backup created --
# proving the backup uses cp (not mv) and failed staging doesn't reach the
# live destination.
clone_valid_case omp-stage-fail
OMP_BEFORE='customLocal: preserve-me'
mkdir -p "$CASE_HOME/.omp/agent"
printf '%s\n' "$OMP_BEFORE" >"$CASE_HOME/.omp/agent/config.yml"
if BOOTSTRAP_TIMESTAMP=20260107T000000Z OMP_CONFIG_SET_FAIL=1 HOME="$CASE_HOME" \
    PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply \
    >"$FIXTURE/omp-stage-fail.out" 2>&1; then
    printf 'omp stage-fail unexpectedly succeeded\n' >&2; exit 1
fi
assert_contains "$(cat "$FIXTURE/omp-stage-fail.out")" 'cannot stage OMP preferences'
[ "$(cat "$CASE_HOME/.omp/agent/config.yml")" = "$OMP_BEFORE" ] || {
    printf 'live omp config mutated during failed staging\n' >&2; exit 1; }
[ ! -e "$CASE_HOME/.workstation-setup-backups/20260107T000000Z/.omp/agent/config.yml" ] || {
    printf 'omp backup created during failed staging\n' >&2; exit 1; }

# Focused: OMP staged-validation regression. When omp config set succeeds
# but omp config list --json returns data missing a key, the staged
# validation must catch it and leave the live destination intact.
clone_valid_case omp-stage-corrupt
mkdir -p "$CASE_HOME/.omp/agent"
printf '%s\n' "$OMP_BEFORE" >"$CASE_HOME/.omp/agent/config.yml"
if BOOTSTRAP_TIMESTAMP=20260108T000000Z OMP_CONFIG_LIST_CORRUPT=1 HOME="$CASE_HOME" \
    PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply \
    >"$FIXTURE/omp-stage-corrupt.out" 2>&1; then
    printf 'omp stage-corrupt unexpectedly succeeded\n' >&2; exit 1
fi
assert_contains "$(cat "$FIXTURE/omp-stage-corrupt.out")" 'cannot stage OMP preferences'
[ "$(cat "$CASE_HOME/.omp/agent/config.yml")" = "$OMP_BEFORE" ] || {
    printf 'live omp config mutated during corrupt staging\n' >&2; exit 1; }
[ ! -e "$CASE_HOME/.workstation-setup-backups/20260108T000000Z/.omp/agent/config.yml" ] || {
    printf 'omp backup created during corrupt staging\n' >&2; exit 1; }

# Focused: OMP descriptor-shape regression. Real omp config list --json
# returns descriptors like {key: {value: ..., type: ...}}, not direct
# values. The staged validation must normalize this shape and accept it.
clone_valid_case omp-descriptor-shape
mkdir -p "$CASE_HOME/.omp/agent"
printf '%s\n' "$OMP_BEFORE" >"$CASE_HOME/.omp/agent/config.yml"
BOOTSTRAP_TIMESTAMP=20260109T000000Z OMP_CONFIG_LIST_DESCRIPTOR=1 HOME="$CASE_HOME" \
    PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply \
    >"$FIXTURE/omp-descriptor.out" 2>&1 || exit 1
assert_contains "$(cat "$FIXTURE/omp-descriptor.out")" 'AGENT_CONFIG RESTORED omp-preferences'
# The live config must carry all 14 curated keys with correct values.
python3 - "$UTILS_DIR/ai/omp/preferences.json" "$CASE_HOME/.omp/agent/config.yml" <<'PY' || exit 1
import json, sys
with open(sys.argv[1]) as f: src = json.load(f)
expected = {}
for k, v in src.items():
    if isinstance(v, bool):
        s = 'true' if v else 'false'
    else:
        s = str(v)
    expected[k] = s
with open(sys.argv[2]) as f:
    live = [ln.rstrip('\n') for ln in f]
for key, want in expected.items():
    matches = [ln for ln in live if ln.split('=', 1)[0] == key]
    if len(matches) != 1 or matches[0] != f'{key}={want}':
        sys.exit(f'descriptor-shape OMP key {key} mismatch: {matches}')
if 'customLocal: preserve-me' not in live:
    sys.exit('descriptor-shape OMP unknown key lost')
PY

# Focused: OMP wrong-bool-value regression. When omp config list --json
# returns a non-bool garbage string for a boolean expected key, the strict
# staged validation must reject it and leave the live destination intact.
clone_valid_case omp-wrong-bool
mkdir -p "$CASE_HOME/.omp/agent"
printf '%s\n' "$OMP_BEFORE" >"$CASE_HOME/.omp/agent/config.yml"
if BOOTSTRAP_TIMESTAMP=20260110T000000Z OMP_CONFIG_LIST_WRONG_BOOL=1 HOME="$CASE_HOME" \
    PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply \
    >"$FIXTURE/omp-wrong-bool.out" 2>&1; then
    printf 'omp wrong-bool unexpectedly succeeded\n' >&2; exit 1
fi
assert_contains "$(cat "$FIXTURE/omp-wrong-bool.out")" 'cannot stage OMP preferences'
[ "$(cat "$CASE_HOME/.omp/agent/config.yml")" = "$OMP_BEFORE" ] || {
    printf 'live omp config mutated during wrong-bool staging\n' >&2; exit 1; }
[ ! -e "$CASE_HOME/.workstation-setup-backups/20260110T000000Z/.omp/agent/config.yml" ] || {
    printf 'omp backup created during wrong-bool staging\n' >&2; exit 1; }

# Focused: OMP newline-injection regression. A string value containing a
# newline could inject extra key=value records. The key serialization must
# reject control characters before passing values to omp config set.
clone_valid_case omp-newline-inject
mkdir -p "$CASE_HOME/.omp/agent"
printf '%s\n' "$OMP_BEFORE" >"$CASE_HOME/.omp/agent/config.yml"
python3 -c '
import json
with open("'"$CASE_UTILS"'/ai/omp/preferences.json") as f:
    data = json.load(f)
data["theme.dark"] = "titanium\nfakeKey=evil"
with open("'"$CASE_UTILS"'/ai/omp/preferences.json", "w") as f:
    json.dump(data, f, indent=2)
'
if BOOTSTRAP_TIMESTAMP=20260111T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply \
    >"$FIXTURE/omp-newline.out" 2>&1; then
    printf 'omp newline-inject unexpectedly succeeded\n' >&2; exit 1
fi
[ "$(cat "$CASE_HOME/.omp/agent/config.yml")" = "$OMP_BEFORE" ] || {
    printf 'live omp config mutated during newline-inject\n' >&2; exit 1; }

# Focused: OMP array value regression. An array value must be serialized
# as JSON and validated as decoded JSON, not comma-joined. This proves the
# array round-trips correctly through staging and validation.
clone_valid_case omp-array-value
mkdir -p "$CASE_HOME/.omp/agent"
printf '%s\n' "$OMP_BEFORE" >"$CASE_HOME/.omp/agent/config.yml"
python3 -c '
import json
with open("'"$CASE_UTILS"'/ai/omp/preferences.json") as f:
    data = json.load(f)
data["theme.dark"] = ["titanium", "midnight"]
with open("'"$CASE_UTILS"'/ai/omp/preferences.json", "w") as f:
    json.dump(data, f, indent=2)
'
BOOTSTRAP_TIMESTAMP=20260112T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply \
    >"$FIXTURE/omp-array.out" 2>&1 || exit 1
assert_contains "$(cat "$FIXTURE/omp-array.out")" 'AGENT_CONFIG RESTORED omp-preferences'
# The array value must be serialized as JSON in the live config.
python3 - "$CASE_HOME/.omp/agent/config.yml" <<'PY' || exit 1
import json, sys
with open(sys.argv[1]) as f:
    for line in f:
        line = line.rstrip('\n')
        if line.startswith('theme.dark='):
            val = line.split('=', 1)[1]
            parsed = json.loads(val)
            if parsed != ["titanium", "midnight"]:
                sys.exit(f'array value mismatch: {val}')
            break
    else:
        sys.exit('theme.dark not found in live config')
PY

# Focused: OMP numeric value regression. A numeric (int) source value must
# round-trip through staging and validation, with the staged verifier
# preserving numeric want and accepting numeric JSON descriptors.
clone_valid_case omp-numeric-value
mkdir -p "$CASE_HOME/.omp/agent"
printf '%s\n' "$OMP_BEFORE" >"$CASE_HOME/.omp/agent/config.yml"
python3 -c '
import json
with open("'"$CASE_UTILS"'/ai/omp/preferences.json") as f:
    data = json.load(f)
data["theme.dark"] = 42
with open("'"$CASE_UTILS"'/ai/omp/preferences.json", "w") as f:
    json.dump(data, f, indent=2)
'
BOOTSTRAP_TIMESTAMP=20260113T000000Z HOME="$CASE_HOME" PATH="$BIN_DIR:$PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply \
    >"$FIXTURE/omp-numeric.out" 2>&1 || exit 1
assert_contains "$(cat "$FIXTURE/omp-numeric.out")" 'AGENT_CONFIG RESTORED omp-preferences'
# The numeric value must appear in the live config as its string form.
python3 - "$CASE_HOME/.omp/agent/config.yml" <<'PY' || exit 1
import sys
with open(sys.argv[1]) as f:
    for line in f:
        line = line.rstrip('\n')
        if line.startswith('theme.dark='):
            val = line.split('=', 1)[1]
            if val != '42':
                sys.exit(f'numeric value mismatch: {val}')
            break
    else:
        sys.exit('theme.dark not found in live config')
PY

# Focused: missing `claude` CLI prints follow-up, does not write the claude
# destination or create a misleading backup, and does not fail unrelated
# bootstrap work. A controlled PATH is built from the fixture bin shims minus
# only `claude`, plus python3's bin dir — no real claude/omp can leak through.
# The omp merge still runs (omp is present) and restores the omp destination,
# proving the missing-tool follow-up is non-fatal for the rest of the run.
clone_valid_case missing-claude
mkdir -p "$CASE_HOME/.claude" "$CASE_HOME/.omp/agent"
cat >"$CASE_HOME/.claude/settings.json" <<'JSON'
{"model": "local-model", "customLocalKey": "preserve-me"}
JSON
printf '%s\n' 'customLocal: preserve-me' >"$CASE_HOME/.omp/agent/config.yml"
MISSING_CLAUDE_BEFORE_SRC=$(cat "$CASE_UTILS/ai/claude/settings.json")
MISSING_CLAUDE_BEFORE_CLAUDE=$(cat "$CASE_HOME/.claude/settings.json")
MISSING_CLAUDE_BIN="$FIXTURE/missing-claude-bin"
mkdir -p "$MISSING_CLAUDE_BIN"
for shim in "$BIN_DIR"/*; do
    name=$(basename "$shim")
    [ "$name" = "claude" ] && continue
    ln -s "$shim" "$MISSING_CLAUDE_BIN/$name"
done
ln -s "$(command -v python3)" "$MISSING_CLAUDE_BIN/python3"
MISSING_CLAUDE_PATH="$MISSING_CLAUDE_BIN:/usr/bin:/bin"
# Guard: claude must NOT resolve on this PATH.
if /bin/bash -c 'PATH=$1; command -v claude >/dev/null 2>&1' \
    missing-claude "$MISSING_CLAUDE_PATH"; then
    printf 'claude unexpectedly resolved on missing-claude PATH\n' >&2
    exit 1
fi
MISSING_CLAUDE_TS=20260114T000000Z
BOOTSTRAP_TIMESTAMP=$MISSING_CLAUDE_TS HOME="$CASE_HOME" PATH="$MISSING_CLAUDE_PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply \
    >"$FIXTURE/missing-claude.out" 2>&1 || { cat "$FIXTURE/missing-claude.out" >&2; exit 1; }
assert_contains "$(cat "$FIXTURE/missing-claude.out")" 'FOLLOW_UP Claude Code: install/authenticate Claude Code, then rerun bootstrap.'
# The unrelated omp merge must have succeeded.
assert_contains "$(cat "$FIXTURE/missing-claude.out")" 'AGENT_CONFIG RESTORED omp-preferences'
[ "$(cat "$CASE_UTILS/ai/claude/settings.json")" = "$MISSING_CLAUDE_BEFORE_SRC" ] || {
    printf 'claude source mutated when claude CLI absent\n' >&2; exit 1; }
[ "$(cat "$CASE_HOME/.claude/settings.json")" = "$MISSING_CLAUDE_BEFORE_CLAUDE" ] || {
    printf 'claude destination mutated when claude CLI absent\n' >&2; exit 1; }
[ ! -e "$CASE_HOME/.workstation-setup-backups/$MISSING_CLAUDE_TS/.claude/settings.json" ] || {
    printf 'misleading claude backup created when claude CLI absent\n' >&2; exit 1; }
# The omp destination must carry the curated values (unrelated work completed).
python3 - "$CASE_UTILS/ai/omp/preferences.json" "$CASE_HOME/.omp/agent/config.yml" <<'PY' || exit 1
import json, sys
with open(sys.argv[1]) as f: src = json.load(f)
expected = {}
for k, v in src.items():
    if isinstance(v, bool):
        s = 'true' if v else 'false'
    else:
        s = str(v)
    expected[k] = s
with open(sys.argv[2]) as f:
    live = [ln.rstrip('\n') for ln in f]
for key, want in expected.items():
    matches = [ln for ln in live if ln.split('=', 1)[0] == key]
    if len(matches) != 1 or matches[0] != f'{key}={want}':
        sys.exit(f'OMP curated key missing or wrong: {key}')
if 'customLocal: preserve-me' not in live:
    sys.exit('OMP unknown key customLocal lost')
PY

# Focused: missing `omp` CLI prints follow-up, does not write the omp
# destination or create a misleading backup, and does not fail unrelated
# bootstrap work. A controlled PATH is built from the fixture bin shims minus
# only `omp`, plus python3's bin dir — no real claude/omp can leak through.
# The claude merge still runs (claude is present) and restores the claude
# destination, proving the missing-tool follow-up is non-fatal for the rest
# of the run.
clone_valid_case missing-omp
mkdir -p "$CASE_HOME/.claude" "$CASE_HOME/.omp/agent"
cat >"$CASE_HOME/.claude/settings.json" <<'JSON'
{"model": "local-model", "customLocalKey": "preserve-me"}
JSON
printf '%s\n' 'customLocal: preserve-me' >"$CASE_HOME/.omp/agent/config.yml"
MISSING_OMP_BEFORE_SRC=$(cat "$CASE_UTILS/ai/omp/preferences.json")
MISSING_OMP_BEFORE_OMP=$(cat "$CASE_HOME/.omp/agent/config.yml")
MISSING_OMP_BIN="$FIXTURE/missing-omp-bin"
mkdir -p "$MISSING_OMP_BIN"
for shim in "$BIN_DIR"/*; do
    name=$(basename "$shim")
    [ "$name" = "omp" ] && continue
    ln -s "$shim" "$MISSING_OMP_BIN/$name"
done
ln -s "$(command -v python3)" "$MISSING_OMP_BIN/python3"
MISSING_OMP_PATH="$MISSING_OMP_BIN:/usr/bin:/bin"
# Guard: omp must NOT resolve on this PATH.
if /bin/bash -c 'PATH=$1; command -v omp >/dev/null 2>&1' \
    missing-omp "$MISSING_OMP_PATH"; then
    printf 'omp unexpectedly resolved on missing-omp PATH\n' >&2
    exit 1
fi
MISSING_OMP_TS=20260115T000000Z
BOOTSTRAP_TIMESTAMP=$MISSING_OMP_TS HOME="$CASE_HOME" PATH="$MISSING_OMP_PATH" \
    bash "$BOOTSTRAP" --os macos --profile base --utils-path "$CASE_UTILS" --apply \
    >"$FIXTURE/missing-omp.out" 2>&1 || { cat "$FIXTURE/missing-omp.out" >&2; exit 1; }
assert_contains "$(cat "$FIXTURE/missing-omp.out")" 'FOLLOW_UP OMP: install Oh My Pi, then rerun bootstrap.'
# The unrelated claude merge must have succeeded.
assert_contains "$(cat "$FIXTURE/missing-omp.out")" 'AGENT_CONFIG RESTORED claude-preferences'
[ "$(cat "$CASE_UTILS/ai/omp/preferences.json")" = "$MISSING_OMP_BEFORE_SRC" ] || {
    printf 'omp source mutated when omp CLI absent\n' >&2; exit 1; }
[ "$(cat "$CASE_HOME/.omp/agent/config.yml")" = "$MISSING_OMP_BEFORE_OMP" ] || {
    printf 'omp destination mutated when omp CLI absent\n' >&2; exit 1; }
[ ! -e "$CASE_HOME/.workstation-setup-backups/$MISSING_OMP_TS/.omp/agent/config.yml" ] || {
    printf 'misleading omp backup created when omp CLI absent\n' >&2; exit 1; }
# The claude destination must carry the curated values (unrelated work completed).
python3 - "$CASE_UTILS/ai/claude/settings.json" "$CASE_HOME/.claude/settings.json" <<'PY' || exit 1
import json, sys
with open(sys.argv[1]) as f: src = json.load(f)
with open(sys.argv[2]) as f: dst = json.load(f)
for k, v in src.items():
    if k not in dst or dst[k] != v:
        sys.exit(f'claude curated key mismatch: {k}')
if dst.get('customLocalKey') != 'preserve-me':
    sys.exit('claude unknown key customLocalKey lost')
PY
if grep -E 'fixture|placeholder|token|secret|password' "$FIXTURE"/*.out >/dev/null 2>&1; then
    printf 'secret fixture leaked into output\n' >&2
    exit 1
fi

printf 'bootstrap fixture tests: PASS\n'

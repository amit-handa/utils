#!/usr/bin/env bash
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PACKAGE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)
SNAPSHOT="$PACKAGE_DIR/scripts/snapshot.sh"
LIB="$PACKAGE_DIR/scripts/lib.sh"
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/snapshot-test.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT HUP INT TERM
HOME_DIR="$FIXTURE/home"
BIN_DIR="$FIXTURE/bin"
UTILS_DIR="$FIXTURE/utils"
NOW=1781000000
mkdir -p "$HOME_DIR" "$BIN_DIR" "$UTILS_DIR/.hammerspoon/keyboard" \
  "$UTILS_DIR/nvim-custom/lua/custom/plugins" "$UTILS_DIR/.config/gh" \
  "$UTILS_DIR/.local/bin" "$UTILS_DIR/ide/vscode" "$UTILS_DIR/ide/cursor" \
  "$HOME_DIR/.hammerspoon" "$HOME_DIR/.config/herdr" "$HOME_DIR/.cursor" \
  "$HOME_DIR/.omp" "$HOME_DIR/.kube" "$HOME_DIR/.ssh" "$HOME_DIR/go-bin" \
  "$HOME_DIR/safe" \
  "$HOME_DIR/Applications/JetBrainsIDE.app" \
  "$HOME_DIR/Library/Application Support/com.mitchellh.ghostty" \
  "$HOME_DIR/.local/share/applications" "$HOME_DIR/.config/ghostty"

cat >"$BIN_DIR/brew" <<'SH'
#!/bin/sh
case "$*" in
  'list --formula --versions') printf 'git 2.51.0\ngh 2.97.0\nherdr 0.8.0\nomp 17.3.0\nteleport 18.0\ntmux 3.5\nneovim 0.11.0\n' ;;
  'list --cask --versions') printf 'cursor 1.0\nghostty 1.2\nhammerspoon 1.0\nalt-tab 0.27\nmaccy 0.30\n' ;;
esac
SH
cat >"$BIN_DIR/mdfind" <<'SH'
#!/bin/sh
cat <<'APPS'
/Applications/JetBrainsIDE.app
/Applications/Visual Studio Code.app
/Applications/Cursor.app
/Applications/Ghostty.app
/Applications/Hammerspoon.app
/Applications/AltTab.app
/Applications/Maccy.app
/Applications/Android Studio.app
/Applications/Xcode.app
/Applications/Uncatalogued Dev Tool.app
/Applications/工具.app
/System/Library/CoreServices/PrivateSystemTool.app
APPS
SH
cat >"$BIN_DIR/mdls" <<'SH'
#!/bin/sh
last=''
for argument in "$@"; do last=$argument; done
case $last in
  */JetBrainsIDE.app) printf 'IntelliJ IDEA\n' ;;
  *) name=${last##*/}; printf '%s\n' "${name%.app}" ;;
esac
SH
cat >"$BIN_DIR/dpkg-query" <<'SH'
#!/bin/sh
printf 'git\t1:2.43.0\nlibc6:arm64\t2.39\ntmux\t3.4\nneovim\t0.9.5\nnodejs\t22.0\npython3\t3.12\ngolang-go\t1.22\nopenjdk-21-jdk\t21.0\n'
SH
cat >"$BIN_DIR/apt" <<'SH'
#!/bin/sh
printf 'Listing...\napt-fallback-tool/stable,now 2.0 arm64 [installed]\n'
SH
cat >"$BIN_DIR/tool-shim" <<'SH'
#!/bin/sh
name=${0##*/}
case $name in
  java) printf 'openjdk version "21.0.1"\n' >&2 ;;
  jenv) printf 'jenv 0.5.7\n' ;;
  go) printf 'go version go1.24.0 darwin/arm64\n' ;;
  node) printf 'v22.0.0\n' ;;
  bun) printf '1.2.0\n' ;;
  adb) printf 'Android Debug Bridge version 1.0.41\n' ;;
  xcodebuild) printf 'Xcode 16.0\nBuild version 16A1\n' ;;
esac
exit 0
SH
chmod +x "$BIN_DIR/brew" "$BIN_DIR/mdfind" "$BIN_DIR/mdls" \
  "$BIN_DIR/dpkg-query" "$BIN_DIR/apt" "$BIN_DIR/tool-shim"
for name in idea code cursor nvim vim herdr omp claude codex tmux gh tsh kubectl k kgpo kgcmoyaml bazel java jenv go node bun adb xcodebuild; do
  ln -s tool-shim "$BIN_DIR/$name"
done
printf '#!/bin/sh\nexit 0\n' >"$HOME_DIR/go-bin/custom-go-tool"
chmod +x "$HOME_DIR/go-bin/custom-go-tool"

printf '# safe zsh config\n' >"$UTILS_DIR/.zshrc"
printf '# safe work zsh config\n' >"$UTILS_DIR/.zshrc.work"
printf '%s\n' '# safe herdr title watcher' >"$UTILS_DIR/.local/bin/herdr-title-watch"
chmod +x "$UTILS_DIR/.local/bin/herdr-title-watch"
printf '# safe bash config\n' >"$UTILS_DIR/.bashrc"
printf '# identity-free git config\n' >"$UTILS_DIR/.gitconfig"
printf '# safe tmux config\n' >"$UTILS_DIR/.tmux.conf"
printf '# safe ghostty config\n' >"$UTILS_DIR/ghostty.config"
printf '%s\n' '{"editor.minimap.enabled": false}' >"$UTILS_DIR/ide/vscode/settings.json"
printf '%s\n' '{"workbench.colorTheme": "Cursor Dark"}' >"$UTILS_DIR/ide/cursor/settings.json"
printf '%s\n' '[]' >"$UTILS_DIR/ide/cursor/keybindings.json"
printf '%s\n' '-- safe nvim custom config' >"$UTILS_DIR/nvim-custom/lua/custom/plugins/init.lua"
printf '%s\n' '# safe vim config' >"$UTILS_DIR/.vimrc"
printf '%s\n' '[core]' 'editor = nvim' >"$UTILS_DIR/.config/gh/config.yml"
printf '# safe aliases\n' >"$UTILS_DIR/.kubectlAliases"
printf '%s\n' '-- safe hammerspoon config' >"$UTILS_DIR/.hammerspoon/init.lua"
printf '%s\n' '-- safe unusual module' >"$UTILS_DIR/.hammerspoon/keyboard/evil|column.lua"
printf '%s\n' '-- safe backslash-pipe module' >"$UTILS_DIR/.hammerspoon/keyboard/evil\\|column.lua"
printf '%s\n' '-- safe backtick module' >"$UTILS_DIR/.hammerspoon/keyboard/"'a`b.lua'
printf '%s\n' '-- safe plain module' >"$UTILS_DIR/.hammerspoon/keyboard/ab.lua"
printf 'fixture-sensitive-kube-token\n' >"$HOME_DIR/.kube/config"
printf 'fixture-ssh-private-value\n' >"$HOME_DIR/.ssh/sentinel"
ln -s .ssh "$HOME_DIR/inventory-link"
printf 'terminal config\n' >"$HOME_DIR/.config/ghostty/config"
printf 'mac terminal config\n' >"$HOME_DIR/Library/Application Support/com.mitchellh.ghostty/config"
cat >"$HOME_DIR/.local/share/applications/cursor.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Cursor
DESKTOP
cat >"$HOME_DIR/.zsh_history" <<EOF
: $((NOW - 100)):0;idea private-project-path
: $((NOW - 90)):0;herdr --host fixture-host.internal
: $((NOW - 80)):0;omp --token fixture-secret-token
: $((NOW - 70)):0;mystery-tool --secret fixture-secret-payload
: $((NOW - 60)):0;git status
: $((NOW - 50)):0;gst
EOF

git -C "$UTILS_DIR" init -q
git -C "$UTILS_DIR" add -f .zshrc .zshrc.work .bashrc .gitconfig .tmux.conf ghostty.config nvim-custom/lua/custom .vimrc .config/gh/config.yml .kubectlAliases .local/bin/herdr-title-watch .hammerspoon/init.lua .hammerspoon/keyboard ide/vscode/settings.json ide/cursor/settings.json ide/cursor/keybindings.json
git -C "$UTILS_DIR" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
git -C "$HOME_DIR" init -q
git -C "$HOME_DIR" add -f .
git -C "$HOME_DIR" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture-home
HOME_BEFORE=$(git -C "$HOME_DIR" status --short)
BEFORE=$(git -C "$UTILS_DIR" status --short)

assert_contains() {
  case $1 in *"$2"*) ;; *) printf 'missing expected text: %s\n' "$2" >&2; exit 1 ;; esac
}
assert_not_contains() {
  case $1 in *"$2"*) printf 'found private/unexpected text: %s\n' "$2" >&2; exit 1 ;; *) ;; esac
}
# Extract the body of a ## section: text after "## <heading>" up to the next
# "## " heading.  Fails (empty output) when the heading is absent.
section_content() {
  local document=$1 heading=$2
  awk -v h="## $heading" '
    $0 == h { in_section=1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' <<<"$document"
}
(
  shopt -s patsub_replacement 2>/dev/null || true
  . "$LIB"
  [ "$(ws_markdown_escape 'a&b|c`d')" = 'a&amp;b&#124;c&#96;d' ]
)
run_snapshot() {
  local os=$1 output=$2 utils_path=${3:-$UTILS_DIR}
  HOME="$HOME_DIR" HISTFILE="$HOME_DIR/.zsh_history" GOBIN="$HOME_DIR/go-bin" \
    SNAPSHOT_NOW_EPOCH=$NOW PATH="$BIN_DIR:/usr/bin:/bin" \
    bash "$SNAPSHOT" --os "$os" --since 7d \
      --utils-path "$utils_path" --output-dir "$output" >/dev/null
}

MAC_OUT="$FIXTURE/out-macos"
run_snapshot macos "$MAC_OUT"
MAC_CURRENT=$(cat "$MAC_OUT/current-machine.md")
MAC_RECENT=$(cat "$MAC_OUT/recent-usage.md")
CONFIG_SECTION=$(section_content "$MAC_CURRENT" 'Configuration sources')
assert_contains "$CONFIG_SECTION" '| zshrc |'
assert_contains "$CONFIG_SECTION" '| base |'
assert_not_contains "$CONFIG_SECTION" 'personal|server|work'
for expected in 'IntelliJ IDEA' 'Visual Studio Code' 'Cursor' 'Herdr' \
  'Hammerspoon' 'Oh My Pi' 'Ghostty' 'Claude Code' 'Codex' \
  'GitHub CLI' 'Android tooling' 'Xcode and simulators' \
  'formula' 'cask' 'go-bin' 'custom-go-tool' 'utils-revision' 'present' \
  'jenv=' 'bun=' 'hammerspoon:init.lua' 'nvim-custom' 'Desired profile' \
  '## Recent usage' 'Uncatalogued Dev Tool'; do
  assert_contains "$MAC_CURRENT" "$expected"
done
assert_not_contains "$MAC_CURRENT" 'PrivateSystemTool'
assert_not_contains "$MAC_CURRENT" '| application | JetBrainsIDE |'
assert_contains "$MAC_CURRENT" '| formula | gh | 2.97.0 | work |'
assert_contains "$MAC_CURRENT" '| formula | herdr | 0.8.0 | work |'
assert_contains "$MAC_CURRENT" '| formula | omp | 17.3.0 | base |'
assert_contains "$MAC_RECENT" 'IntelliJ IDEA'
assert_contains "$MAC_RECENT" 'Herdr'
assert_contains "$MAC_CURRENT" '工具'
assert_contains "$MAC_CURRENT" 'hammerspoon:keyboard/evil&#124;column.lua'
assert_contains "$MAC_CURRENT" 'hammerspoon:keyboard/evil\&#124;column.lua'
assert_contains "$MAC_CURRENT" 'hammerspoon:keyboard/a&#96;b.lua'
assert_contains "$MAC_CURRENT" 'hammerspoon:keyboard/ab.lua'
assert_contains "$MAC_CURRENT" '| formula | teleport | 18.0 | work |'
assert_contains "$MAC_RECENT" 'Oh My Pi'
assert_contains "$MAC_CURRENT" '## CLI and shells'
assert_contains "$MAC_CURRENT" '| Git | detected |'
assert_not_contains "$MAC_CURRENT" '| ghostty-linux |'
assert_contains "$MAC_RECENT" '| Git | developer | base | 2 |'
assert_contains "$MAC_RECENT" 'mystery-tool'
assert_contains "$MAC_CURRENT" '## Menu-bar utilities'
MENU_BAR_SECTION=$(section_content "$MAC_CURRENT" 'Menu-bar utilities')
[ -n "$MENU_BAR_SECTION" ] || { printf 'Menu-bar utilities section is empty\n' >&2; exit 1; }
assert_contains "$MENU_BAR_SECTION" '| AltTab | detected | application:AltTab | base@macos |'
assert_contains "$MENU_BAR_SECTION" '| Maccy | detected | application:Maccy | base@macos |'
assert_not_contains "$MENU_BAR_SECTION" '| Git |'
assert_contains "$MAC_CURRENT" '| cask | alt-tab | 0.27 | base@macos |'
assert_contains "$MAC_CURRENT" '| cask | maccy | 0.30 | base@macos |'

LINUX_OUT="$FIXTURE/out-linux"
run_snapshot linux "$LINUX_OUT"
LINUX_CURRENT=$(cat "$LINUX_OUT/current-machine.md")
assert_contains "$LINUX_CURRENT" 'apt'
assert_contains "$LINUX_CURRENT" 'Hammerspoon'
assert_contains "$LINUX_CURRENT" 'libc6:arm64'
assert_contains "$LINUX_CURRENT" 'not detected'
assert_contains "$LINUX_CURRENT" '$HOME/.config/ghostty/config'
assert_contains "$LINUX_CURRENT" '| apt | neovim | 0.9.5 | base |'
assert_contains "$LINUX_CURRENT" '| apt | nodejs | 22.0 | base |'
assert_contains "$LINUX_CURRENT" '| apt | python3 | 3.12 | base |'
assert_contains "$LINUX_CURRENT" '| apt | golang-go | 1.22 | base |'
assert_contains "$LINUX_CURRENT" '| apt | openjdk-21-jdk | 21.0 | base |'
assert_not_contains "$LINUX_CURRENT" '## Menu-bar utilities'
assert_not_contains "$LINUX_CURRENT" '| AltTab |'
assert_not_contains "$LINUX_CURRENT" '| Maccy |'
assert_not_contains "$LINUX_CURRENT" '| cask | alt-tab |'
assert_not_contains "$LINUX_CURRENT" '| cask | maccy |'
printf '#!/bin/sh\nexit 0\n' >"$BIN_DIR/dpkg-query"
chmod +x "$BIN_DIR/dpkg-query"
LINUX_APT_OUT="$FIXTURE/out-linux-apt"
run_snapshot linux "$LINUX_APT_OUT"
LINUX_APT_CURRENT=$(cat "$LINUX_APT_OUT/current-machine.md")
assert_contains "$LINUX_APT_CURRENT" 'apt-fallback-tool'

SYNTHETIC_PACKAGE="$FIXTURE/synthetic-package"
mkdir -p "$SYNTHETIC_PACKAGE/scripts" "$SYNTHETIC_PACKAGE/references"
cp "$SNAPSHOT" "$SYNTHETIC_PACKAGE/scripts/snapshot.sh"
cp "$LIB" "$SYNTHETIC_PACKAGE/scripts/lib.sh"
cp "$PACKAGE_DIR/scripts/recent_usage.py" "$SYNTHETIC_PACKAGE/scripts/recent_usage.py"
cp "$PACKAGE_DIR/references/config-sources.tsv" \
  "$SYNTHETIC_PACKAGE/references/config-sources.tsv"
cp "$PACKAGE_DIR/references/tool-catalog.tsv" \
  "$SYNTHETIC_PACKAGE/references/tool-catalog.tsv"
printf '%s\n' \
  'xcode-platform-prefixed	Xcode platform-prefixed	mobile	xcodebuild	Xcode	macos=Library/Developer	mobile@macos' \
  >>"$SYNTHETIC_PACKAGE/references/tool-catalog.tsv"
SYNTHETIC_OUT="$FIXTURE/out-synthetic-catalog"
HOME="$HOME_DIR" HISTFILE="$HOME_DIR/.zsh_history" GOBIN="$HOME_DIR/go-bin" \
  SNAPSHOT_NOW_EPOCH=$NOW PATH="$BIN_DIR:/usr/bin:/bin" \
  bash "$SYNTHETIC_PACKAGE/scripts/snapshot.sh" --os linux --since 7d \
    --utils-path "$UTILS_DIR" --output-dir "$SYNTHETIC_OUT" >/dev/null
SYNTHETIC_CURRENT=$(cat "$SYNTHETIC_OUT/current-machine.md")
assert_contains "$SYNTHETIC_CURRENT" \
  '| Xcode platform-prefixed | detected | command:xcodebuild | mobile@macos |'
UNSAFE_UTILS="$FIXTURE/unsafe-utils"
mkdir -p "$UNSAFE_UTILS"
ln -s "$HOME_DIR/.ssh" "$UNSAFE_UTILS/.hammerspoon"
UNSAFE_OUT="$FIXTURE/out-unsafe-utils"
run_snapshot macos "$UNSAFE_OUT" "$UNSAFE_UTILS"
UNSAFE_CURRENT=$(cat "$UNSAFE_OUT/current-machine.md")
assert_contains "$UNSAFE_CURRENT" '| hammerspoon | unsafe |'

FAIL_OUT="$FIXTURE/out-publication-failure"
mkdir -p "$FAIL_OUT"
printf 'old-current\n' >"$FAIL_OUT/current-machine.md"
printf 'old-recent\n' >"$FAIL_OUT/recent-usage.md"
cat >"$BIN_DIR/mv" <<'SH'
#!/bin/sh
destination=''
for argument in "$@"; do destination=$argument; done
case $destination in */.recent-usage.md.tmp.*) exit 1 ;; esac
exec /bin/mv "$@"
SH
chmod +x "$BIN_DIR/mv"
if run_snapshot macos "$FAIL_OUT" 2>/dev/null; then
  printf 'snapshot reported success after publication failure\n' >&2
  exit 1
fi
rm -f "$BIN_DIR/mv"
[ "$(cat "$FAIL_OUT/current-machine.md")" = old-current ]
[ "$(cat "$FAIL_OUT/recent-usage.md")" = old-recent ]
assert_not_contains "$UNSAFE_CURRENT" 'hammerspoon:sentinel'
assert_not_contains "$UNSAFE_CURRENT" 'fixture-ssh-private-value'

COMBINED=$MAC_CURRENT$MAC_RECENT$LINUX_CURRENT$(cat "$LINUX_OUT/recent-usage.md")$LINUX_APT_CURRENT$UNSAFE_CURRENT
assert_not_contains "$LINUX_CURRENT" '| ghostty-macos |'
for private in "$FIXTURE" 'fixture-sensitive-kube-token' 'fixture-ssh-private-value' \
  'fixture-host.internal' 'fixture-secret-token' 'fixture-secret-payload' \
  'private-project-path' '--host' '--token' '--secret'; do
  assert_not_contains "$COMBINED" "$private"
done
AFTER=$(git -C "$UTILS_DIR" status --short)
[ "$BEFORE" = "$AFTER" ] || { printf 'snapshot modified utils fixture\n' >&2; exit 1; }
HOME_AFTER=$(git -C "$HOME_DIR" status --short --untracked-files=all)
[ "$HOME_BEFORE" = "$HOME_AFTER" ] || {
  printf 'snapshot modified fixture home: %s\n' "$HOME_AFTER" >&2
  exit 1
}
if HOME="$HOME_DIR" HISTFILE="$HOME_DIR/.zsh_history" GOBIN="$HOME_DIR/go-bin" \
  SNAPSHOT_NOW_EPOCH=$NOW PATH="$BIN_DIR:/usr/bin:/bin" \
  bash "$SNAPSHOT" --os macos --since 7d --utils-path "$UTILS_DIR" \
    --output-dir "$HOME_DIR/safe/../.ssh" >/dev/null 2>&1; then
  printf 'snapshot accepted traversed sensitive output\n' >&2
  exit 1
fi
if HOME="$HOME_DIR" HISTFILE="$HOME_DIR/.zsh_history" GOBIN="$HOME_DIR/go-bin" \
  SNAPSHOT_NOW_EPOCH=$NOW PATH="$BIN_DIR:/usr/bin:/bin" \
  bash "$SNAPSHOT" --os macos --since 7d --utils-path "$UTILS_DIR" \
    --output-dir "$HOME_DIR/inventory-link" >/dev/null 2>&1; then
  printf 'snapshot accepted symlinked sensitive output\n' >&2
  exit 1
fi
[ ! -e "$HOME_DIR/.ssh/current-machine.md" ]
[ -f "$MAC_OUT/current-machine.md" ] && [ -f "$MAC_OUT/recent-usage.md" ]
[ -f "$LINUX_OUT/current-machine.md" ] && [ -f "$LINUX_OUT/recent-usage.md" ]
printf 'snapshot fixture tests: PASS\n'

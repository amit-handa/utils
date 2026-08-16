#!/usr/bin/env bash
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
UTILS_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd -P)
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/environment-profile-test.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT HUP INT TERM
HOME_DIR="$FIXTURE/home"
mkdir -p "$HOME_DIR/.oh-my-zsh"
printf '%s\n' '# fixture oh-my-zsh' >"$HOME_DIR/.oh-my-zsh/oh-my-zsh.sh"
printf '%s\n' 'print -r -- loaded >"$PROFILE_MARKER"' >"$HOME_DIR/.zshrc.work"

run_profile() {
  local profile=$1
  rm -f "$FIXTURE/marker"
  if [ "$profile" = unset ]; then
    env -u WORKSTATION_PROFILE HOME="$HOME_DIR" UTILS_DIR="$UTILS_DIR" \
      PROFILE_MARKER="$FIXTURE/marker" zsh -d -f -c \
      'source "$UTILS_DIR/.zshrc"' >/dev/null 2>&1
  else
    HOME="$HOME_DIR" UTILS_DIR="$UTILS_DIR" PROFILE_MARKER="$FIXTURE/marker" \
      WORKSTATION_PROFILE="$profile" zsh -d -f -c \
      'source "$UTILS_DIR/.zshrc"' >/dev/null 2>&1
  fi
}

run_profile personal
[ ! -e "$FIXTURE/marker" ] || exit 1
run_profile server
[ ! -e "$FIXTURE/marker" ] || exit 1
run_profile work
[ -f "$FIXTURE/marker" ] || exit 1
run_profile unset
[ -f "$FIXTURE/marker" ] || exit 1

BIN_DIR="$FIXTURE/bin"
mkdir -p "$BIN_DIR" "$HOME_DIR/.ssh"
printf '%s\n' 'SSH_AGENT_PID=123' >"$HOME_DIR/.ssh/environment"
cat >"$BIN_DIR/ps" <<'SH'
#!/bin/sh
printf '%s\n' 'root 123 1 0 00:00 ? 00:00:00 ssh-agent'
SH
chmod +x "$BIN_DIR/ps"
for command in kubectl kops helm minikube; do
  cat >"$BIN_DIR/$command" <<'SH'
#!/bin/sh
printf '%s\n' work-bash-loaded >>"$PROFILE_MARKER"
printf '%s\n' ':'
SH
  chmod +x "$BIN_DIR/$command"
done
printf '%s\n' 'printf "%s\n" work-bash-loaded >>"$PROFILE_MARKER"' >"$HOME_DIR/.kubectlAliases"

run_bash_profile() {
  local source_file=$1 profile=$2
  rm -f "$FIXTURE/marker"
  if [ "$profile" = unset ]; then
    env -u WORKSTATION_PROFILE HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" PS1=fixture \
      UTILS_DIR="$UTILS_DIR" SOURCE_FILE="$source_file" PROFILE_MARKER="$FIXTURE/marker" \
      bash --noprofile --norc -c 'source "$UTILS_DIR/4-archives/$SOURCE_FILE"' \
      >/dev/null 2>&1
  else
    HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" PS1=fixture \
      UTILS_DIR="$UTILS_DIR" SOURCE_FILE="$source_file" PROFILE_MARKER="$FIXTURE/marker" \
      WORKSTATION_PROFILE="$profile" bash --noprofile --norc -c \
      'source "$UTILS_DIR/4-archives/$SOURCE_FILE"' >/dev/null 2>&1
  fi
  if [ "$profile" = personal ] || [ "$profile" = server ]; then
    [ ! -e "$FIXTURE/marker" ] || exit 1
  else
    [ -f "$FIXTURE/marker" ] || exit 1
  fi
}

for source_file in .bashrc0 .bashrc0.mac; do
  run_bash_profile "$source_file" personal
  run_bash_profile "$source_file" server
  run_bash_profile "$source_file" work
  run_bash_profile "$source_file" unset
done
printf 'environment profile fixture tests: PASS\n'

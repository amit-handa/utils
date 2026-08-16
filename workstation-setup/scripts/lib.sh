#!/usr/bin/env bash

# Shared Bash 3.2-compatible helpers for workstation setup scripts.

ws_die() {
  printf 'error: %s\n' "$1" >&2
  return 1
}

ws_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ws_markdown_escape() {
  local value=$1
  value=${value//$'\n'/ }
  value=${value//$'\r'/ }
  value=${value//&/\&amp;}
  value=${value//|/\&#124;}
  value=${value//\`/\&#96;}
  printf '%s' "$value"
}

ws_safe_token() {
  case $1 in
    ''|*[!A-Za-z0-9@._+\/-]*) return 1 ;;
    *) return 0 ;;
  esac
}


ws_safe_package_name() {
  case $1 in
    ''|*[!A-Za-z0-9@._+:\/-]*) return 1 ;;
    *) return 0 ;;
  esac
}


ws_safe_tsv_field() {
  case $1 in
    ''|*$'\t'*|*$'\n'*|*$'\r'*) return 1 ;;
    *) return 0 ;;
  esac
}

ws_forbidden_relative_path() {
  case $1 in
    .ssh|.ssh/*|.aws|.aws/*|.kube|.kube/*|.secrets|.secrets/*|\
    .tsh|.tsh/*|.netrc|.npmrc|.env|.env.*|*/.env|*/.env.*|\
    .docker/config.json|.config/gcloud|.config/gcloud/*|\
    .config/gh/hosts.yml|.config/gh/state.yml|\
    .claude/sessions|.claude/sessions/*|.cursor/projects|.cursor/projects/*|\
    .codex/sessions|.codex/sessions/*|.omp/logs|.omp/logs/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ws_safe_relative_path() {
  case $1 in
    ''|/*|..|../*|*/../*|*/..) return 1 ;;
  esac
  ! ws_forbidden_relative_path "$1"
}

ws_output_path_is_safe() {
  local path=$1 relative home_root=${WS_HOME_CANONICAL:-$HOME}
  case $path in
    "$home_root") return 1 ;;
    "$home_root"/*)
      relative=${path#"$home_root"/}
      ! ws_forbidden_relative_path "$relative"
      ;;
    *) return 0 ;;
  esac
}

ws_home_label() {
  local path=$1
  case $path in
    "$HOME") printf '$HOME' ;;
    "$HOME"/*) printf '$HOME/%s' "${path#"$HOME"/}" ;;
    *) printf '$EXTERNAL' ;;
  esac
}

ws_profile_matches() {
  local tokens=$1 requested=$2 os=$3 token profile platform
  local old_ifs=$IFS
  IFS='|'
  for token in $tokens; do
    profile=${token%@*}
    platform=''
    case $token in *@*) platform=${token#*@} ;; esac
    if [ -n "$platform" ] && [ "$platform" != "$os" ]; then
      continue
    fi
    if [ "$profile" = "$requested" ] || {
      [ "$profile" = base ] && { [ "$requested" = work ] || [ "$requested" = mobile ]; }
    }; then
      IFS=$old_ifs
      return 0
    fi
  done
  IFS=$old_ifs
  return 1
}


ws_tokens_apply_to_os() {
  local tokens=$1 os=$2 token platform
  local old_ifs=$IFS
  IFS='|'
  for token in $tokens; do
    platform=''
    case $token in *@*) platform=${token#*@} ;; esac
    if [ -z "$platform" ] || [ "$platform" = "$os" ]; then
      IFS=$old_ifs
      return 0
    fi
  done
  IFS=$old_ifs
  return 1
}

ws_resolve_config_root() {
  local roots=$1 os=$2 entry
  local old_ifs=$IFS
  case $roots in
    '') return 1 ;;
    *'='*)
      IFS='|'
      for entry in $roots; do
        if [ "${entry%%=*}" = "$os" ]; then
          IFS=$old_ifs
          printf '%s' "${entry#*=}"
          return 0
        fi
      done
      IFS=$old_ifs
      return 1
      ;;
    *) printf '%s' "$roots" ;;
  esac
}

ws_sha256_file() {
  local path=$1 digest
  [ -f "$path" ] && [ ! -L "$path" ] || return 1
  if ws_command_exists shasum; then
    digest=$(shasum -a 256 "$path" 2>/dev/null) || return 1
  elif ws_command_exists sha256sum; then
    digest=$(sha256sum "$path" 2>/dev/null) || return 1
  else
    return 1
  fi
  printf '%s' "${digest%% *}"
}

ws_tsv_to_unit_separator() {
  printf '%s\n' "${1//$'\t'/$'\034'}"
}

ws_sanitize_version_line() {
  local value=$1
  value=${value%%$'\n'*}
  value=${value//$'\r'/}
  if [ -n "${HOME:-}" ]; then
    value=${value//"$HOME"/'$HOME'}
  fi
  # Version collectors are allowlisted; strip shell/control punctuation anyway.
  printf '%s' "$value" | LC_ALL=C tr -cd '[:alnum:] ._+,:@()=\/$-'
}

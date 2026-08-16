#!/usr/bin/env bash
set -u
export PYTHONDONTWRITEBYTECODE=1

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PACKAGE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

CATALOG="$PACKAGE_DIR/references/tool-catalog.tsv"
CONFIG_SOURCES="$PACKAGE_DIR/references/config-sources.tsv"
RECENT_USAGE="$SCRIPT_DIR/recent_usage.py"
OS=''
SINCE='7d'
UTILS_PATH=${HOME}/utils
# Generated inventories must not be written into the utils source repository.
# Set WORKSTATION_SETUP_OUTPUT_DIR when the report should be written elsewhere.
OUTPUT_DIR=${WORKSTATION_SETUP_OUTPUT_DIR:-${HOME}/.workstation-setup/inventory}

usage_error() {
  ws_die 'invalid snapshot arguments'
  exit 2
}

while [ "$#" -gt 0 ]; do
  case $1 in
    --os|--since|--utils-path|--output-dir)
      [ "$#" -ge 2 ] || usage_error
      case $1 in
        --os) OS=$2 ;;
        --since) SINCE=$2 ;;
        --utils-path) UTILS_PATH=$2 ;;
        --output-dir) OUTPUT_DIR=$2 ;;
      esac
      shift 2
      ;;
    *) usage_error ;;
  esac
done

case $OS in macos|linux) ;; *) usage_error ;; esac
case $SINCE in *d) DAYS=${SINCE%d} ;; *) usage_error ;; esac
case $DAYS in ''|0|*[!0-9]*) usage_error ;; esac
case ${SNAPSHOT_NOW_EPOCH:-} in *[!0-9]*) usage_error ;; esac
NOW_EPOCH=${SNAPSHOT_NOW_EPOCH:-$(date +%s)}
START_EPOCH=$((NOW_EPOCH - DAYS * 86400))
ws_command_exists python3 || {
  ws_die 'python3 is required for snapshot safety'
  exit 1
}
canonicalize_path() {
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null
}
OUTPUT_DIR=$(canonicalize_path "$OUTPUT_DIR") || usage_error
UTILS_CANONICAL=$(canonicalize_path "$UTILS_PATH") || usage_error
WS_HOME_CANONICAL=$(canonicalize_path "$HOME") || usage_error
case $OUTPUT_DIR in
  "$UTILS_CANONICAL"|"$UTILS_CANONICAL"/*)
    ws_die 'snapshot output cannot modify the utils source'
    exit 2
    ;;
esac
ws_output_path_is_safe "$OUTPUT_DIR" || {
  ws_die 'unsafe snapshot output directory'
  exit 2
}
[ -r "$CATALOG" ] && [ -r "$CONFIG_SOURCES" ] && [ -r "$RECENT_USAGE" ] || {
  ws_die 'snapshot metadata is unavailable'
  exit 1
}

mkdir -p "$OUTPUT_DIR" || {
  ws_die 'cannot create snapshot output directory'
  exit 1
}
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/workstation-snapshot.XXXXXX") || exit 1
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

APPS="$TMP_ROOT/apps.tsv"
KNOWN_APPS="$TMP_ROOT/known-apps.tsv"
PACKAGES="$TMP_ROOT/packages.tsv"
RUNTIMES="$TMP_ROOT/runtimes.tsv"
CONFIG_STATE="$TMP_ROOT/config.tsv"
USAGE_RAW="$TMP_ROOT/usage.tsv"
ALIASES="$TMP_ROOT/aliases.tsv"
: >"$APPS"
: >"$KNOWN_APPS"
: >"$PACKAGES"
: >"$RUNTIMES"
: >"$CONFIG_STATE"
: >"$USAGE_RAW"
: >"$ALIASES"

append_app() {
  local name=$1
  ws_safe_tsv_field "$name" || return
  printf '%s\n' "$name" >>"$APPS"
}

append_macos_app_path() {
  local path=$1 name metadata_name
  name=${path##*/}
  name=${name%.app}
  if ws_command_exists mdls; then
    metadata_name=$(mdls -raw -name kMDItemDisplayName "$path" 2>/dev/null || true)
    case $metadata_name in ''|'(null)') ;; *) name=$metadata_name ;; esac
  fi
  append_app "$name"
}

collect_macos_apps() {
  local path app relative
  if ws_command_exists mdfind; then
    while IFS= read -r path; do
      case $path in
        /Applications/*.app) relative=${path#/Applications/} ;;
        "$HOME"/Applications/*.app) relative=${path#"$HOME"/Applications/} ;;
        *) continue ;;
      esac
      case $relative in */*) continue ;; esac
      append_macos_app_path "$path"
    done <<EOF
$(mdfind "kMDItemContentType == 'com.apple.application-bundle'" 2>/dev/null || true)
EOF
  fi
  for app in /Applications/*.app "$HOME"/Applications/*.app; do
    [ -e "$app" ] || continue
    append_macos_app_path "$app"
  done
}

collect_linux_apps() {
  local directory desktop line name
  for directory in /usr/share/applications "$HOME/.local/share/applications"; do
    [ -d "$directory" ] || continue
    for desktop in "$directory"/*.desktop; do
      [ -r "$desktop" ] || continue
      name=''
      while IFS= read -r line; do
        case $line in Name=*) name=${line#Name=}; break ;; esac
      done <"$desktop"
      [ -n "$name" ] && append_app "$name"
    done
  done
}

collect_package_line() {
  local kind=$1 line=$2 name version
  name=${line%%[[:space:]]*}
  [ "$name" != "$line" ] || version=''
  version=${line#"$name"}
  version=${version#${version%%[![:space:]]*}}
  ws_safe_package_name "$name" || return
  version=$(ws_sanitize_version_line "$version")
  printf '%s\t%s\t%s\n' "$kind" "$name" "$version" >>"$PACKAGES"
}

collect_packages() {
  local line name version rest go_bin gopath binary dpkg_output=''
  if [ "$OS" = macos ] && ws_command_exists brew; then
    while IFS= read -r line; do
      [ -n "$line" ] && collect_package_line formula "$line"
    done <<EOF
$(brew list --formula --versions 2>/dev/null || true)
EOF
    while IFS= read -r line; do
      [ -n "$line" ] && collect_package_line cask "$line"
    done <<EOF
$(brew list --cask --versions 2>/dev/null || true)
EOF
  elif [ "$OS" = linux ]; then
    if ws_command_exists dpkg-query; then
      dpkg_output=$(dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null || true)
    fi
    if [ -n "$dpkg_output" ]; then
      while IFS=$'\t' read -r name version; do
        ws_safe_package_name "$name" || continue
        version=$(ws_sanitize_version_line "$version")
        printf 'apt\t%s\t%s\n' "$name" "$version" >>"$PACKAGES"
      done <<EOF
$dpkg_output
EOF
    elif ws_command_exists apt; then
      while IFS= read -r line; do
        case $line in ''|'Listing...'*) continue ;; esac
        name=${line%%/*}
        rest=${line#* }
        version=${rest%% *}
        ws_safe_package_name "$name" || continue
        version=$(ws_sanitize_version_line "$version")
        printf 'apt\t%s\t%s\n' "$name" "$version" >>"$PACKAGES"
      done <<EOF
$(apt list --installed 2>/dev/null || true)
EOF
    fi
  fi
  if ws_command_exists pipx; then
    while IFS= read -r line; do
      [ -n "$line" ] && collect_package_line pipx "$line"
    done <<EOF
$(pipx list --short 2>/dev/null || true)
EOF
  fi
  if ws_command_exists cargo; then
    while IFS= read -r line; do
      case $line in [![:space:]]*' v'*) collect_package_line cargo "$line" ;; esac
    done <<EOF
$(cargo install --list 2>/dev/null || true)
EOF
  fi
  if ws_command_exists npm && ws_command_exists python3; then
    npm list -g --depth=0 --json 2>/dev/null >"$TMP_ROOT/npm.json" || true
    python3 - "$TMP_ROOT/npm.json" >>"$PACKAGES" 2>/dev/null <<'PY'
import json, re, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(0)
for name, meta in sorted(data.get("dependencies", {}).items()):
    if re.fullmatch(r"[A-Za-z0-9@._+/-]+", name):
        version = str(meta.get("version", ""))
        version = "".join(c for c in version if c.isalnum() or c in ".+-_")
        print(f"npm\t{name}\t{version}")
PY
  fi
  go_bin=${GOBIN:-}
  if [ -z "$go_bin" ] && ws_command_exists go; then
    go_bin=$(go env GOBIN 2>/dev/null || true)
    if [ -z "$go_bin" ]; then
      gopath=$(go env GOPATH 2>/dev/null || true)
      [ -n "$gopath" ] && go_bin=$gopath/bin
    fi
  fi
  if [ -n "$go_bin" ] && [ -d "$go_bin" ]; then
    for binary in "$go_bin"/*; do
      [ -f "$binary" ] && [ -x "$binary" ] || continue
      name=${binary##*/}
      ws_safe_package_name "$name" || continue
      printf 'go-bin\t%s\t%s\n' "$name" '' >>"$PACKAGES"
    done
  fi
}

collect_version() {
  local id=$1 output
  shift
  output=$("$@" 2>&1) || true
  output=${output%%$'\n'*}
  output=$(ws_sanitize_version_line "$output")
  [ -n "$output" ] && printf '%s\t%s\n' "$id" "$output" >>"$RUNTIMES"
}

collect_runtimes() {
  ws_command_exists java && collect_version java java -version
  ws_command_exists jenv && collect_version jenv jenv --version
  ws_command_exists go && collect_version go go version
  ws_command_exists python3 && collect_version python python3 --version
  ws_command_exists node && collect_version node node --version
  ws_command_exists bun && collect_version bun bun --version
  ws_command_exists adb && collect_version android adb version
  [ "$OS" = macos ] && ws_command_exists xcodebuild && \
    collect_version xcode xcodebuild -version
}

file_has_line() {
  local file=$1 wanted=$2 line
  [ -r "$file" ] || return 1
  while IFS= read -r line; do
    [ "$line" = "$wanted" ] && return 0
  done <"$file"
  return 1
}

runtime_value() {
  local wanted=$1 id value
  while IFS=$'\t' read -r id value; do
    [ "$id" = "$wanted" ] && { printf '%s' "$value"; return 0; }
  done <"$RUNTIMES"
  return 1
}


runtime_summary() {
  local catalog_id=$1 runtime_id value result='' ids
  case $catalog_id in
    java) ids='java jenv' ;;
    node) ids='node bun' ;;
    *) ids=$catalog_id ;;
  esac
  for runtime_id in $ids; do
    value=$(runtime_value "$runtime_id" || true)
    [ -n "$value" ] || continue
    [ -z "$result" ] || result="$result; "
    result="$result$runtime_id=$value"
  done
  [ -n "$result" ] && printf '%s' "$result"
}

catalog_aliases() {
  local line fields id display category commands app profiles candidate old_ifs
  while IFS= read -r line; do
    case $line in id$'\t'*) continue ;; esac
    fields=$(ws_tsv_to_unit_separator "$line")
    IFS=$'\034' read -r id display category commands app _ profiles <<EOF
$fields
EOF
    [ -n "$app" ] && printf '%s\n' "$app" >>"$KNOWN_APPS"
    old_ifs=$IFS
    IFS=':'
    for candidate in $commands; do
      [ -n "$candidate" ] && printf '%s\t%s\t%s\t%s\n' \
        "$candidate" "$display" "$category" "$profiles" >>"$ALIASES"
    done
    IFS=$old_ifs
  done <"$CATALOG"
  LC_ALL=C sort -u "$KNOWN_APPS" -o "$KNOWN_APPS"
}

collect_config_state() {
  local revision='unavailable' line fields id source destination mode profile
  local path digest status detail module module_path module_digest
  local source_canonical module_canonical
  if [ -d "$UTILS_PATH/.git" ] && ws_command_exists git; then
    revision=$(git -C "$UTILS_PATH" rev-parse --verify HEAD 2>/dev/null || true)
    case $revision in *[!0-9a-fA-F]*|'') revision='unavailable' ;; esac
  fi
  printf 'utils-revision\tpresent\t%s\tsource\n' "$revision" >>"$CONFIG_STATE"
  while IFS= read -r line; do
    case $line in id$'\t'*) continue ;; esac
    fields=$(ws_tsv_to_unit_separator "$line")
    IFS=$'\034' read -r id source destination mode profile <<EOF
$fields
EOF
    ws_tokens_apply_to_os "$profile" "$OS" || continue
    status=missing
    detail='-'
    source_canonical=''
    case $mode in
      local)
        if [ -L "$HOME/$destination" ]; then
          status=unsafe
        elif [ -f "$HOME/$destination" ]; then
          status=local-present
        elif [ -e "$HOME/$destination" ]; then
          status=unsafe
        else
          status=local-missing
        fi
        ;;
      manual-review)
        status=manual-review
        ;;
      symlink)
        if [ -z "$source" ] || ws_forbidden_relative_path "$source"; then
          status=excluded-sensitive
        else
          path=$UTILS_PATH/$source
          if [ -f "$path" ] && [ ! -L "$path" ]; then
            digest=$(ws_sha256_file "$path" || true)
            if [ -n "$digest" ]; then status=present; detail=$digest; fi
          elif [ -d "$path" ] && [ ! -L "$path" ]; then
            source_canonical=$(canonicalize_path "$path" || true)
            case $source_canonical in
              "$UTILS_CANONICAL"/*)
                status=directory-present
                detail=$revision
                ;;
              *) status=unsafe ;;
            esac
          elif [ -e "$path" ] || [ -L "$path" ]; then
            status=unsafe
          fi
        fi
        ;;
      *) status=manual-review ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$detail" "$profile" \
      >>"$CONFIG_STATE"
    if [ "$id" = hammerspoon ] && [ "$status" = directory-present ] && \
       [ -n "$source_canonical" ]; then
      for module_path in \
        "$UTILS_PATH/$source/init.lua" \
        "$UTILS_PATH/$source"/keyboard/*.lua \
        "$UTILS_PATH/$source"/winlayout/*.lua \
        "$UTILS_PATH/$source"/Spoons/*.spoon/init.lua; do
        [ -f "$module_path" ] && [ ! -L "$module_path" ] || continue
        module_canonical=$(canonicalize_path "$module_path" || true)
        case $module_canonical in "$source_canonical"/*) ;; *) continue ;; esac
        module=${module_path#"$UTILS_PATH/$source/"}
        ws_safe_tsv_field "$module" || continue
        module_digest=$(ws_sha256_file "$module_path" || true)
        [ -n "$module_digest" ] || continue
        printf 'hammerspoon:%s\tpresent\t%s\t%s\n' \
          "$module" "$module_digest" "$profile" >>"$CONFIG_STATE"
      done
    fi
  done <"$CONFIG_SOURCES"
}

category_heading() {
  case $1 in
    ide) printf 'Applications and IDEs' ;;
    developer) printf 'CLI and shells' ;;
    terminal|session|window-utility) printf 'Terminal and session utilities' ;;
    ai) printf 'AI tools' ;;
    menu-bar-utility) printf 'Menu-bar utilities' ;;
    runtime|mobile) printf 'Language and mobile stacks' ;;
    *) printf 'Developer and cloud tools' ;;
  esac
}

app_detected() {
  local candidate=$1 line
  [ -n "$candidate" ] || return 1
  while IFS= read -r line; do [ "$line" = "$candidate" ] && return 0; done <"$APPS"
  return 1
}

command_detected() {
  local candidates=$1 candidate old_ifs=$IFS
  IFS=':'
  for candidate in $candidates; do
    if [ -n "$candidate" ] && ws_command_exists "$candidate"; then
      IFS=$old_ifs
      printf '%s' "$candidate"
      return 0
    fi
  done
  IFS=$old_ifs
  return 1
}

render_catalog_rows() {
  local line fields id display category commands app roots profiles heading status evidence command root runtime
  while IFS= read -r line; do
    case $line in id$'\t'*) continue ;; esac
    fields=$(ws_tsv_to_unit_separator "$line")
    IFS=$'\034' read -r id display category commands app roots profiles <<EOF
$fields
EOF
    # A platform-prefixed config root that does not resolve on the current OS
    # suppresses only menu-bar utility rows. Other catalog rows still render so
    # command/app discovery (for example Xcode on Linux) remains unchanged.
    # A bare root (Hammerspoon) or an empty roots field still resolves/applies
    # on every OS and is never skipped.
    root=''
    if [ -n "$roots" ]; then
      root=$(ws_resolve_config_root "$roots" "$OS" || true)
      if [ -z "$root" ] && [ "$category" = menu-bar-utility ]; then
        continue
      fi
    fi
    heading=$(category_heading "$category")
    status='not detected'
    evidence='none'
    command=$(command_detected "$commands" || true)
    if [ -n "$command" ]; then
      status=detected
      evidence="command:$command"
    elif app_detected "$app"; then
      status=detected
      evidence="application:$app"
    else
      if [ -n "$root" ]; then
        if ws_forbidden_relative_path "$root"; then
          status='excluded-sensitive'
          evidence='presence not inspected'
        elif [ -e "$HOME/$root" ]; then
          status=detected
          evidence="config:\$HOME/$root"
        fi
      fi
    fi
    runtime=$(runtime_summary "$id" || true)
    [ -n "$runtime" ] && evidence="$evidence; version:$runtime"
    printf '| %s | %s | %s | %s |\n' \
      "$(ws_markdown_escape "$display")" \
      "$(ws_markdown_escape "$status")" \
      "$(ws_markdown_escape "$evidence")" \
      "$(ws_markdown_escape "$profiles")" \
      >>"$TMP_ROOT/$heading.rows"
  done <"$CATALOG"
}

collect_usage() {
  local history=${HISTFILE:-$HOME/.zsh_history}
  if [ -r "$history" ]; then
    python3 "$RECENT_USAGE" --history "$history" \
      --start-epoch "$START_EPOCH" --end-epoch "$NOW_EPOCH" \
      >"$USAGE_RAW" 2>/dev/null || : >"$USAGE_RAW"
  fi
}

lookup_alias() {
  local wanted=$1 name display category profiles
  while IFS=$'\t' read -r name display category profiles; do
    [ "$name" = "$wanted" ] && {
      printf '%s\t%s\t%s' "$display" "$category" "$profiles"
      return 0
    }
  done <"$ALIASES"
  return 1
}

render_recent_usage() {
  local output=$1 date name count mapping display category profiles
  local previous_date='' previous_display='' previous_category=''
  local previous_profiles='' total=0
  local classified="$TMP_ROOT/recent-classified.tsv"
  local sorted_classified="$TMP_ROOT/recent-classified-sorted.tsv"
  : >"$classified"
  : >"$TMP_ROOT/recent-unclassified.rows"
  while IFS=$'\t' read -r date name count; do
    [ -n "$date" ] && ws_safe_token "$name" || continue
    case $count in ''|*[!0-9]*) continue ;; esac
    mapping=$(lookup_alias "$name" || true)
    if [ -n "$mapping" ] && [ "$name" != unclassified ]; then
      display=${mapping%%$'\t'*}
      mapping=${mapping#*$'\t'}
      category=${mapping%%$'\t'*}
      profiles=${mapping#*$'\t'}
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "$date" "$display" "$category" "$profiles" "$count" >>"$classified"
    else
      printf '| %s | %s | observed-only | %s |\n' "$date" \
        "$(ws_markdown_escape "$name")" "$count" \
        >>"$TMP_ROOT/recent-unclassified.rows"
    fi
  done <"$USAGE_RAW"
  LC_ALL=C sort "$classified" >"$sorted_classified"
  {
    printf '# Recent Tool Usage\n\n'
    printf '**Window:** last %s days ending %s UTC\n\n' "$DAYS" "$GENERATED_DATE"
    printf 'Only normalized executable names, UTC dates, categories, and counts are retained.\n\n'
    printf '## Classified\n\n| Date | Tool | Category | Desired profile | Count |\n| --- | --- | --- | --- | ---: |\n'
  } >"$output"
  while IFS=$'\t' read -r date display category profiles count; do
    if [ "$date" = "$previous_date" ] && \
       [ "$display" = "$previous_display" ] && \
       [ "$category" = "$previous_category" ] && \
       [ "$profiles" = "$previous_profiles" ]; then
      total=$((total + count))
      continue
    fi
    if [ -n "$previous_date" ]; then
      printf '| %s | %s | %s | %s | %s |\n' "$previous_date" \
        "$(ws_markdown_escape "$previous_display")" \
        "$(ws_markdown_escape "$previous_category")" \
        "$(ws_markdown_escape "$previous_profiles")" "$total" >>"$output"
    fi
    previous_date=$date
    previous_display=$display
    previous_category=$category
    previous_profiles=$profiles
    total=$count
  done <"$sorted_classified"
  if [ -n "$previous_date" ]; then
    printf '| %s | %s | %s | %s | %s |\n' "$previous_date" \
      "$(ws_markdown_escape "$previous_display")" \
      "$(ws_markdown_escape "$previous_category")" \
      "$(ws_markdown_escape "$previous_profiles")" "$total" >>"$output"
  fi
  {
    printf '\n## Unclassified\n\n| Date | Normalized name | Desired profile | Count |\n| --- | --- | --- | ---: |\n'
    if [ -s "$TMP_ROOT/recent-unclassified.rows" ]; then
      cat "$TMP_ROOT/recent-unclassified.rows"
    elif [ ! -s "$USAGE_RAW" ]; then
      printf '| %s | unavailable | observed-only | 0 |\n' "$GENERATED_DATE"
    else
      printf '| %s | none | observed-only | 0 |\n' "$GENERATED_DATE"
    fi
  } >>"$output"
}

catalog_id_profile() {
  local wanted=$1 line fields id profiles
  while IFS= read -r line; do
    case $line in id$'\t'*) continue ;; esac
    fields=$(ws_tsv_to_unit_separator "$line")
    IFS=$'\034' read -r id _ _ _ _ _ profiles <<EOF
$fields
EOF
    if [ "$id" = "$wanted" ]; then
      printf '%s' "$profiles"
      return 0
    fi
  done <"$CATALOG"
  return 1
}


package_profile() {
  local mapping profiles
  # Explicit package names are sourced from the curated platform manifests.
  case $1 in
    git|tmux|neovim|vim|curl|python3|python3-pip|nodejs|npm|golang-go|\
    openjdk-21-jdk|go|python|python@*|node|bun|jenv|\
    intellij-idea|visual-studio-code|cursor|ghostty|hammerspoon)
      printf 'base'
      return
      ;;
    gh|kubectl|bazelisk)
      printf 'work'
      return
      ;;
    android-studio|android-platform-tools)
      printf 'mobile'
      return
      ;;
    @earendil-works/pi-coding-agent)
      printf 'base'
      return
      ;;
  esac
  # A package named like a catalog/common-manifest ID uses that direct profile.
  profiles=$(catalog_id_profile "$1" || true)
  if [ -n "$profiles" ]; then
    printf '%s' "$profiles"
    return
  fi
  # Portable packages named like command candidates inherit catalog profiles.
  mapping=$(lookup_alias "$1" || true)
  if [ -n "$mapping" ]; then
    profiles=${mapping##*$'\t'}
    printf '%s' "$profiles"
  else
    printf 'observed-only'
  fi
}


render_packages() {
  local output=$1 kind name version profile
  printf '| Source | Package | Version | Desired profile |\n| --- | --- | --- | --- |\n' >>"$output"
  if [ ! -s "$PACKAGES" ]; then
    printf '| unavailable | none | - | observed-only |\n' >>"$output"
    return
  fi
  LC_ALL=C sort -u "$PACKAGES" | while IFS=$'\t' read -r kind name version; do
    profile=$(package_profile "$name")
    printf '| %s | %s | %s | %s |\n' "$kind" "$name" \
      "$(ws_markdown_escape "${version:--}")" "$profile"
  done >>"$output"
}

render_config() {
  local output=$1 id status detail profile
  printf '| Source | Status | Safe fingerprint | Desired profile |\n| --- | --- | --- | --- |\n' >>"$output"
  while IFS=$'\t' read -r id status detail profile; do
    printf '| %s | %s | %s | %s |\n' \
      "$(ws_markdown_escape "$id")" \
      "$(ws_markdown_escape "$status")" \
      "$(ws_markdown_escape "${detail:--}")" \
      "$(ws_markdown_escape "${profile:-observed-only}")"
  done <"$CONFIG_STATE" >>"$output"
}

render_unclassified_apps() {
  local output=$1 app found=0
  printf '| Source | Name | Desired profile |\n| --- | --- | --- |\n' >>"$output"
  while IFS= read -r app; do
    file_has_line "$KNOWN_APPS" "$app" && continue
    printf '| application | %s | observed-only |\n' \
      "$(ws_markdown_escape "$app")" >>"$output"
    found=1
  done <"$APPS"
  [ "$found" -eq 1 ] || printf '| application | none | observed-only |\n' >>"$output"
  printf '\nUnknown normalized commands are retained in `recent-usage.md`.\n' >>"$output"
}


usage_row_count() {
  local count=0 _date _name _value
  while IFS=$'\t' read -r _date _name _value; do
    [ -n "$_date" ] && count=$((count + 1))
  done <"$USAGE_RAW"
  printf '%s' "$count"
}


[ "$OS" = macos ] && collect_macos_apps || collect_linux_apps
LC_ALL=C sort -u "$APPS" -o "$APPS"
collect_packages
collect_runtimes
catalog_aliases
collect_config_state
collect_usage
render_catalog_rows

GENERATED_DATE=$(python3 - "$NOW_EPOCH" <<'PY'
import datetime, sys
print(datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc).strftime("%Y-%m-%d"))
PY
) || GENERATED_DATE='unknown'

CURRENT_TMP="$TMP_ROOT/current-machine.md"
{
  printf '# Current Workstation Inventory\n\n'
  printf '**Generated:** %s UTC  \n**Platform:** %s\n\n' "$GENERATED_DATE" "$OS"
  printf 'Observed state only. Desired setup remains curated in `manifests/`.\n'
} >"$CURRENT_TMP"
for heading in 'Applications and IDEs' 'CLI and shells' \
  'Terminal and session utilities' 'AI tools' 'Menu-bar utilities' \
  'Developer and cloud tools' 'Language and mobile stacks'; do
  # The Menu-bar utilities section is macOS-only: the catalog rows it draws
  # from are skipped on non-macOS platforms (platform-prefixed config roots),
  # so an empty rows file means the section must not render at all. The other
  # sections always emit a heading with a placeholder row when nothing was
  # detected, preserving the existing inventory contract.
  if [ "$heading" = 'Menu-bar utilities' ] && [ ! -s "$TMP_ROOT/$heading.rows" ]; then
    continue
  fi
  printf '\n## %s\n\n| Tool | Status | Evidence | Desired profile |\n| --- | --- | --- | --- |\n' \
    "$heading" >>"$CURRENT_TMP"
  if [ -s "$TMP_ROOT/$heading.rows" ]; then
    cat "$TMP_ROOT/$heading.rows" >>"$CURRENT_TMP"
  else
    printf '| none | not detected | none | observed-only |\n' >>"$CURRENT_TMP"
  fi
done
printf '\n## Package manager inventory\n\n' >>"$CURRENT_TMP"
render_packages "$CURRENT_TMP"
printf '\n## Configuration sources\n\n' >>"$CURRENT_TMP"
render_config "$CURRENT_TMP"
printf '\n## Recent usage\n\n| Status | Normalized date/name rows | Detail |\n| --- | ---: | --- |\n' >>"$CURRENT_TMP"
if [ -s "$USAGE_RAW" ]; then
  printf '| available | %s | See `recent-usage.md`; no raw commands retained. |\n' \
    "$(usage_row_count)" >>"$CURRENT_TMP"
else
  printf '| unavailable | 0 | Other discovery sources completed. |\n' >>"$CURRENT_TMP"
fi
printf '\n## Unclassified\n\n' >>"$CURRENT_TMP"
render_unclassified_apps "$CURRENT_TMP"

RECENT_TMP="$TMP_ROOT/recent-usage.md"
render_recent_usage "$RECENT_TMP"

publish_inventory() {
  local current_source=$1 recent_source=$2
  local current_final="$OUTPUT_DIR/current-machine.md"
  local recent_final="$OUTPUT_DIR/recent-usage.md"
  local current_stage="$OUTPUT_DIR/.current-machine.md.tmp.$$"
  local recent_stage="$OUTPUT_DIR/.recent-usage.md.tmp.$$"
  local current_backup="$OUTPUT_DIR/.current-machine.md.backup.$$"
  local recent_backup="$OUTPUT_DIR/.recent-usage.md.backup.$$"
  local had_current=0 had_recent=0

  mv "$current_source" "$current_stage" 2>/dev/null || return 1
  if ! mv "$recent_source" "$recent_stage" 2>/dev/null; then
    rm -f "$current_stage"
    return 1
  fi
  if [ -e "$current_final" ] || [ -L "$current_final" ]; then
    if ! mv "$current_final" "$current_backup" 2>/dev/null; then
      rm -f "$current_stage" "$recent_stage"
      return 1
    fi
    had_current=1
  fi
  if [ -e "$recent_final" ] || [ -L "$recent_final" ]; then
    if ! mv "$recent_final" "$recent_backup" 2>/dev/null; then
      [ "$had_current" -eq 1 ] && mv "$current_backup" "$current_final" 2>/dev/null
      rm -f "$current_stage" "$recent_stage"
      return 1
    fi
    had_recent=1
  fi
  if ! mv "$current_stage" "$current_final" 2>/dev/null; then
    [ "$had_current" -eq 1 ] && mv "$current_backup" "$current_final" 2>/dev/null
    [ "$had_recent" -eq 1 ] && mv "$recent_backup" "$recent_final" 2>/dev/null
    rm -f "$current_stage" "$recent_stage"
    return 1
  fi
  if ! mv "$recent_stage" "$recent_final" 2>/dev/null; then
    rm -f "$current_final" "$current_stage" "$recent_stage"
    [ "$had_current" -eq 1 ] && mv "$current_backup" "$current_final" 2>/dev/null
    [ "$had_recent" -eq 1 ] && mv "$recent_backup" "$recent_final" 2>/dev/null
    return 1
  fi
  rm -f "$current_backup" "$recent_backup"
  return 0
}

if ! publish_inventory "$CURRENT_TMP" "$RECENT_TMP"; then
  ws_die 'cannot publish snapshot output'
  exit 1
fi
printf 'snapshot written: %s/current-machine.md, %s/recent-usage.md\n' \
  "$OUTPUT_DIR" "$OUTPUT_DIR"

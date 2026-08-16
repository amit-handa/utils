# Oh My Zsh
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export ZSH="$HOME/.oh-my-zsh"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
setopt no_case_glob
export ZSH_THEME="robbyrussell"
plugins=(dnf fzf git zsh-autosuggestions zsh-completions)

source "$ZSH/oh-my-zsh.sh"

# Keep PATH entries unique while preserving the existing shell path.
typeset -U path fpath
path=(
  /opt/homebrew/bin
  /usr/local/bin
  "$HOME/tools/bin"
  "$HOME/.local/bin"
  /opt/local/bin
  /opt/local/sbin
  $path
)
fpath=("$ZSH/functions" $fpath)

# Preferred editor for local and remote sessions.
if [[ -n ${SSH_CONNECTION:-} ]]; then
  export EDITOR=vim
else
  export EDITOR=nvim
fi
export VISUAL=cursor
alias vi=nvim

if [[ -r "$HOME/.fzf.zsh" ]]; then
  source "$HOME/.fzf.zsh"
fi

if [[ -x /usr/libexec/java_home ]]; then
  JAVA_HOME=$(/usr/libexec/java_home -v 17 2>/dev/null)
  [[ -n "$JAVA_HOME" ]] && export JAVA_HOME
fi
if (( $+commands[brew] )); then
  GOROOT="$(brew --prefix go 2>/dev/null)/libexec"
  [[ -d "$GOROOT" ]] && export GOROOT
  gradle_root="$(brew --prefix gradle 2>/dev/null)"
  [[ -d "$gradle_root" ]] && export GRADLE_HOME="$gradle_root"
fi
export GOPATH="$HOME/go"
[[ -n ${GOROOT:-} ]] && path=("$GOROOT/bin" $path)

alias yaml2json="ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load(ARGF))'"

if [[ -r "$HOME/.opam/opam-init/init.zsh" ]]; then
  source "$HOME/.opam/opam-init/init.zsh" >/dev/null 2>&1
fi

SSH_ENV="$HOME/.ssh/environment"

_start_ssh_agent() {
  [[ -d "${SSH_ENV:h}" ]] || return 1
  ssh-agent -s | sed 's/^echo/#echo/' >| "$SSH_ENV" || return 1
  chmod 600 "$SSH_ENV" || return 1
  source "$SSH_ENV" >/dev/null 2>&1 || return 1
  ssh-add
}

if (( $+commands[ssh-agent] && $+commands[ssh-add] )); then
  if [[ -r "$SSH_ENV" ]]; then
    source "$SSH_ENV" >/dev/null 2>&1
  fi
  if [[ -z ${SSH_AGENT_PID:-} ]] ||
     ! kill -0 "$SSH_AGENT_PID" >/dev/null 2>&1; then
    _start_ssh_agent
  fi
fi

bindkey -M emacs '^[f' vi-forward-blank-word-end
if [[ "$TERMINAL_EMULATOR" == "JetBrains-JediTerm" ]]; then
  bindkey "∫" backward-word
  bindkey "ƒ" forward-word
  bindkey "∂" delete-word
fi
bindkey -M emacs '^[[1;3D' backward-word
bindkey -M emacs '^[[1;3C' forward-word

if [[ -d "$HOME/.jenv/bin" ]]; then
  path=("$HOME/.jenv/bin" $path)
fi
if (( $+commands[jenv] )); then
  eval "$(jenv init -)"
  jenv enable-plugin export
fi
if (( $+commands[rbenv] )); then
  eval "$(rbenv init - zsh)"
fi
if [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]]; then
  export NVM_DIR="$HOME/.nvm"
  source "/opt/homebrew/opt/nvm/nvm.sh"
  [[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ]] &&
    source "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
fi
[[ -d "$HOME/.maestro/bin" ]] && path=("$HOME/.maestro/bin" $path)
if (( $+commands[pyenv] )); then
  path=("$(pyenv root)/shims" $path)
fi

# >>> conda initialize >>>
if [[ -x "$HOME/miniconda3/bin/conda" ]]; then
  __conda_setup="$("$HOME/miniconda3/bin/conda" "shell.zsh" "hook" 2>/dev/null)"
  if [[ $? -eq 0 ]]; then
    eval "$__conda_setup"
  elif [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
  else
    path=("$HOME/miniconda3/bin" $path)
  fi
  unset __conda_setup
fi
# <<< conda initialize <<<


if [[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]]; then
  source "$HOME/google-cloud-sdk/path.zsh.inc"
fi
if [[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]]; then
  source "$HOME/google-cloud-sdk/completion.zsh.inc"
fi

TRAPWINCH() { zle && zle reset-prompt }

if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

autoload -Uz add-zsh-hook
zmodload zsh/datetime 2>/dev/null

# Notify with sound when a foreground command takes >=10s.
_notify_long_preexec() { _NOTIFY_CMD_START=$EPOCHSECONDS }
_notify_long_precmd() {
  if [[ -n ${_NOTIFY_CMD_START:-} ]]; then
    local elapsed=$(( EPOCHSECONDS - _NOTIFY_CMD_START ))
    (( elapsed >= 10 )) && afplay /System/Library/Sounds/Glass.aiff &>/dev/null &!
    unset _NOTIFY_CMD_START
  fi
}
add-zsh-hook preexec _notify_long_preexec
add-zsh-hook precmd _notify_long_precmd

export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
path=(
  "$ANDROID_HOME/platform-tools"
  "$ANDROID_HOME/emulator"
  "$ANDROID_HOME/cmdline-tools/latest/bin"
  $path
)

# Inject a fresh GitHub token when launching OMP extensions.
omp() { GITHUB_TOKEN="$(gh auth token 2>/dev/null)" command omp "$@"; }


# Load work-only settings when the work profile is linked.
if [[ -r "$HOME/.zshrc.work" ]] &&
   [[ -z ${WORKSTATION_PROFILE:-} || "$WORKSTATION_PROFILE" == work ]]; then
  source "$HOME/.zshrc.work"
fi

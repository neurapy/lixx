# zoxide.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# fzf integration. Debian/Ubuntu packages install these under /usr/share/doc.
if (( $+commands[fzf] && ${ZSH_HAS_TERMINAL:-0} )); then
  [[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
  [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
  [[ -r /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
  [[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
fi

# micromamba. Prefer the profile script to avoid a second unmanaged compinit.
if [[ -r "$MAMBA_ROOT_PREFIX/etc/profile.d/mamba.sh" ]]; then
  source "$MAMBA_ROOT_PREFIX/etc/profile.d/mamba.sh"
elif [[ -x "$MAMBA_EXE" ]]; then
  if ! command -v compinit >/dev/null && [[ -n $ZSH_COMPDUMP ]]; then
    autoload -Uz compinit
    compinit -u -d "$ZSH_COMPDUMP"
  fi

  __mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2>/dev/null)"
  if [[ $? -eq 0 ]]; then
    eval "$__mamba_setup"
  else
    alias micromamba="$MAMBA_EXE"
  fi
  unset __mamba_setup
fi

# nvm is expensive to source. Load it on first Node-related command.
__zsh_load_nvm() {
  [[ -n ${__ZSH_NVM_LOADED:-} ]] && return 0
  [[ -s "$NVM_DIR/nvm.sh" ]] || return 1

  source "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
  typeset -g __ZSH_NVM_LOADED=1
}

__zsh_unset_nvm_lazy_wrappers() {
  unfunction nvm node npm npx corepack pnpm yarn yarnpkg 2>/dev/null || true
}

__zsh_lazy_nvm() {
  local cmd="$1"
  shift
  __zsh_unset_nvm_lazy_wrappers
  __zsh_load_nvm || return
  "$cmd" "$@"
}

__zsh_lazy_nvm_command() {
  local cmd="$1"
  shift
  __zsh_unset_nvm_lazy_wrappers
  __zsh_load_nvm || true
  command "$cmd" "$@"
}

nvm() { __zsh_lazy_nvm nvm "$@"; }
node() { __zsh_lazy_nvm_command node "$@"; }
npm() { __zsh_lazy_nvm_command npm "$@"; }
npx() { __zsh_lazy_nvm_command npx "$@"; }
corepack() { __zsh_lazy_nvm_command corepack "$@"; }
pnpm() { __zsh_lazy_nvm_command pnpm "$@"; }
yarn() { __zsh_lazy_nvm_command yarn "$@"; }
yarnpkg() { __zsh_lazy_nvm_command yarnpkg "$@"; }

[[ -o interactive ]] || return
typeset -g ZSH_CONFIG_DIR="${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}"
typeset -g ZSH_HAS_TERMINAL=0
[[ -t 0 || -t 1 || -t 2 ]] && ZSH_HAS_TERMINAL=1

if [[ -z $ZSH ]]; then
    if [[ -r "$ZSH_CONFIG_DIR/oh-my-zsh/oh-my-zsh.sh" ]]; then
        ZSH="$ZSH_CONFIG_DIR/oh-my-zsh"
    else
        ZSH="${XDG_DATA_HOME:-$HOME/.local/share}/lixx-system/zsh/oh-my-zsh"
    fi
fi
typeset -g ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh}"
instant_prompt="${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
if (( ZSH_HAS_TERMINAL )) && [[ -r "$ZSH/oh-my-zsh.sh" && -r "$instant_prompt" ]]; then
    source "$instant_prompt"
fi
unset instant_prompt

# env.zsh and the function files belong to the account.
if [[ -r "$ZSH_CONFIG_DIR/env.zsh" ]]; then
    source "$ZSH_CONFIG_DIR/env.zsh"
fi
source "$ZSH_CONFIG_DIR/options.zsh"
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH_CONFIG_DIR/plugins.zsh"
else
    if (( ! $+functions[compdef] )); then
        autoload -Uz compinit
        mkdir -p -- "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
        compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
    fi
    PROMPT='%F{cyan}%~%f %# '
fi

source "$ZSH_CONFIG_DIR/tools.zsh"
for zsh_module in functions/aliases.zsh functions/functions.zsh functions/up.zsh; do
    if [[ -r "$ZSH_CONFIG_DIR/$zsh_module" ]]; then
        source "$ZSH_CONFIG_DIR/$zsh_module"
    fi
done
unset zsh_module
if (( $+functions[p10k] )) && [[ -r "$ZSH_CONFIG_DIR/.p10k.zsh" ]]; then
    source "$ZSH_CONFIG_DIR/.p10k.zsh"
fi

typeset -U path
path=("${XDG_DATA_HOME:-$HOME/.local/share}/lixx-system/bin" "$HOME/.local/bin" "${path[@]}")
if [[ -r "$HOME/.local/bin/env" ]]; then
    source "$HOME/.local/bin/env"
fi

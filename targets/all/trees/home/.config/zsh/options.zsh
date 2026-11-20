# History.
typeset -g HISTSIZE=200000
typeset -g SAVEHIST=200000
typeset -g HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p -- "${HISTFILE:h}"

setopt append_history
setopt inc_append_history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt hist_ignore_space

# Shell behavior.
setopt auto_cd
setopt extended_glob
setopt complete_in_word
setopt glob_dots
unsetopt beep

[[ -o zle ]] && bindkey -v

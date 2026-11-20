# Oh My Zsh and prompt.
zstyle ':omz:update' mode disabled
typeset -g DISABLE_AUTO_UPDATE=true

typeset -g ZSH_THEME="powerlevel10k/powerlevel10k"

typeset -U fpath
[[ -d "$ZSH/custom/plugins/zsh-completions/src" ]] && fpath=("$ZSH/custom/plugins/zsh-completions/src" $fpath)
[[ -d /usr/share/zsh/site-functions ]] && fpath=(/usr/share/zsh/site-functions $fpath)

plugins=(
  git
  sudo
  colored-man-pages
  zsh-completions
  zsh-autosuggestions
  fzf-tab
  zsh-vi-mode
  fast-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

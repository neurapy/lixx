export ZDOTDIR="${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}"
export skip_global_compinit=1
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/env/session.sh" ]]; then
    source "${XDG_CONFIG_HOME:-$HOME/.config}/env/session.sh"
fi

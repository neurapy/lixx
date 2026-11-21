# Shared user defaults for graphical sessions and interactive shells.

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"

if [ -x /usr/bin/zsh ]; then
  export SHELL=/usr/bin/zsh
fi

case ":${PATH:-}:" in
*:"$HOME/.local/bin":*) ;;
*) PATH="$HOME/.local/bin${PATH:+:$PATH}" ;;
esac

case ":${PATH:-}:" in
*:"${XDG_DATA_HOME:-$HOME/.local/share}/lixx-system/bin":*) ;;
*) PATH="${XDG_DATA_HOME:-$HOME/.local/share}/lixx-system/bin${PATH:+:$PATH}" ;;
esac

export PATH

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

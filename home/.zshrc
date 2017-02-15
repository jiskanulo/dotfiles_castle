#
# Executes commands at the start of an interactive session.
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# homeshick
if [[ -f "$HOME/.homesick/repos/homeshick/homeshick.sh" ]]; then
  source "$HOME/.homesick/repos/homeshick/homeshick.sh"

  fpath=($fpath "$HOME/.homesick/repos/homeshick/completions")
  autoload -U compinit
  compinit -u
fi

# load my own configures
source "$HOME/.zsh.d/alias" 2> /dev/null
source "$HOME/.zsh.d/completion" 2> /dev/null
source "$HOME/.zsh.d/env-zsh" 2> /dev/null

# peco
if [ $commands[peco] ]; then
  source "$HOME/.zsh.d/function/cdd" 2> /dev/null
  source "$HOME/.zsh.d/function/peco" 2> /dev/null
fi

# Homebew
if [ $commands[brew] ]; then
  # autojump
  [[ -s $(brew --prefix)/etc/profile.d/autojump.sh ]] && . $(brew --prefix)/etc/profile.d/autojump.sh
fi

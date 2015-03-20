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

  fpath=("$HOME/.homesick/repos/homeshick/completions" $fpath)
  autoload -U compinit
  compinit -u
fi

# load my own configures
source "$HOME/.zsh.d/env-git" 2> /dev/null
source "$HOME/.zsh.d/env-zsh" 2> /dev/null

if [ $commands[brew] ]; then
  source "$HOME/.zsh.d/homebrew/env-git" 2> /dev/null
  source "$HOME/.zsh.d/homebrew/function-peco" 2> /dev/null
  [[ -s $(brew --prefix)/etc/profile.d/autojump.sh ]] && . $(brew --prefix)/etc/profile.d/autojump.sh
fi

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
fi

# load my own configures
source "$HOME/.zsh.d/alias" 2> /dev/null
source "$HOME/.zsh.d/bindkey" 2> /dev/null
source "$HOME/.zsh.d/completion" 2> /dev/null
source "$HOME/.zsh.d/env-rails" 2> /dev/null
source "$HOME/.zsh.d/env-zsh" 2> /dev/null
source "$HOME/.zsh.d/stty" 2> /dev/null

# anyenv
if [ $commands[anyenv] ]; then
  eval "$(anyenv init -)"
fi

# peco
if [ $commands[peco] ]; then
  source "$HOME/.zsh.d/function/cdd" 2> /dev/null
  source "$HOME/.zsh.d/function/d" 2> /dev/null
  source "$HOME/.zsh.d/function/peco-select-history" 2> /dev/null
  if [ $commands[ghq] ]; then
    source "$HOME/.zsh.d/function/cdw" 2> /dev/null
  fi
fi

# Homebew
if [ $commands[brew] ]; then
  # autojump
  [[ -s $(brew --prefix)/etc/profile.d/autojump.sh ]] && . $(brew --prefix)/etc/profile.d/autojump.sh
fi

# Profile zsh
if (which zprof > /dev/null) ;then
  zprof | less
fi
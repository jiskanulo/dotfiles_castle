#
# Executes commands at the start of an interactive session.
#

# zplug
if [[ -d "/usr/local/opt/zplug" ]]; then
  export ZPLUG_HOME=/usr/local/opt/zplug
  source $ZPLUG_HOME/init.zsh
  source "$HOME/.config/zsh/zplug" 2> /dev/null
fi

# load my own configures
source "$HOME/.config/zsh/alias" 2> /dev/null
source "$HOME/.config/zsh/bindkey" 2> /dev/null
source "$HOME/.config/zsh/completion" 2> /dev/null
source "$HOME/.config/zsh/env-zsh" 2> /dev/null
source "$HOME/.config/zsh/env" 2> /dev/null
source "$HOME/.config/zsh/stty" 2> /dev/null

# homeshick
if [[ -f "$HOME/.homesick/repos/homeshick/homeshick.sh" ]]; then
  source "$HOME/.homesick/repos/homeshick/homeshick.sh"
  fpath=($fpath "$HOME/.homesick/repos/homeshick/completions")
fi

# anyenv
if [ $commands[anyenv] ]; then
  eval "$(anyenv init - --no-rehash)"
fi

# direnv
if [ $commands[direnv] ]; then
  eval "$(direnv hook zsh)"
fi

# peco
if [ $commands[peco] ]; then
  source "$HOME/.config/zsh/function/cdd" 2> /dev/null
  source "$HOME/.config/zsh/function/d" 2> /dev/null
  source "$HOME/.config/zsh/function/peco-select-history" 2> /dev/null
  if [ $commands[ghq] ]; then
    source "$HOME/.config/zsh/function/cdw" 2> /dev/null
  fi
fi

# Homebew
if [ $commands[brew] ]; then
  # autojump
  [[ -s $(brew --prefix)/etc/profile.d/autojump.sh ]] && . $(brew --prefix)/etc/profile.d/autojump.sh
fi

autoload -Uz compinit && compinit -i -u

# Profile zsh
if (which zprof > /dev/null) ;then
  zprof | less
fi
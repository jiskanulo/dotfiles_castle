#
# Executes commands at the start of an interactive session.
#

# zplug
if [[ -d "$(brew --prefix)/opt/zplug" ]]; then
  export ZPLUG_HOME=$(brew --prefix)/opt/zplug
  if [[ -f $ZPLUG_HOME/init.zsh ]]; then
    source $ZPLUG_HOME/init.zsh
    source "$HOME/.config/zsh/zplug" 2> /dev/null
  fi
fi

# load my own configures
source "$HOME/.config/zsh/alias" 2> /dev/null
source "$HOME/.config/zsh/bindkey" 2> /dev/null
source "$HOME/.config/zsh/completion" 2> /dev/null
source "$HOME/.config/zsh/env-zsh" 2> /dev/null
source "$HOME/.config/zsh/env-phpenv" 2> /dev/null
source "$HOME/.config/zsh/stty" 2> /dev/null

# homeshick
export HOMESHICK_DIR=$(brew --prefix)/opt/homeshick
if [[ -f "$HOMESHICK_DIR/homeshick.sh" ]]; then
  source "$HOMESHICK_DIR/homeshick.sh"
fi

# mise
if [ $commands[mise] ]; then
  eval "$(mise activate zsh)"
fi

# direnv
if [ $commands[direnv] ]; then
  eval "$(direnv hook zsh)"
fi

# fzf
if [ $commands[fzf] ]; then
  eval "$(fzf --zsh)"
  source "$HOME/.config/zsh/function/fzf-select-history" 2> /dev/null
  source "$HOME/.config/zsh/function/cdd" 2> /dev/null
  source "$HOME/.config/zsh/function/d" 2> /dev/null
  if [ $commands[ghq] ]; then
    source "$HOME/.config/zsh/function/cdw" 2> /dev/null
  fi
fi

autoload -Uz compinit && compinit -i -u

# Profile zsh
if (which zprof > /dev/null) ;then
  zprof | less
fi
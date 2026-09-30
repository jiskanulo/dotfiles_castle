#
# Executes commands at the start of an interactive session.
#

# Resolve the Homebrew prefix once; `brew --prefix` costs a subprocess per call.
: ${HOMEBREW_PREFIX:=/opt/homebrew}

# Sourcing is guarded by [[ -r ]] instead of `2> /dev/null`, so errors inside
# these files stay visible. Loops (not a helper function) keep sourced
# `typeset` declarations such as `typeset -U path` global.

# zplug
if [[ -f $HOMEBREW_PREFIX/opt/zplug/init.zsh ]]; then
  export ZPLUG_HOME=$HOMEBREW_PREFIX/opt/zplug
  source $ZPLUG_HOME/init.zsh
  [[ -r $HOME/.config/zsh/zplug ]] && source $HOME/.config/zsh/zplug
fi

# load my own configures
for _f in alias bindkey completion env-zsh stty; do
  [[ -r $HOME/.config/zsh/$_f ]] && source $HOME/.config/zsh/$_f
done
unset _f

# homeshick
if [[ -f $HOMEBREW_PREFIX/opt/homeshick/homeshick.sh ]]; then
  export HOMESHICK_DIR=$HOMEBREW_PREFIX/opt/homeshick
  source $HOMESHICK_DIR/homeshick.sh
fi

# mise
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

# direnv
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

# fzf
if (( $+commands[fzf] )); then
  eval "$(fzf --zsh)"
  _fns=(fzf-select-history cdd)
  (( $+commands[ghq] )) && _fns+=(cdw)
  for _f in $_fns; do
    [[ -r $HOME/.config/zsh/function/$_f ]] && source $HOME/.config/zsh/function/$_f
  done
  unset _f _fns
fi

# yazi
if (( $+commands[yazi] )); then
  [[ -r $HOME/.config/zsh/function/y ]] && source $HOME/.config/zsh/function/y
fi

# claude
if (( $+commands[claude] )); then
  [[ -r $HOME/.config/zsh/function/claude-fork ]] && source $HOME/.config/zsh/function/claude-fork
fi

# kiro
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

autoload -Uz compinit && compinit -i -u

# Profile zsh (enable `zmodload zsh/zprof` in .zshenv)
if (( $+builtins[zprof] )); then
  zprof | less
fi

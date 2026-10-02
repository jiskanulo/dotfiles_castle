#
# Executes commands at the start of an interactive session.
#

# Resolve the Homebrew prefix once; `brew --prefix` costs a subprocess per call.
: ${HOMEBREW_PREFIX:=/opt/homebrew}

# Sourcing is guarded by [[ -r ]] instead of `2> /dev/null`, so errors inside
# these files stay visible. Loops (not a helper function) keep sourced
# `typeset` declarations such as `typeset -U path` global.

# Homebrew-installed zsh plugins (brew install zsh-completions
# zsh-autosuggestions zsh-syntax-highlighting); syntax-highlighting is
# sourced at the end, after compinit and all other widgets.
fpath=($HOMEBREW_PREFIX/share/zsh-completions(N-/) $fpath)
[[ -r $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
  source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh

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
  export FZF_CTRL_R_OPTS='--reverse'
  _fns=(cdd)
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

# gcloud: must follow compinit, or its completion.zsh.inc runs a bare
# `compinit` that prompts about insecure directories.
if (( $+commands[gcloud] )); then
  _gcloud_sdk=${commands[gcloud]:A:h:h}
  [[ -f $_gcloud_sdk/completion.zsh.inc ]] && source $_gcloud_sdk/completion.zsh.inc
  unset _gcloud_sdk
fi

# zoxide: init after compinit, as its docs require
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# starship prompt
if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi

[[ -r $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
  source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Profile zsh (enable `zmodload zsh/zprof` in .zshenv)
if (( $+builtins[zprof] )); then
  zprof | less
fi

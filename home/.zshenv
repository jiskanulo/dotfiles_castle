#
# Defines environment variables.
#

# Profile zsh
#zmodload zsh/zprof && zprof

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ "$SHLVL" -eq 1 && ! -o LOGIN && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi

# mise shims: resolve .tool-versions even in non-interactive shells
# (e.g. Claude Code's Bash tool, git hooks) that inherit a PATH stamped
# by `mise activate` from a parent interactive shell.
export PATH="$HOME/.local/share/mise/shims:$PATH"

function show_user_id()
{
  local uid="$(stat -c %u $1 2> /dev/null)"
  if [ -z "$uid" ]; then
    # consider BSD
    uid="$(stat -f %u $1 2> /dev/null)"
  fi

  echo $uid
}

function import_setting()
{
  [ -f $1 ] && [ "$(show_user_id $1)" = "$UID" ] && . $1
}

# If not running interactively, don't do anything
case $- in
  *i*) ;;
    *) return;;
esac

# alias, env, function...
for f in ~/.bash.d/* ; do
  import_setting $f
done

# homeshick
import_setting "$HOME/.homesick/repos/homeshick/homeshick.sh"
import_setting "$HOME/.homesick/repos/homeshick/completions/homeshick-completion.bash"

# Boxen
import_setting /opt/boxen/env.sh

if [ -z "$BOXEN_HOME" ]; then
  # Homebrew
  export PATH="/usr/local/bin:$PATH"

  # rbenv
  if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi
fi

# If Homebrew is not installed, skip after step
[ -z "$(which brew)" ] && return

# bash-completion
import_setting $(brew --prefix)/etc/bash_completion

# php-version
import_setting $(brew --prefix php-version)/php-version.sh

# Homebrew
for f in ~/.bash.d/homebrew/* ; do
  import_setting $f
done

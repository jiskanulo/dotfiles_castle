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

# Boxen
import_setting /opt/boxen/env.sh

# If brew is not installed, skip after step
[ -z "$(which brew)" ] && return

# bash-completion
import_setting $(brew --prefix)/etc/bash_completion

# php-version
import_setting $(brew --prefix php-version)/php-version.sh

# Homebrew
for f in ~/.bash.d/brew/* ; do
  import_setting $f
done

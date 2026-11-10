# dotfiles_castle
my dotfiles managed by homeshick

## Bootstrap a new machine

```sh
# 1. Homebrew, then the tools the bootstrap needs
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install mise gh homeshick

# 2. GitHub auth over HTTPS (agents_castle is private)
gh auth login && gh auth setup-git

# 3. Clone this castle into the ghq layout
git clone https://github.com/jiskanulo/dotfiles_castle ~/Workspace/github.com/jiskanulo/dotfiles_castle

# 4. Bootstrap from the castle's mise config. This clones the other repos,
#    symlinks both castles into ~/.homesick/repos and runs `homeshick link`,
#    which links ~/.config/mise/config.toml for later runs.
MISE_GLOBAL_CONFIG_FILE=~/Workspace/github.com/jiskanulo/dotfiles_castle/home/.config/mise/config.toml mise bootstrap

# 5. Enable this repo's git hooks
git -C ~/Workspace/github.com/jiskanulo/dotfiles_castle config core.hooksPath .githooks
```

After that, plain `mise bootstrap` re-applies everything.

see also
https://github.com/andsens/homeshick

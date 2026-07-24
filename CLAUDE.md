# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Dotfiles managed by [homeshick](https://github.com/andsens/homeshick). All files live under `home/` (the "castle root") and are symlinked to `$HOME` by homeshick.

## Applying changes

```sh
homeshick link dotfiles_castle   # re-create symlinks after adding/renaming files
homeshick pull dotfiles_castle   # pull latest then re-link
```

New files placed under `home/` are not automatically symlinked — run `homeshick link` after adding them.

On a fresh clone, also enable the repo's git hooks (pre-commit secret guard for
`home/.claude/settings.json` and staged changes in general):

```sh
git config core.hooksPath .githooks
```

Policy: secrets never go into `home/.claude/settings.json` — hook scripts read
them from the macOS Keychain or untracked files at runtime. The pre-commit
guard (gitleaks + credential-shape patterns + an env-key check on
settings.json) blocks violations.

## Zsh config loading order

`zshenv` → `zprofile` → `zshrc` (sources selected `~/.config/zsh/` fragments — not all of them) → `zlogin`

Fragments in `~/.config/zsh/function/` are sourced conditionally in `.zshrc` based on whether the required command exists (`fzf`, `ghq`, `yazi`).

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

## Repository structure

| Path | Purpose |
|------|---------|
| `home/.zshrc` | Loads zsh plugins and sources all `~/.config/zsh/*` fragments |
| `home/.zprofile` | Login-time env: PATH, EDITOR, LANG, LESS, Go/Composer setup |
| `home/.config/zsh/` | Modular zsh config: `alias`, `bindkey`, `completion`, `env-*`, `function/*` |
| `home/.config/sheldon/plugins.toml` | Zsh plugin manager (replaces zplug) |
| `home/.config/mise/config.toml` | Runtime versions via mise (node, pnpm, ruby) |
| `home/.config/tmux/tmux.conf` | tmux: prefix `C-t`, vi keys, popup `C-t C-Space` |
| `home/.gitconfig` | Git aliases (`g st`, `g l`, `g sw` via fzf, etc.) |
| `home/.config/karabiner/` | Keyboard remapping |
| `home/.hammerspoon/init.lua` | macOS automation |
| `home/.config/ghostty/` | Terminal emulator config |
| `home/.config/zed/settings.json` | Zed editor settings |

## Zsh config loading order

`zshenv` → `zprofile` → `zshrc` (sources `~/.config/zsh/*` fragments) → `zlogin`

Fragments in `~/.config/zsh/function/` are sourced conditionally in `.zshrc` based on whether the required command exists (`fzf`, `ghq`, `yazi`).

## Key custom shell functions

- `cdd` — fzf-select from zsh's open directories (uses lsof)
- `cdw` — fzf-select ghq-managed repositories
- `y` — yazi wrapper that changes cwd on exit
- `fzf-select-history` — fzf-powered Ctrl-R history search

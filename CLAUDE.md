# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Dotfiles managed by [homeshick](https://github.com/andsens/homeshick). All files live under `home/` (the "castle root") and are symlinked to `$HOME` by homeshick.

## Applying changes

```sh
homeshick link dotfiles_castle   # re-create symlinks after adding/renaming files
homeshick pull dotfiles_castle   # pull latest then re-link
```

New files placed under `home/` are not automatically symlinked — `homeshick link`
only processes **git-tracked** files and silently skips untracked ones. After
adding a file, `git add -N <file>` (or commit) first, then run `homeshick link`.

On a fresh clone, also enable the repo's git hooks (pre-commit secret guard:
gitleaks + credential-shape patterns on staged changes):

```sh
git config core.hooksPath .githooks
```

## Commits

Commits land directly on master (no PR flow); the branch-first rule does
not apply here. Push only when asked.

## Related castle

AI-agent configuration (`~/.claude/` etc.) lives in
[agents_castle](https://github.com/jiskanulo/agents_castle), a sibling homeshick
castle linked into the same `$HOME`. Shell-side integrations that merely reference
an agent (zsh `claude` wrapper, `ccfork`, tmux `@claude_status` format) stay here.

## Zsh config loading order

`zshenv` → `zprofile` → `zshrc` (sources selected `~/.config/zsh/` fragments — not all of them) → `zlogin`

Fragments in `~/.config/zsh/function/` are sourced conditionally in `.zshrc` based on whether the required command exists (`fzf`, `ghq`, `yazi`, `claude`).

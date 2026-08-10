---
paths:
  - home/.config/tmux/**
---

Keep tmux.conf application-agnostic: do not add bindings or config that
depend on a specific application (claude, yazi, etc.). Route app-specific
integrations to the owning app's config instead — e.g. a zsh function
fragment under home/.config/zsh/function/ sourced conditionally from
.zshrc when the command exists (fzf/ghq/yazi/claude pattern).

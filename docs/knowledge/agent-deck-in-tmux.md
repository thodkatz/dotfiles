# Agent Deck inside tmux (fleet's `deck` window)

Found 2026-11-08 trying deck v1.16.38's TUI in a private tmux server on agentvm-thinkrepos (slice 0, dotfiles PR #6).

- **Run inside tmux, deck refuses to start**: it prints "You are inside tmux. agent-deck runs its own tmux sessions,
  and Ctrl+Q would bring you back to this tmux, not to a plain shell. … Or run it here anyway:
  `AGENT_DECK_ALLOW_OUTER_TMUX=1 agent-deck`" and exits 1, so the window closes at once.
- **With only the allowance, attaching fails**: Enter on a session gives "failed to restart session: restart refused:
  this session still owns processes from an earlier spawn". With `TMUX` set, deck looks for its session on the
  outer server, doesn't find it there and tries to restart it. Unset `TMUX` and `TMUX_PANE` too.
- What works, and what `fleet` runs: `env -u TMUX -u TMUX_PANE AGENT_DECK_ALLOW_OUTER_TMUX=1 agent-deck`. Enter
  attaches, Ctrl+Q comes back to the TUI.
- **One TUI per profile**: a second deck exits with "Set [instances] allow_multiple = true in config.toml to allow
  multiple instances", so a deck already open elsewhere makes the `deck` window close.
- **First start asks to install Claude Code hooks** ("Show me when Claude is busy or needs me (adds a small hook to
  Claude's settings)"): `y` writes to `~/.claude/settings.json`, `n` skips, and `hooks_enabled` in config.toml
  turns it off later.
- **`agent-deck launch` writes its own config**: the first launch on the guest added `[claude] dangerous_mode = true`
  and `[security] auto_trust_folders = true` to `~/.config/agent-deck/config.toml` (keeping `config.toml.bak`). On a
  stowed config that write replaces the link with a copy (the package's comment), so check `ls -l` after one.

# 2026-11-10: agent deck config runtime

Unit: `change/agent-deck-config-runtime`, PR #11 (draft, claimed). **The plan is the PR body**: read it first
(`gh pr view 11`), it is the whole design; this file only adds what the PR body doesn't.

## How we got here

A session in nixed (on `main`, with the user) found the user wanted a `[hotkeys] switch_session` binding in Agent
Deck and saw that a one-line settings edit needs a `nixos-rebuild switch` on each host, because nixed's
`modules/home.nix` (`home.activation.agentDeckConfig`, nixed #30) generates the hosts' `config.toml` at switch time.
The user agreed to build it at fleet start instead, from two files: a shared `settings.toml` (machine-agnostic,
the same everywhere: the user's own words, dotfiles is machine-agnostic config) and a per-machine `remotes.toml`.

User rulings (in the session):
- `settings.toml` is shared by every machine, never varied per host.
- The laptop (Arch Linux, no nixed checkout) keeps its remotes **tracked in dotfiles**, as
  `agent-deck/dot-config/agent-deck/remotes.toml`; only the laptop stows it. The hosts' `remotes.toml` comes from
  nixed's `projects.nix`, written by nixed (follow-up PR there).

## Facts found (deck v1.16.38 source, pinned and latest)

- One config file, `toml.DecodeFile` of `$XDG_CONFIG_HOME/agent-deck/config.toml`: no includes, no path override
  but `XDG_CONFIG_HOME` itself (`internal/session/userconfig.go` `LoadUserConfig`, `internal/agentpaths/paths.go`).
  Deck reloads it when its mtime changes, so a regenerated file is picked up by a running TUI.
- `[hotkeys] switch_session` ships unbound (`internal/ui/hotkeys.go`, `defaultDisabledHotkeys`: Ctrl+S collides
  with Claude Code's stash-prompt and XOFF). Only the TUI's Enter-attach sets a switch key; `agent-deck session
  attach` (cmd/agent-deck/session_focus_cmd.go `handleSessionAttach`) passes only the detach byte. Verified by the
  user and in a private tmux: Ctrl+S does nothing either way while unbound.
- Separate agent-deck bugs seen in the same session (not this unit; the user hasn't decided on an upstream report):
  a detach back to a shell homes the cursor and clears scrollback (`internal/tmux/pty.go`: `terminalStyleReset`
  ends in a bare `ESC[r`, PR #2964; `emitScrollbackClear` on attach and detach); an attach run inside an attached
  session nests (two status bars); the status bar says "ctrl+s switch" with nothing bound.

## Next

Implement PR #11's plan in this worktree (`superpowers:subagent-driven-development` is overkill for one change;
TDD on `tests/fleet.bats`), local review round, merge, then the nixed follow-up as its own change unit
(`change/agent-deck-config-runtime` in nixed: write `remotes.toml`, link `settings.toml`, drop `agentDeckConfig`,
a `BACKLOG.md` *Next* switch line for both hosts).

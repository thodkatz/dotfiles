# Backlog

Deferred items with no slice yet. One item each, about three lines at most: the item, where it came from (PR, review
thread, spec), and why it waits. An item that needs more points to its proposal in `docs/proposals/`. The PR
that fixes an item deletes its line. See
`.methodology/shared/guides/development-workflow.md`, *Deferred items land somewhere durable*.

## Next

Due soon, on any track: what someone said to do "in the next session", and what waits on the user. Every session
start reads this section; keep it short.

<!-- - <item> — from <investigation / review / handoff>; <waits on the user: what> | <due: why soon>. -->
- The laptop try of layout C (agent-methodology's slice 3b, 3b.2 step 1 and 3b.3 step 1): does `agent-deck session
  focus --remote <guest> <id> --attach` open a remote's session in the TUI (`follow.log` in fleet's state dir says what each
  hop did; a no-op `--attach` means `FOLLOW_ARGS=()`); the look with both guests; the hint's counts against `methodology status`; whether deck's rows show
  `am-unattended` — from PR #7's rulings; waits on the user: a `git pull`, `stow -R tmux agent-deck` and `fleet` on the
  laptop.
- thinkcentre's deck window: after nixed PR #27 (`change/host-agent-deck`) merges and is switched, `fleet --local
  doctor` passes and `fleet --local` from outside tmux shows the deck window — from dotfiles PR #8; waits on the user:
  nixed #27 merged and switched, a `git pull` in thinkcentre's `~/repos/dotfiles`, and `README.md`'s *Setup on a host*
  block with `192.168.123.*` in thinkcentre's `~/.ssh/config` (`ok    deck ssh`).
- nixos's deck window: its `repos` remote showed `auth failed` — from dotfiles PR #10; waits on the user: a `git pull`
  in nixos's `~/repos/dotfiles`, `README.md`'s *Setup on a host* block (`192.168.122.*`) in nixos's `~/.ssh/config`,
  then `fleet --local doctor` shows `ok    deck ssh`.
- nixed's half of the runtime deck config: `modules/home.nix` writes `remotes.toml` from `projects.nix` (the host's
  guests), links `settings.toml`, drops `agentDeckConfig`; then a `switch` on both hosts — from dotfiles PR #11 (the next
  unit, `change/agent-deck-config-runtime` in nixed); until then a host's `fleet` warns and keeps its old config.
- The laptop after PR #11: `git pull`, `stow -R agent-deck` (drops the `config.toml` link), `fleet`; `fleet doctor`
  shows `ok    agent-deck config` — waits on the user.

## Unscheduled

<!-- - <item> — from <PR #n / review thread / spec Inputs for>, waits because <reason>. -->
- Agent Deck bugs seen in v1.16.38, maybe an upstream report: a detach back to a shell homes the cursor and clears
  scrollback (`internal/tmux/pty.go`, `terminalStyleReset`'s bare `ESC[r`, PR #2964; `emitScrollbackClear`); an attach run
  inside an attached session nests; the status bar says "ctrl+s switch" with nothing bound — from dotfiles PR #11's
  handoff; waits on the user: whether to report them.

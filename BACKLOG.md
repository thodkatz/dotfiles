# Backlog

Deferred items with no slice yet. One item each, about three lines at most: the item, where it came from (PR, review
thread, spec), and why it waits. An item that needs more points to its proposal in `docs/proposals/`. The PR
that fixes an item deletes its line. See
`.methodology/shared/guides/development-workflow.md`, *Deferred items land somewhere durable*.

## Next

Due soon, on any track: what someone said to do "in the next session", and what waits on the user. Every session
start reads this section; keep it short.

<!-- - <item> — from <investigation / review / handoff>; <waits on the user: what> | <due: why soon>. -->
- The hop follow of PR #12 on each host and laptop: once agent-methodology#158 is on the guests (`methodology update`),
  `git pull`, `stow -R tmux` and `fleet`; then a hop in a viewed session moves the TUI's attach to the successor with
  its cursor on it, and one Ctrl+Q leaves; `claudes` from an extra window of a deck session switches that terminal —
  from PR #12; waits on the user.
- The laptop try of layout C (agent-methodology's slice 3b, 3b.2 step 1 and 3b.3 step 1): at a hop, does the TUI's attach
  move to the successor, and after Ctrl+Q is its cursor on it (`agent-deck session focus --remote <guest> <id>`; `follow.log`
  in fleet's state dir says what each hop did); the look with both guests; the hint's counts against `methodology status`; whether deck's rows show
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
  unit, `change/host-agent-deck-config` in nixed); until then a host's `fleet` warns and keeps its old config.
- The laptop after PR #11: `git pull`, `stow -R agent-deck` (drops the `config.toml` link), `fleet`; `fleet doctor`
  shows `ok    agent-deck config` — waits on the user.
- Claude Code's status line after PR #14, which is inert until agent-methodology#177 (the hook that runs the renderer) has
  merged. Then, a session: check `claude/dot-config/agent-methodology/statusline-render` against the hook as merged
  (`AGENT_STATUSLINE_RENDER`, the path `~/.config/agent-methodology/statusline-render`, `AGENT_SL_PLAIN`, `AGENT_SL_CTX`,
  `AGENT_SL_BUDGET`, `AGENT_SL_INBOX`, where its stderr goes) and fix what differs, as a direct commit. The user, per
  machine: `methodology update`; on the laptop `git pull`, `mkdir -p ~/.config/agent-methodology`, `stow -t "$HOME"
  --dotfiles -R claude` and the pinned `npm install` (`README.md`, *Install*); in a guest the three lines of `README.md`,
  *Claude Code's status line*; then look at the line: only they can judge it. If its last line runs past the terminal's
  edge (our boxes take up to 47 columns, claude-powerline keeps 45 free), set `display.widthReserve` in the config —
  from PR #14 and its review (finding 9); waits on agent-methodology#177, then on the user.
- A gruvbox theme for Claude Code itself, the other half of what the user asked for with the status line (2026-11-15):
  `claude/dot-claude/themes/gruvbox.json` (`base: dark` plus `overrides`; the token names are in
  code.claude.com/docs/en/terminal-config.md, *Create a custom theme* and *Color token reference*), picked with `/theme`;
  their theme is plain `dark` now. Its own small change in the `claude` package — from PR #14's handoff; due: asked for,
  not built.
- The status line on the hosts and in every guest without hand setup, a change in nixed (the user asked how,
  2026-11-15): `modules/home.nix` links the renderer with `linkDotfile` as it does `fleet` (thinkcentre and nixos, one
  switch each) and installs the pinned claude-powerline; `microvms/guest/base.nix` does the same for the guests, where a
  guest whose `/workspace` is one project has no `/workspace/dotfiles` to link from, so nixed has to carry the renderer
  there. To check first: that the renderer finds its config through home-manager's link, and that Claude Code on a host
  runs `statusline.sh` outside a methodology repo — from PR #14's session; after #14 and agent-methodology#177.

## Unscheduled

- fleet's cursor misses a second hop made while the moved attach is still open (d-am-1 → 2 → 3 with the TUI still attached): `follow_hops` marks the 2 → 3 hop followed, since neither `cur` nor `rec` names d-am-2; the view moves anyway (agent-methodology's end), only the cursor ends on the old row. Fix: a waiting hop's successor counts as `cur` too, with a bats case — from #12's review.

<!-- - <item> — from <PR #n / review thread / spec Inputs for>, waits because <reason>. -->
- Agent Deck bugs seen in v1.16.38, maybe an upstream report: a detach back to a shell homes the cursor and clears
  scrollback (`internal/tmux/pty.go`, `terminalStyleReset`'s bare `ESC[r`, PR #2964; `emitScrollbackClear`); an attach run
  inside an attached session nests; the status bar says "ctrl+s switch" with nothing bound — from dotfiles PR #11's
  handoff; waits on the user: whether to report them.
- Spinner verbs for Claude Code (`spinnerVerbs` in the settings), offered to the user with the status line and not asked
  for — from PR #14's handoff; waits on the user: whether they want them.
- Two gotchas in `docs/knowledge/claude-code-appearance.md` belong in agent-methodology's `tooling-gotchas.md`, being
  about Claude Code and bash in any repo: a `! <command>` prints escape codes as text (show colours in a
  `tmux display-popup -E`), and `$'\ue0b0'` follows the locale while the Write tool turns `\ue0b0` into the glyph (write
  the bytes). Carry them as a change there, then cut them from the note — from PR #14's review (finding 20).

# 2026-11-08: fleet layout C, tests and texts done (hop 2)

**Unit:** change `change/fleet-layout-c`, draft PR #7, worktree `.claude/worktrees/change-fleet-layout-c`. Agent Deck
slice 3b: `/workspace/agent-methodology/docs/superpowers/plans/2026-11-08-agent-deck-adoption/slice-3b-view.md`.
The previous handoff (`2026-11-08T1850Z-fleet-layout-c-wip.md`) says what the new fleet does; read only this one.

## Done (commits 5fb8ffc, cf7b716, pushed)

- `tests/fleet.bats` rewritten: 40 tests, **all ok** (`bats tests/`, ~2 min); shellcheck on fleet and the stubs prints
  nothing. Includes 3b.1's four and 3b.2's four by the plan's names, plus a probe-script hops test inside "an
  unviewed hop moves nothing". New: `tests/stub/agent-deck` (TUI loop attaching what `$FLEET_FIXTURES/deck-attach`
  names; `list --json`, `session annotate`; else logs to `deck.log`), `tests/fixtures/deck-config.toml`, fixtures in
  3a's shape, ssh stub's `fleet:hops`, `session attach` and `test -x .local/bin/agent-deck` cases.
- **A fix in fleet:** `deck_attached` matched processes by `comm == ssh`; a script named ssh (the stub, or any
  wrapper) has comm `bash`. It now reads `args`: first word ssh, or second after a shell. Say so in the PR body.
- Texts: `tmux.conf` (no `F`, no agent-pane border tags or host-coloured tabs; border names overview/resources panes),
  `README.md` (fleet section, keys table, *Update and run*: no prefix F; run `fleet` once from outside an older
  session to rebuild it), `AGENTS.md` *Project in brief*, deck config `[remotes.repos]`, the spec (decisions 6–12,
  14, 15, *Layout*, new *Hops*, *Hint*, *Contract consumed*; *Sync* gone; Clarification 20 `folded`).

## Next

1. D20's grep for the PR body: `grep -n 'pane-border\|sync\|follow_panes\|name_windows' tmux/dot-local/bin/fleet
   tmux/dot-config/tmux/tmux.conf` (expect only tmux.conf's pane-border lines for overview/btop, no session window).
   Also grep the repo for stale mentions (`prefix F`, `fleet sync`, `overview2`, `_hintloop`, `FLEET_NO_HINTLOOP`,
   `docs/knowledge/`, `BACKLOG.md`) and fix any current-design text.
2. Squash-or-not is the merge's; update PR #7's title/body: `fleet: layout C whole, the session windows go
   (agent-methodology D20)`, 3b.1 and 3b.2 land together, the tests removed (sync/tick/attach/session-window/
   overview-colour/hint-loop, all of the old file's tests not kept), the deck_attached fix, the mode ruling (mode
   shows in window 2's rows), what the user runs after merge (pull on laptop and hosts, `stow -R tmux agent-deck`,
   `prefix r`, run `fleet` from outside the old session to rebuild).
3. Local review (reviewer subagents, `development-workflow.md` *Local review*), address findings, bats again.
4. Gate on PR #7 for the user's laptop try (3b.2 step 1, 3b.3 step 1) per `development-workflow.md` *Gates*. With no
   answer the ruling is the fallback `FOLLOW_ARGS=()` (select only), in the PR body. Then merge and 3b.3 step 2 in
   agent-methodology (the earlier handoff `2026-11-08T1843Z-agent-deck-slice-3b.md`, *At the end*).

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

## Unscheduled

<!-- - <item> — from <PR #n / review thread / spec Inputs for>, waits because <reason>. -->

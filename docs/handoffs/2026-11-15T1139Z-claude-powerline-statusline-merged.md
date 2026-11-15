# Handoff: the powerline status line (change/claude-powerline-statusline, #14), the unit's end

Written 2026-11-15, before the merge: the review round is done and every finding answered on the PR. This is the
unit's last handoff; it has no next unit. What is left is in `BACKLOG.md`, not here.

## State

- **dotfiles #14** adds the `claude` package (the renderer, claude-powerline's config), `tests/statusline.bats` and
  the docs. One local review round (correctness; methodology), 20 findings, all fixed or ruled: the findings comment
  and the reply are on the PR. `bats tests/`: 70 of 70. The `shellcheck` line in `AGENTS.md`, *Setup*: clean.
- **Ruled in the review**: #14 merges without waiting for agent-methodology#177 (the hook that runs the renderer).
  The files are inert until that hook is on a machine. The earlier handoff
  (`2026-11-15T0804Z-claude-powerline-statusline.md`) said to wait with `next --end --blocked`: that is the gate
  form, and another repo's PR is no gate.
- **agent-methodology #177** was an open draft at 11:40Z, with a first commit of the hook; its session is the
  supervisor's.

## What is left, and where it lives

`BACKLOG.md`, *Next* (`sed -n '/^## Next/,/^## /p' BACKLOG.md`):

- the status line after #14: once #177 has merged, check the renderer against the hook as merged; then the user's
  setup per machine and their look at the line;
- the gruvbox theme for Claude Code itself, still owed to the user;
- the nixed change that gives the hosts (thinkcentre, nixos) and every guest the status line without hand setup.

*Unscheduled*: the spinner verbs, and two gotchas to carry to agent-methodology.

## Notes

`docs/knowledge/claude-code-appearance.md`: why not tweakcc or ccstatusline, how to show the user colours, the
arrow as bytes, claude-powerline's recolouring of the usage boxes.

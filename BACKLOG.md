# Backlog

Deferred items with no slice yet. One item each, about three lines at most: the item, where it came from (PR, review
thread, spec), and why it waits. An item that needs more points to its proposal in `docs/proposals/`. The PR
that fixes an item deletes its line. See
`.methodology/shared/guides/development-workflow.md`, *Deferred items land somewhere durable*.

## Next

Due soon, on any track: what someone said to do "in the next session", and what waits on the user. Every session
start reads this section; keep it short.

<!-- - <item> — from <investigation / review / handoff>; <waits on the user: what> | <due: why soon>. -->
- GitHub settings for thodkatz/dotfiles (ADOPTING.md step 4): the labels `spec plan impl change approved
  large-slice waiting-on-user`, auto-delete of head branches — from the
  adoption PR; the user declined them on 2026-11-07, so until they exist a claim's `gh pr create --label` fails
  (open without `--label`) and a spec has no `approved` gate; waits on the user.

## Unscheduled

<!-- - <item> — from <PR #n / review thread / spec Inputs for>, waits because <reason>. -->
- Split the tmux-fleet spec (`docs/superpowers/specs/2026-11-05-tmux-fleet-design.md`, 412 lines) into a directory,
  a `README.md` index plus one file per section (`spec-and-plan-layout.md`, *Splitting an existing document*) — from PR #4's
  review, waits because it is a `git mv`-and-links change of its own, not this PR's.

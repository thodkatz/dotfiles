# 2026-11-07: fleet window branch review

Unit: change `change/fleet-window-branch`, PR thodkatz/dotfiles#4, worktree
`/var/tmp/worktrees/dotfiles-fleet-window-branch` (made by hand before dotfiles adopted the methodology, not under
`.claude/worktrees/`). The previous session hit its context budget before the review round.

## State

- Implemented, rebased on `origin/master` (7437cd1, after the methodology adoption #3) with `--signoff`, pushed.
  Windows are named `<repo>/<branch's last part>` (`win_label`, `name_windows` in `tmux/dot-local/bin/fleet`),
  tagged `@fleet-repo` and `@fleet-name`; README, spec decision 6, *Layout*, *Sync* step 2 and Clarification 18,
  and a tmux.conf comment updated. Why `/` and not `·`: the spec's Clarification 10.
- `bats tests/` passed 70/70 before the rebase (the rebase touched no fleet file). The new tests fail on the old
  `fleet`. `shellcheck tmux/dot-local/bin/fleet`: the same SC1010, SC2015 and SC2034 as master, nothing new.
- The hint loop ticks the `fleet` on disk (`cmd__hintloop`, stamp 5), so tick-time renames need no stamp bump.
- Not done: the PR has no `change` label (the repo has none; creating it is the user's adoption setting,
  `forge-github.md`, *Setup*); no review round yet.

## Next, in order

1. `bats tests/` once more on the rebased branch.
2. Local review round (`development-workflow.md`, *Review and merge*, step 2): reviewer subagents via
   `superpowers:requesting-code-review` on PR #4, a **correctness** focus (the diff against spec decision 6's
   acceptance check and Clarification 18; old-window adoption, hand renames, grouping by `@fleet-repo`,
   `split_windows`) and a **methodology** focus (stale docs, `methodology sync --check`). Post them as one comment
   starting `Methodology <sha>` (`git -C .methodology rev-parse HEAD`).
3. Fix or answer each finding, reply in one comment, then `gh pr merge 4 --squash` (no `pr-checks` here: AGENTS.md
   *Overrides*). Clean up (*Review and merge* step 7), then the post-merge handoff on master and
   `methodology next --end` (no track follows this unit).
4. Report to the user that #4 merged; after merging they run `git pull` on the laptop and hosts, then `prefix F`.

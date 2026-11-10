# 2026-11-10: agent deck config runtime merge


Unit: `change/agent-deck-config-runtime`, PR #11 (ready, not merged), worktree
`.claude/worktrees/change-agent-deck-config-runtime`. The previous handoff is
`2026-11-10T2152Z-agent-deck-config-runtime.md`; the PR body has the plan, a *Result* section and the rulings.

## Done

- `agent-deck/dot-local/bin/agent-deck-config` (bash + awk), wired into `fleet up` (before the deck window, at each
  run) and `fleet doctor`; the package's `config.toml` split into `settings.toml` and `remotes.toml`; README, spec
  Clarification 25, knowledge note (`switch_session` does nothing on a remote's session), BACKLOG, AGENTS.md.
- The review round is done: both reviewers' findings are fixed and replied to in one PR comment (#issuecomment-6781737032).

## Next

1. Run the full suite (`bats tests/`, about 4 min, in the background) and `shellcheck tmux/dot-local/bin/fleet
   agent-deck/dot-local/bin/* tests/stub/*`. The last full run (55/55) came before the review fixes in 058d8d5; since
   then only the `agent-deck-config` tests and the `up: builds deck's config…` test were run, 9/9 ok. Update the body's
   `Checks:` line to the new count.
2. Re-read the PR's comments, then merge it squashed (forge sheet *Merge*, `master`), clean up (workflow step 7).
3. Write the post-merge handoff on `master` and chain with `methodology next --unit` into the nixed follow-up
   (`BACKLOG.md` *Next*'s first new line: nixed's `change/agent-deck-config-runtime`). It runs in the nixed repo, so
   the chain starts from nixed's main checkout.

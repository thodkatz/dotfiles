# 2026-11-08: Agent Deck slice 3b, layout C whole (start)

**Unit:** change `change/fleet-layout-c`, slice 3b of agent-methodology's Agent Deck plan. Slice 3a merged there
(#141, `2ec4cd6`): `methodology status --json` now has `deck_id`, `activity`, `mode`, `skipped`, no `socket`;
`--all` reads each `[remotes]` guest over ssh.

**Read first:** the slice,
`/workspace/agent-methodology/docs/superpowers/plans/2026-11-08-agent-deck-adoption/slice-3b-view.md` (tasks
3b.1–3b.3, its rulings for the PR body). For the design, only what it names: `05-view.md` *Layout C* (D20) and
Clarification 5, under `/workspace/agent-methodology/docs/superpowers/specs/2026-11-08-agent-deck-adoption-design/`.
agent-methodology's newest handoff, `docs/handoffs/2026-11-08T1843Z-slice-3a-merged-3b-next.md`, says what 3a's merge
settled.

**Work here** by dotfiles' `AGENTS.md`: a `change` PR from this worktree, signed off, local review before the merge.

**Known limits for an unattended run:** this session runs on the guest (agentvm-thinkrepos). Task 3b.1 and 3b.2's
steps 2-3 (bats on an ssh stub) are guest work. 3b.2 step 1 (does `focus --remote <guest> <id> --attach` open a
remote session in the TUI) and 3b.3 step 1 (the look with both guests, a capture) need the laptop: do the guest's
part, then gate on the PR for the user's try (development-workflow.md, *Gates*), and implement `follow_hops` from
the answer; if the answer isn't in, the plan's fallback (`focus` without `--attach`) is the ruling, overrulable.

**At the end** (3b.3 step 2): after the merge, in agent-methodology on `main`, direct mode: 3b's *Status* in the plan
README, a handoff, `BACKLOG.md`'s *Next*; the texts naming fleet's session windows or `fleet sync` are
agent-methodology's `change/fleet-layout-c-texts` PR, merged before slice 4a starts.

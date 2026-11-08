# 2026-11-08: Agent Deck slice 0, layout C's overview (start)

**Unit:** change `change/fleet-layout-c-overview`, slice 0 of agent-methodology's Agent Deck plan (#128, merged
as `b699d87`). The user asked for it to start unattended (2026-11-08).

**Read first:** the slice, `/workspace/agent-methodology/docs/superpowers/plans/2026-11-08-agent-deck-adoption/slice-0-overview.md`
(tasks 0.1–0.3, the rulings for the PR body). For the design behind it, only what the slice names: the spec's
*Early output* and `05-view.md` *Layout C* (D20, D25), under
`/workspace/agent-methodology/docs/superpowers/specs/`. agent-methodology's newest handoff,
`docs/handoffs/2026-11-08T0153Z-agent-deck-slice-0.md` there, says the same.

**Work here** by dotfiles' `AGENTS.md`: a `change` PR from this worktree, signed off, local review before the merge.

**Known limits for an unattended run:** task 0.2 installs `agent-deck` on the laptop and tries deck's TUI inside the
outer tmux; this session runs on the guest (agentvm-thinkrepos), so what only the laptop can show (the install there,
the TUI's look and keys) goes in the PR body as for the user to try, with the guest's part done and recorded. Task
0.3.2's comment asks the user for the working-session look; no gate on this PR.

**At the end** (task 0.3.4): after the merge, in agent-methodology on `main`, direct mode: the plan's slice 0 status,
a handoff, `BACKLOG.md`'s *Next* ("slice 1a waits for the user's look at step 0"), then `methodology next --unit
impl/agent-deck-1a-pin-contract <handoff>` from agent-methodology's main checkout.

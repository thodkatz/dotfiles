# 2026-11-08: fleet layout C overview, done (Agent Deck slice 0)

**Unit:** `change/fleet-layout-c-overview`, dotfiles PR #6. Slice:
`/workspace/agent-methodology/docs/superpowers/plans/2026-11-08-agent-deck-adoption/slice-0-overview.md`. The PR body
holds the rulings, versions, the guest-side try and what the user runs.

## Done

- Tasks 0.1 and 0.2 (`fleet` windows `deck` and `overview2`, the hint's `✉N`, the `agent-deck` package), README and
  the fleet spec (decisions 6 and 10, Clarification 19). `bats tests/` 80/80; shellcheck no new findings.
- Task 0.2 step 3 on the guest: deck's TUI in a private tmux server, a scratch `agent-deck launch` with one real
  claude turn, attached and detached. Found: deck must run as `env -u TMUX -u TMUX_PANE AGENT_DECK_ALLOW_OUTER_TMUX=1
  agent-deck` inside tmux; fleet now does (knowledge note `docs/knowledge/agent-deck-in-tmux.md`).
- Task 0.3.1: the sample is `_overview2 --once` against this guest, 0 open inbox items today (in the PR body);
  0.3.2: the look-request comment is posted on PR #6.
- Local review round (correctness, methodology): every finding fixed in `b0026a0` or answered in the PR body.

## Next (the rest of 0.3)

1. **0.3.3**: close dotfiles PR #5 with a comment: dropped by agent-methodology's Agent Deck spec (#127, D21).
2. **0.3.4**, in agent-methodology on `main`, direct mode: the plan's slice 0 *Status* (merged, dotfiles PR #6),
   a handoff for slice 1a, `BACKLOG.md`'s *Next* ("slice 1a waits for the user's look at step 0", naming PR #6's
   comment), then `methodology next --unit impl/agent-deck-1a-pin-contract <handoff>` from agent-methodology's
   main checkout.

## Open for the user (no gate)

The working-session look (PR #6's comment); the laptop's install and `agent-deck --version`; attaching a remote
guest's session from the laptop (untried); deck's hooks prompt on the laptop.

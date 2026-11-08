# 2026-11-08: fleet layout C, reviewed (hop 3, the unit's end)

**Unit:** change `change/fleet-layout-c`, PR #7 (Agent Deck slice 3b in agent-methodology:
`/workspace/agent-methodology/docs/superpowers/plans/2026-11-08-agent-deck-adoption/slice-3b-view.md`).

## Done

- Stale texts after the grep (AGENTS.md's `prefix F`, the shellcheck line now "clean", the old plan's row is history;
  BACKLOG's spec-split item dropped at 355 lines).
- PR body: title, what changes, tests, after-merge steps, rulings.
- Local review round (correctness, methodology), one comment on PR #7, every finding fixed or answered there.
  Code fixes in `follow_hops`: a hop whose attach is still open waits a round; a record the user left live is dropped
  (Clarification 5); a failed `focus --attach` is retried without it; each decision logs to
  `<state>/<s>/follow.log`; `names` matches ids and tmux names exactly. `tmux.conf` has `unbind F`. 44 bats tests ok.
- **Ruling: no gate for the laptop try** (a plan step adds no gate); it is `BACKLOG.md` *Next*, waiting on the user.

## Next

3b.3 step 2, in agent-methodology on `main`: 3b's *Status* in the plan README, a handoff, its `BACKLOG.md` *Next*;
the texts naming fleet's session windows or `fleet sync` (`sessions-and-context.md`, the machine notes,
`docs/knowledge/`) are agent-methodology's `change/fleet-layout-c-texts` PR, local review, merged before slice 4a.

Seen once, cause not found: the second of two back-to-back `bats tests/` runs in one command stalled past 15 min;
run alone, the suite passed in a few minutes.

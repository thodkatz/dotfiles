# 2026-11-08: fleet deck doctor, review round next

## change/fleet-deck-doctor (PR #8, ready)
Done: `fleet doctor` checks this machine's agent-deck (on PATH, at `agent-deck-install`'s pin read from the checkout
fleet runs from, with its config); `fleet up` says when there is no deck window and rebuilds a layout-C session
without one once deck is installed. README updated. `bats tests/` 47 ok, shellcheck clean (commit b577b31).

Why: on thinkcentre `fleet --local` showed no deck window and doctor passed (agent-deck wasn't installed on the host).
Paired with nixed PR #27 (`change/host-agent-deck`), which installs it there through home-manager.

Next: the local review round (AGENTS.md, *Reviewers*: correctness and methodology subagents), address it, merge
(*Before a merge*), clean up. Then on thinkcentre, after nixed #27's switch: `fleet --local doctor`, and `fleet --local`
from outside tmux should show the deck window.

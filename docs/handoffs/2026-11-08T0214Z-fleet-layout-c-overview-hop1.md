# 2026-11-08: fleet layout C overview, hop 1 (Agent Deck slice 0)

**Unit:** `change/fleet-layout-c-overview`, claimed as **dotfiles PR #6** (draft, label `change`), worktree
`/workspace/dotfiles/.claude/worktrees/change-fleet-layout-c-overview`. Slice:
`/workspace/agent-methodology/docs/superpowers/plans/2026-11-08-agent-deck-adoption/slice-0-overview.md`. The
previous handoff is `2026-11-08T0202Z-agent-deck-slice-0.md` (its *Known limits* and *At the end* still hold).

## Done (pushed)

- `0bf1608` task 0.2's package: `agent-deck/dot-config/agent-deck/config.toml` (`[updates]` all false,
  `[remotes.thinkrepos]` host `agentvm@192.168.123.51`, `agent_deck_path` `/home/agentvm/.local/bin/agent-deck`) and
  `agent-deck/dot-local/bin/agent-deck-install` (v1.16.38, linux_amd64 tarball sha256
  `f7971f89…63536`, from the release's own digest; tried: installs, skips when present, refuses a wrong sum).
- On this guest, by hand: `~/.local/bin/agent-deck` = **Agent Deck v1.16.38**, binary sha256 `077bd760…b760f`, the
  trial's; `~/.config/agent-deck/config.toml` = the `[updates]` block only.
- `d4e7a2d` task 0.1: `fleet _overview2 [--once] [session]`, `overview2_render`, `inbox_items`,
  `layout_c_windows` (deck window first when `FLEET_DECK_CMD`, default `agent-deck`, is found; `overview2` after
  `overview`, stamp `@fleet-overview2 1`, btop of the first guest beside, 72 cols), the hint's `✉N` per host and
  `COUNT_DEFS` (live/asking from `activity` when a row has it). **`bats tests/` 79/79 ok; shellcheck same 6 findings
  as before.**

## Rulings made (copy into the PR body)

- **The inbox is read from the item files, not INBOX.md**: INBOX.md's open lines carry no `continue` (inbox.sh's
  render); the item files do. The probe's new mode `inbox-json` prints `fleet:inbox`, each non-closed item as
  `<n>\t<key>=<value>` lines, `fleet:status`, then status.sh's JSON. Fixture: `tests/fixtures/inbox-192.168.123.51/`
  (items 21 open, 20 closed) instead of the plan's `inbox.md`.
- **Discovery uses `inbox-json`**, so the hint's ✉ and window overview2 share one probe; overview2 rediscovers into
  its own `overview2.json` every `FLEET_OVERVIEW_INTERVAL` (30 s) so it doesn't depend on the hint loop.
- **The hint stays per host and gains `✉N`** (blue `#83a598`, left out at 0): with one host it reads layout C's
  `●N ◆M ✉N`; with two, each host keeps its own counts. Live/asking come from `activity` (`working|idle|asking`,
  `asking`) when a row has one; today's status.sh has no `activity`, so the old rules apply (alive and no kind;
  a kind or blocked).
- **The install script is a stowed command** (`agent-deck-install` in `~/.local/bin`), not `agent-deck/install.sh`:
  stow would link the latter as `~/install.sh`.
- An item with no `continue` shows `needs: <needs>`. `sync -p` never takes a btop, overview2 or deck pane.

## Next (in order)

1. **README.md** (*Working Conventions*: every user-facing change): add `agent-deck` to the install command's
   package list (with `mkdir -p ~/.config/agent-deck` first so stow links the file), the `agent-deck-install` step,
   windows `deck` and `overview2`, the hint's ✉. Check `tmux/dot-config/tmux/tmux.conf`'s hint comment (~l. 59–63)
   and the fleet spec's text for stale wording. Commit.
2. Task 0.2 step 3 / 0.3 step 1 on the guest: `fleet --local _overview2 --once` can't reach this guest from itself;
   for the sample run `_overview2 --once` with `FLEET_HOSTS_FILE` unused… simplest: the render of a hand-made
   discover file, or `tmux capture-pane` text of a test session. Today the guest's inbox has **0 open items**
   (INBOX.md `0 open`), so the sample's "one real open item" may need the user's next item; say so in the PR body.
   Try `agent-deck launch` scratch per the slice only if it fits; the laptop-only parts go in the PR body for the user.
3. PR body (plan, rulings, versions, what the user runs: `git pull`, `stow -R tmux agent-deck`,
   `agent-deck-install`, `prefix F`), mark ready, local review (two reviewer subagents: correctness, methodology),
   address, merge, the 0.3.2 comment, close PR #5 (0.3.3), then 0.3.4 in agent-methodology per the earlier handoff.

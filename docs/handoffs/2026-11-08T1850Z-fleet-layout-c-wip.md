# 2026-11-08: fleet layout C whole, mid-unit (hop 1)

**Unit:** change `change/fleet-layout-c`, draft PR #7, worktree `.claude/worktrees/change-fleet-layout-c`. Agent Deck
slice 3b: `/workspace/agent-methodology/docs/superpowers/plans/2026-11-08-agent-deck-adoption/slice-3b-view.md`
(read it; the previous handoff, `2026-11-08T1843Z-agent-deck-slice-3b.md`, has the limits of an unattended run).

## Done (commit "wip: fleet layout C whole…")

`tmux/dot-local/bin/fleet` is rewritten for 3b.1 and 3b.2 (`bash -n` ok, shellcheck printed nothing); **the tests are
not yet rewritten, so `bats tests/` fails now.** What the new fleet does:

- `cmd_up`: window `deck` (when `FLEET_DECK_CMD`/agent-deck exists, `@fleet-deck` 1), then `overview` (`_overview`
  loop, `@fleet-overview` 1) with the first guest's btop (`@fleet-res-guest`) right, `-l 72`. No other windows.
  `@fleet-booted-<s>` is now `c` (`LAYOUT`): an older fleet's session (marker `1`) is killed and rebuilt by `fleet`,
  and an old `hintloop.pid`'s loop is killed.
- Gone: sync (`fleet sync` is now unknown: usage, exit 2), `_tick`, `_hintloop`, `_attach`, `_overview2`, `_colour`,
  `follow_panes`, `sync_layout`, `name_windows`, `split_windows`, `tag_pane`, `win_label`, `live_look`,
  `colour_table`, `overview_layout`, `pane_guest_ip`, `OVERVIEW_STAMP`, the `↻` count.
- `_overview <s> [--once]`: each round runs the on-disk fleet's `_round` (discover into `<state>/<s>/fleet.json`,
  `hint_write`, `follow_hops`, `overview_render`), so a pull needs no restart. `FLEET_NO_LOOP` set: the pane idles
  (for the tests: set it in `setup` in place of `FLEET_NO_HINTLOOP`).
- `overview_render` lists each status row under `status: N rows`: `    <branch|worktree's last part>  <mode>
  <activity|->  [kind] [gated #N]` (the plan's mode ruling: the mode shows in window 2's rows).
- `COUNT_DEFS` reads only `activity` (live: working|idle|asking; asking: asking).
- The probe's `inbox-json` now ends with `fleet:hops` and `<old id>\t<successor id>\t<old's tmux session>` lines
  (rows whose `prev` names an archived deck session with `am.viewed=1`; deck at `~/.local/bin/agent-deck` on the
  guest). `discover` adds `hops: [{prev, id, tmux}]` per guest.
- `follow_hops`: the deck pane's attaching ssh (`deck_attached`: an ssh under the pane whose words contain
  `attach`, its host resolved by `ssh -G` to a fleet.json IP) is recorded each round in `<state>/<s>/deck-attached`
  (kept when the TUI is on its list); a hop whose old id or tmux session is in the record, on that guest, with the
  TUI attached to nothing now, runs `agent-deck session focus --remote <name> <new> --attach` (`FOLLOW_ARGS`), name
  from deck's config (`deck_remote`, `FLEET_DECK_CONFIG`). Each hop once (`hops-followed`, "<ip> <old>"), chains in
  order (the record moves to the successor).
- `doctor` checks `test -x .local/bin/agent-deck` on each guest (message "no ssh, or no agent-deck there"); no fzf.

## Next

1. **Tests** (`tests/fleet.bats`): delete the sync/tick/attach/session-window/overview-colour/hint-loop tests; adapt
   the rest (window names now `overview` only, or `deck,overview`; `_overview2 --once` → `_overview fleet --once`, its
   output now has the row lines; boot marker `c`; ssh tests: the btop pane in place of attach panes; doctor's
   message). Rewrite the guest fixtures to 3a's `status --json` shape (`deck_id`, `activity`, `mode`, `prev`, no
   `entry`/`live`/dtach `continue`). Add the plan's tests: 3b.1's four (`"fleet start makes the deck and overview
   windows only"`, `"overview lists both guests' open items and status rows"`, `"hint counts live, asking, open from
   status --json's activity"`, `"fleet sync is unknown"`) and 3b.2's four. For them: a stub `tests/stub/agent-deck`
   (no args: a TUI loop that, while `$FLEET_FIXTURES/deck-attach` holds `<ip> <id>`, runs `ssh -t agentvm@<ip>
   agent-deck session attach <id>`; else logs `agent-deck $*` to `deck.log`); the ssh stub: a `*'session attach '*`
   case that waits while `deck-attach` names it, `'bash -s -- inbox-json'` printing `fleet:hops` then
   `$fx/hops-<dest>`, `'test -x .local/bin/agent-deck'` exiting 0; a fixture deck config with `[remotes.thinkrepos]`
   (192.168.123.51) and `[remotes.repos]` (192.168.122.51); the fixture `status.sh` printing `$FLEET_FIXTURES/
   status-json` when it exists (for a probe-script hops test, with a stub `$HOME/.local/bin/agent-deck`).
2. **Texts in the same change:** `tmux.conf` (drop the `F` binding, the session-pane parts of `pane-border-format`
   and `@fleet-host-colour` in the window-status formats; keep the btop pane's border and the resurrect hook),
   `README.md` (fleet section, keys table, *Update and run*: no prefix F, run `fleet` from outside the session once
   after the pull to rebuild), `AGENTS.md` *Project in brief* (no version stamps/prefix F), `agent-deck/dot-config/
   agent-deck/config.toml` (`[remotes.repos]`, `host = "agentvm@192.168.122.51"`), the spec
   `docs/superpowers/specs/2026-11-05-tmux-fleet-design.md` where it describes sync/panes (or a clarification
   pointing to agent-methodology D20). D20's grep for the PR body.
3. Verify (`bats tests/`, shellcheck), commit `fleet: layout C whole, the session windows go (agent-methodology D20)`
   (3b.1 and 3b.2 land together; say so in the PR body), local review (subagents), address findings.
4. Gate on PR #7 for the user's laptop try (3b.2 step 1, 3b.3 step 1: `focus --remote --attach` opens a remote
   session? which TUI was attached; the look with both guests; am-unattended in deck's rows) per
   development-workflow.md *Gates*. If no answer, the ruling is the fallback: `FOLLOW_ARGS=()` (select only), in the
   PR body. Then merge and 3b.3 step 2 in agent-methodology (the previous handoff's *At the end*).

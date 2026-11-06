# tmux fleet view: observing agent sessions across hosts

**Status:** approved by the user, 2026-11-05. **Repos touched:** `dotfiles` (slices 1–2), `nixed` (slice 3).
`agent-methodology` is consumed, not changed.

**Who reads it:** the plan's author, each slice's implementer and reviewers, and the user, who approves the
decisions table.

**Problem.** Agent sessions run inside microVM guests (`agentvm-repos` on host `nixos`, `thinkrepos` on host
`thinkcentre`, more later), each under `dtach`, each guest with its own agent-methodology supervisor. The user
drives both hosts from an Arch laptop on the tailnet, and has no single place to see which agents are running,
which are stalled or blocked, or to jump into one. The host tmux config is also kept by hand in two copies
(this repo's `tmux` package and nixed's `programs.tmux`), which have already drifted (the OSC 52 commit is only
here).

**Decision.** This repo becomes the single source of the tmux config, with plugins (sessionx,
extrakto, yank, resurrect, continuum) and its own gruvbox theme, and gains a bash tool, `fleet`, that builds one tmux session on the
laptop: window 1 is an overview of every guest's `status.sh`, then one window per attachable agent session (named
for its repo, coloured for its host) holding its interactive pane (`ssh -t` + `dtach -a`). It discovers hosts' guests live from
`/etc/agentvm/projects.json`, reads each guest's sessions from the supervisor's own `status.sh --json`, syncs on
a key (never on its own), and shows a cached status-bar hint when the layout is out of date. The same tool runs
on a host as `fleet --local`, for that host's guests only. nixed stops carrying its own copy: home-manager links
`tmux.conf` and `fleet` to the host's `~/repos/dotfiles` checkout (the repo is private, so no flake input), and
generates a `plugins.tmux` that loads the plugins from `pkgs.tmuxPlugins`.

## Decisions taken

| # | Decision | Section | Acceptance check |
|---|---|---|---|
| 1 | One tmux config, `tmux/dot-config/tmux/tmux.conf`, shared by the laptop and the hosts; plugins are loaded from a separate per-platform `plugins.tmux` it sources, so `tmux.conf` names neither TPM nor a Nix path | *Where things live* | `grep -nE 'tpm\|/nix/store' tmux/dot-config/tmux/tmux.conf` prints nothing; `tmux -L t -f tmux/dot-config/tmux/tmux.conf start-server \; show -g @sessionx-bind` works on the laptop and on `nixos` after slice 3 |
| 2 | The laptop gets plugins through TPM, from `tmux/dot-config/tmux/plugins.tmux`: tmux-sessionx, extrakto, tmux-yank, tmux-resurrect, tmux-continuum | *Plugins, keys, theme* | On the laptop after stow + `prefix I`: `tmux list-keys \| grep -E 'sessionx\|extrakto'` shows both bindings, and `tmux show -g @continuum-save-interval` prints `15` |
| 3 | nixed drops `programs.tmux` (it writes its own `tmux.conf`, which would clash with the link): `tmux`, `jq`, `fzf` go in `home.packages`; `tmux.conf` and `fleet` are `mkOutOfStoreSymlink`s into `~/repos/dotfiles`; `plugins.tmux` is generated with one `run-shell` per plugin from `pkgs.tmuxPlugins` | *Where things live* | In the VM: `grep -n 'programs.tmux' modules/home.nix` prints nothing. On `nixos` after switch: `readlink ~/.config/tmux/tmux.conf` points into `~/repos/dotfiles`; `grep -c '^run-shell' ~/.config/tmux/plugins.tmux` prints `6`; `tmux list-keys \| grep -E 'sessionx\|extrakto'` shows both |
| 4 | `fleet` discovers hosts from `~/.config/fleet/hosts` and each host's guests from `ssh theo@<host> cat /etc/agentvm/projects.json`; `--local` reads this machine's file and no hosts list | *Discovery* | bats: with a stub `ssh` serving two hosts' `projects.json`, `fleet ls` prints one line per guest with its host; with `--local` and `AGENTVM_PROJECTS=<fixture>`, only that file's guests |
| 5 | Each guest's sessions come from the `status.sh` and `AGENT_SUPERVISE_REPOS` its `agent-supervise` user unit names (`systemctl --user show -p ExecStart -p Environment`); a guest without the unit is shown as `no supervisor` | *Discovery* | bats: the stub returns a unit with `ExecStart=/workspace/agent-methodology/shared/claude/supervise.sh`; `fleet` runs `…/status.sh --json --no-forge` with that `AGENT_SUPERVISE_REPOS`; a stub with no unit gives the `no supervisor` line and exit 0 |
| 6 | Session `fleet` (`fleet-<host>` under `--local`): window 1 `overview` with one pane per guest, refreshing `fleet status <guest>` every 15 s, each row in its glyph's colour, its border naming the guest and its host (Clarifications 11, 13); then one window per attachable session, named for its repo and tagged with its host (Clarification 10), ordered by host then repo, a repo's windows side by side (Clarification 17) | *Layout* | bats on `tmux -L fleet-test`: from the fixtures, `list-windows -F '#W|#{@fleet-host}|#{window_panes}'` prints `overview|`, `nixed|nixos|1`, `nixed|nixos|1`, `agent-methodology|thinkcentre|1` in that order; `overview` has one pane per guest; a session a later sync adds goes right after its repo's last window; an older fleet's tiled window is broken up into one window per session, a shell opened in it staying |
| 7 | A session is attachable when its `continue` starts with `dtach -a`; it gets one pane running `ssh -t agentvm@<ip> dtach -a <sock> -e '^]' -r winch`, tagged `@fleet-entry=<entry>` and with its border's `@fleet-glyph`, `@fleet-colour`, `@fleet-branch`, `@fleet-live` (Clarification 10), retagged on each sync; every other row (own terminal, blocked, stopped) is only an overview row | *Layout* | bats: three rows (one `dtach -a`, one empty `continue`, one blocked) give exactly one pane, whose `#{@fleet-entry}` and `#{@fleet-branch}` match the first row (Clarification 1) |
| 8 | Sync is explicit (`prefix F` or `fleet sync`) and idempotent: it adds a pane for each attachable entry whose socket has none, closes every tagged pane whose attach has exited and every second pane on one socket, retags a live one whose entry is now blocked or stopped, never touches an untagged pane but the shell pane `prefix F` was pressed in, which attaches in place to the session a person started on its guest (Clarification 14), and prints what it did; between syncs, the hint loop only follows hops in the panes there are, in place (Clarification 16) | *Sync* | bats: a second sync on unchanged fixtures leaves `list-panes -a -F '#{pane_id}'` identical; adding one entry adds one pane; removing one closes it; an ended pane of a blocked entry is closed; of two live panes on one socket one is left; a pane made by hand in a fleet window survives both; `sync` prints `fleet: synced <s>, nothing to change` or what changed |
| 9 | One unreachable host or guest never fails a sync: ssh runs with `BatchMode=yes`, `ConnectTimeout=5`, guests in parallel, and the failure becomes one `unreachable` overview line | *Discovery* | bats: the stub fails for one guest; `fleet sync` exits 0, the other guest's panes exist, and `fleet status <failed>` prints `unreachable` |
| 10 | The status bar shows `fleet hint` from a cache file a background loop in the session refreshes every 20 s, so the bar never runs ssh: `<host> ●N ◆M  …  ↻K` in tmux styles (● live, ◆ a `kind` or `blocked`, hidden at 0; ↻ attachable entries with no pane, hidden at 0; the host in its tab colour) | *Hint* | bats: fixtures with 2 live, 1 stalled, 1 blocked on `nixos` and one unpaned attachable entry give `nixos ●3 ◆2  thinkcentre ●1  ↻1` with the styles stripped (Clarifications 2, 10); `fleet hint` with no cache prints nothing and exits 0 |
| 11 | Keys (prefix `C-b`, nothing existing rebound): `F` sync, `f` sessionx, `Tab` extrakto, `y` in copy mode tmux-yank; `C-]` detaches dtach in an agent pane, which closes it and leaves the agent running | *Plugins, keys, theme* | `tmux list-keys -T prefix` shows `F`, `f`, `Tab` bound as stated and `h j k l r c " %` unchanged; manual: `C-]` in an agent pane closes it, and the guest's `status.sh` still shows that session `alive` |
| 12 | Theme: gruvbox, written in `tmux.conf` (no theme plugin); `pane-border-status top` showing an agent pane's state emoji, branch and live value, an overview pane's guest in its host's colour with its counts (else the pane command); the focused pane's border is blue (Clarifications 10, 11) | *Plugins, keys, theme* | Early output (below): the user looks at the laptop session and can tell agent panes from their own shells |
| 13 | resurrect leaves `ssh` out of restored processes (its default) and continuum auto-restores on the laptop only; `fleet` rebuilds a fleet session it finds without its server-lifetime marker `@fleet-booted-<session>` (a restore into a new server), and leaves one with the marker alone (Clarification 3) | *Plugins, keys, theme* | bats: with the marker unset, `fleet up` rebuilds the session to the fresh layout and sets it; with it set, a window made by hand survives `fleet up`; `tmux show -g @continuum-restore` is `on` on the laptop and not `on` on `nixos` |
| 14 | `fleet doctor` checks each prerequisite (ssh to each host, ssh to each guest, the tailnet route to each guest subnet, `jq`, `fzf`, `dtach` on the guest) and names the one that fails | *Discovery* | bats: the stub refuses one guest's ssh; `fleet doctor` exits 1 and its output names that guest and `ssh agentvm@<ip>` |
| 15 | `fleet` uses only these `status.sh --json` fields: `repo`, `worktree`, `branch`, `live`, `state`, `kind`, `entry`, `continue` (and `unattended`, `started`, `prev`: Clarifications 14, 16); a missing field shows `?` and never stops a sync | *Contract consumed* | bats: a fixture row with no `kind` and no `branch` still gets its pane, with `@fleet-branch` `?` |

## Early output

The user's own fleet, on the laptop, after slice 2: `fleet` started with both hosts live, a screenshot or a
`tmux capture-pane` of the overview and of one agent window with its session attached. The user
judges whether the overview answers "what is running, what needs me" at a glance and whether agent panes are
distinguishable (decision 12). Slice 1 has its own smaller sample: the restyled bar and borders on the laptop.

## Where things live

**dotfiles**, `tmux` package (stowed on the laptop):

- `dot-config/tmux/tmux.conf`: today's settings, the theme, the keys, and `source-file -q
  ~/.config/tmux/plugins.tmux` last.
- `dot-config/tmux/plugins.tmux`: laptop only: `set -g @plugin …` for TPM and the six plugins, their options,
  `run ~/.config/tmux/plugins/tpm/tpm`.
- `dot-local/bin/fleet`: the tool.
- `dot-config/fleet/hosts`: one host per line, `nixos` and `thinkcentre`.
- `tests/fleet.bats` and `tests/fixtures/`: not stowed (outside the package).
- `README.md`: the Arch setup: `pacman -S tmux jq fzf xclip bash-bats`, clone TPM, stow `tmux`, `tailscale up
  --accept-routes`, the guest-key `~/.ssh/config` stanzas, `fleet doctor`.

**nixed** (slice 3):

- `modules/home.nix`: `programs.tmux` goes, since it generates `tmux.conf` itself and would collide with the link;
  `tmux`, `jq` and `fzf` go in `home.packages`. `xdg.configFile."tmux/tmux.conf".source` and
  `home.file.".local/bin/fleet".source` are `config.lib.file.mkOutOfStoreSymlink "/home/theo/repos/dotfiles/…"`.
  `xdg.configFile."tmux/plugins.tmux".text` sets the plugins' options (continuum's restore off) and has one
  `run-shell` per plugin, from `pkgs.tmuxPlugins.{tmux-sessionx,extrakto,yank,resurrect,continuum}`
  (attribute names and each plugin's `.tmux` entry path checked against nixpkgs in the plan).
- `docs/guides/tmux.md`: becomes a short host note pointing here for keys and `fleet`.
- `docs/guides/host-operations.md`, new-machine setup: clone dotfiles into `~/repos`.

Why symlinks, not a flake input: dotfiles is private, and a `nixos-rebuild` as root would need a GitHub token
to fetch it. A link to the checkout the host already has needs none, takes edits without a rebuild, and is the
same kind of hand-checked host path as nixed's `repoRoot`. The cost: a host without `~/repos/dotfiles` gets
dangling `tmux.conf` and `fleet` links, which the guide's setup step checks with `readlink -e` (`fleet doctor`
can't: it dangles too).

## Discovery

For each host in `~/.config/fleet/hosts` (or, under `--local`, this machine alone, from
`/etc/agentvm/projects.json` directly): read its `projects.json` (guest name, IP). For each guest, over
`ssh agentvm@<ip>`, read the `agent-supervise` unit's `ExecStart` and `Environment`, derive `status.sh` as
`$(dirname ExecStart)/status.sh`, and run it with `--json --no-forge` and that `AGENT_SUPERVISE_REPOS`. This is the
supervisor's own view by construction: no second list of repos to keep. `--no-forge` (agent-methodology #72)
skips the PR listings and gate labels, most of a run's time and no field fleet reads (decision 15): a blocked row
stays `state=blocked`, so the `◆` count is the same. The overview's table keeps the forge (its PR column).

All ssh calls: `-o BatchMode=yes -o ConnectTimeout=5`, guests in parallel (background jobs, one output file each
in a temporary directory under the session's state directory), then joined; a guest's probe runs under
`timeout` (`FLEET_PROBE_TIMEOUT`, 15 s). Hosts are read in parallel too, joined in the hosts file's order. The probes
and the hosts' `projects.json` reads share one ssh connection per destination (`ControlMaster=auto`,
`ControlPath=<state>/ssh/%C`, `ControlPersist` `FLEET_SSH_PERSIST`, 10m), so a sync or a refresh pays no handshake;
the attach panes never do, so a master's end can't take a pane with it. `FLEET_SSH_MUX=0` turns it off, as does a
state path too long for the 108-byte socket path. State lives in `${XDG_RUNTIME_DIR:-/tmp}/fleet-$UID/<session>/`:
`fleet.json`, `hint`, `hintloop.pid`, `sync.lock`. The laptop reaches guests directly over the tailnet routes each
host advertises; on a host, over its own bridge.

Guest ssh also adds `-o StrictHostKeyChecking=accept-new`, and `-i "$AGENTVM_KEY"` when that is set, else, under
`--local`, `-i ~/.agentvm/keys/id_ed25519` when it exists (the host's own agentvm key); never `IdentitiesOnly`.
On the laptop the key comes from `~/.ssh/config`: one stanza per guest subnet (`192.168.122.*` nixos,
`192.168.123.*` thinkcentre) naming `User agentvm` and a copy of that host's key; `fleet doctor` shows ssh's own
error for a guest it can't reach (Clarification 5).

## Layout

Session `fleet`, or `fleet-<host>` under `--local`.

- Window 1 `overview`: one pane per guest (tiled), each a loop of `fleet status <guest>` every 15 s: the
  guest's `status.sh` table, or `unreachable` / `no supervisor`. Its border names the guest in its host's colour,
  the host, the guest's `●N ◆M` (as the hint's) and its ip and last refresh (pane options `@fleet-guest`,
  `@fleet-guest-host`, `@fleet-guest-colour`, set by each sync, and `@fleet-summary`, set by the loop; not
  `@fleet-host`, which as a pane option would shadow the window's) (Clarification 11).
- One window per attachable row, ordered by host then repo (repo is the basename of the row's `repo`), so a
  repo's windows sit side by side; a session a later sync adds opens right after that host's last window for its
  repo (a repo new to the session, at the end). It is named for the repo and tagged `@fleet-host` and
  `@fleet-host-colour` (the host's place among fleet.json's sorted hosts picks it from aqua, orange, blue,
  purple), which the tab is drawn in. A window made before the tags, named `<host>·<repo>`, is renamed and
  tagged by the next sync, whether or not it adds a pane there (Clarification 11). A window an older fleet tiled
  several sessions in keeps its first agent pane; each other one moves to a window of its own right after it, in
  pane order, with the same name and tags, and a pane that isn't an agent's stays where it is (Clarification 17).
- Each attachable row (`continue` starts with `dtach -a`) is one pane: `ssh -t agentvm@<ip>` running the
  `continue` command with `-e '^]'` added, so dtach's detach key is `C-]` and `C-\` stays free. Pane options:
  `@fleet-entry` (the row's `entry`), `@fleet-glyph` and `@fleet-colour` (its `live` value's, *Plugins, keys,
  theme*), `@fleet-branch`, `@fleet-live`, `@fleet-sock` (`<ip> <sock>`, the dtach it attaches to).
- Non-attachable rows: a live session in someone's own terminal (`continue` empty), a blocked or stopped run.
  They appear only in the overview.

## Sync

`fleet sync` (bound to `prefix F`), and once on `fleet` start:

1. Discover (above).
2. For each attachable entry with no tagged pane: open a window for it, right after that host's last window for
   its repo (*Layout*). Last, after step 4's exception, break an older fleet's tiled window apart: each agent pane
   but its first to a window of its own (`break-pane -d -a`, so no pane restarts and the focus stays), counted as
   moved (Clarification 17).
3. For each tagged pane: an attach that has ended (the session ended, or the link was lost: ssh exited 255)
   marks the pane `@fleet-ended` and leaves it with its last screen and a `[fleet] session ended` or `[fleet]
   link lost` line, until the next sync closes it; if its entry is still attachable, a fresh attach replaces it.
   Before that, the hops are followed as the hint loop's tick follows them (*Hint*), so an ended pane whose session
   handed over to a new socket is respawned in place, not closed with a new pane added elsewhere (Clarification 16).
   A live pane whose entry is gone but whose `@fleet-sock` is a live entry's (a hop: `chain.sh` runs every hop of a
   chain in one dtach, each a new entry) is retagged with that entry and its tags, not replaced; a pane with no
   `@fleet-sock` (made before it existed) gets it from the `_attach <ip> <sock>` in its start command first. A
   socket keeps one pane: a second live one on it (it would mirror the first, scrolling included) is closed. A live
   pane whose entry is now blocked or stopped stays, its tags set to the new state; one whose entry is gone (or
   whose guest is unreachable this time) is kept as it is. A resurrect restore
   never reaches this step: `fleet` rebuilds a restored session (Clarification 3), and saves leave fleet's
   sessions out (Clarification 6).
4. Untagged panes and windows with neither `@fleet-host` nor a `<host>·<repo>` name are never touched, with one
   exception, before step 2: the pane `prefix F` was pressed in (`fleet sync -p <pane>`). When it is an untagged
   pane of this session (no `@fleet-entry`, no `@fleet-guest`) whose first `ssh` process, at or under the pane's,
   resolves (`ssh -G`'s `hostname`) to a guest's IP or name, it is respawned as that guest's newest (`started`)
   attended (`unattended` 0) attachable entry with no pane, tagged as any agent pane, in its own window; no such
   entry, and it is left as it is (Clarification 14).
5. Refresh the hint cache.
6. Bring forward what an older fleet left running, which a `git pull` does not change (Clarification 11): an overview
   pane without `@fleet-overview` 2 is respawned with the current loop, and a hint loop whose `hintloop.pid` has
   no version is replaced. The hint loop runs the fleet on disk for each refresh, so later pulls reach it.

One sync at a time per session (`flock -n` on its `sync.lock`): a second exits 0 and says one is running.
`prefix F` shows `fleet: syncing…` as it starts, and the line `sync` prints when it ends: `fleet: synced <s>, nothing
to change`, `fleet: synced <s>: 1 attached in this pane, 1 added, 2 closed, 1 followed a hop, 1 renamed, 2 moved to a window of its
own`, or why it did not run.

Nothing ever syncs on its own: panes never appear, move or close while the user types into an agent. What runs
on its own is narrower, the hint loop's following of hops in the panes there are, in place (*Hint*, Clarification 16).

## Hint

A background loop started with the session (`run-shell -b`, one per server, a pid file guards it) runs
discovery every 20 s and writes the session's `hint` (state directory above), removing it when the session ends.
`status-right` runs `fleet hint`, which only `cat`s that file, and only while its session exists. Format, in tmux styles: one `<host> ●N ◆M` group per host (the host in its tab colour, `◆M` left out at 0,
`<host> ✗` when unreachable), two spaces between, then `↻K` when attachable entries have no pane.

Each tick (`fleet _tick`) also follows hops in the panes there are, in place, under the sync's lock (`flock -n`:
while a sync holds it, the tick follows nothing and that sync does), discovery staying outside it so a `prefix F`
pressed meanwhile is not turned away (Clarification 16). A live pane whose entry is gone but whose `@fleet-sock` is
a live entry's is retagged onto it, as in *Sync* step 3. An ended pane whose entry has a successor, an attachable
row whose `prev` is the pane's run id (the entry's file name), on another socket with no pane (a hop or a resume
that got a dtach of its own: `next-session.sh` outside `chain.sh`, `--resume`, the supervisor's restart) is
respawned (`respawn-pane -k`) attached to it, where it is, and retagged. Every pane of an attachable entry gets
fresh tags. The tick adds no pane, closes none and moves none: a new session, a gone one, a second pane on a
socket, a lost link and a hop it can't see (two new sockets within one tick: rows show a worktree's newest entry
only) wait for `prefix F`. The loop's pid file carries version 4.

## Plugins, keys, theme

| Plugin | Why | Key / option |
|---|---|---|
| tmux-sessionx | fuzzy jump to any session/window with preview | `prefix f` (not its default `O`) |
| extrakto | pick hashes, paths, URLs, `#PR` from agent output | `prefix Tab` (its default) |
| tmux-yank | copy mode to the system clipboard on the laptop | `y` in copy mode; hosts keep OSC 52 (`set-clipboard on`) |
| tmux-resurrect | restore the user's own windows after a laptop reboot | `@resurrect-processes` without `ssh`; `@resurrect-hook-post-save-layout` drops `fleet`/`fleet-*` from each save (Clarification 6) |
| tmux-continuum | save every 15 min; auto-restore on the laptop only | `@continuum-restore on` in the laptop's `plugins.tmux` only |

Theme: gruvbox dark, set in `tmux.conf` itself, so the status line stays fleet's and the laptop and the hosts look
the same. `pane-border-status top`; the format shows an agent pane's state: its glyph, the branch bold (left out
when `?`), the `live` value dim, then its window's host in its colour (Clarifications 10, 11), or its entry while an older fleet's tags are on it; an overview pane's
guest (*Layout*); any other pane's command and directory (Clarification 4). The focused pane's border is blue.
fleet picks the glyph, one narrow character tmux draws in its colour, so it shows in colour with any font
(Clarification 11), the same as agent-methodology's `status.sh` table:

| `live` | glyph | colour |
|---|---|---|
| alive | `●` | green |
| waiting | `○` | yellow |
| stalled | `◐` | yellow |
| blocked… | `◆` | purple |
| dead, dead? | `✗` | red |
| done | `✓` | grey |
| gone | `∅` | grey |
| ended, `-`, `?` | `·` | grey |

## Contract consumed

From agent-methodology, as of its session-supervisor spec (`status.sh`, D18): `status.sh --json` prints an
array of rows with `repo`, `worktree`, `branch`, `live`, `state`, `kind`, `entry`, `continue`; `continue` is
`dtach -a <sock> -r winch` for a live run under dtach. And nixed's `agent-supervisor` extra defines the
`agent-supervise` user unit whose `ExecStart` is the supervising checkout's `supervise.sh`. `fleet` reads only
these. A row missing a field is shown with `?`; a `continue` of another shape is treated as not attachable.
Later: `unattended` and `started` (Clarification 14), and `prev`, the run id of the run a row's entry continues
(agent-methodology's status-chains, #86), which the tick follows (Clarification 16); a row without `prev` is no
pane's successor.

## Testing

- **dotfiles, every slice:** `bash -n` and `shellcheck` on `fleet`; `bats tests/fleet.bats`, which runs against a
  private tmux server (`tmux -L fleet-test`, killed in teardown) with a stub `ssh` first on `PATH` that answers
  from `tests/fixtures/` by host or IP and command. The checks in the decisions table are its cases.
- **Laptop, manual (slice 2):** `fleet doctor` passes; `fleet` shows both hosts; typing in an agent pane reaches
  the agent; `C-]` leaves it running; a session started in a guest afterwards shows as `↻1`, then as a pane after
  `prefix F`.
- **nixed (slice 3):** its *Setup* check in the VM; on the host, `nixos-rebuild build`, then after the user's
  switch, decision 3's check and `fleet --local` on `nixos`.

## Slices

1. **dotfiles: config and plugins.** `tmux.conf` restructured (decision 1), `plugins.tmux` with TPM (2), keys
   (11, minus `F`), theme (12), resurrect/continuum (13's options), README. Early output: the restyled laptop
   session.
2. **dotfiles: `fleet`.** Discovery, layout, sync, hint, doctor, `--local` (4–10, 13's re-adopt, 14, 15),
   `prefix F`, `fleet/hosts`, bats suite. Early output: the user's fleet (above).
3. **nixed: hosts use dotfiles.** `programs.tmux` replaced by links and Nix plugins (3), guide updates. Needs the user's
   `nixos-rebuild switch` on both hosts; `~/repos/dotfiles` cloned on `thinkcentre` first.

## Out of scope, and follow-ups

- **Agent sessions under tmux in the guests** (native read-only attach, scrollback) instead of dtach: an
  agent-methodology change of its own, if wanted later.
- **Marking the consumed `status.sh --json` fields as a stable interface**, with a test, in agent-methodology:
  optional, its own change; until then decision 15's tolerance covers drift.
- **Auto-sync**: rejected (panes would move under the user's typing); the hint replaces it. Narrowed by
  Clarification 16: the hint loop follows hops in the panes there are, in place, and nothing more.
- **Read-only agent panes**: rejected for now in favour of interactive attach with distinct borders.
- **Overview when every host is down**: its first pane is a `-` guest with nothing useful in it; show one line
  saying no host answered instead.
- **A cap on windows** (asked by the user after the first laptop run, with a per-window pane cap that Clarification
  17 made moot: a window holds one session): today nothing limits the number of agent windows. Wanted: a cap,
  showing only the most recent sessions (the rest stay in the overview, and the hint says how many are hidden). "Most recent" needs a time per entry, which none of the consumed `status.sh --json`
  fields (decision 15) carries: find one in `status.sh` or add it in agent-methodology first.

## Clarifications

1. **Pane title is `@fleet-title`, not `pane_title`** (decision 7) — `folded`. An agent CLI sets the terminal
   title itself, which overwrites `pane_title`; the border reads the tmux user option `@fleet-title` instead.
2. **Hint check string** (decision 10) — `folded`. The bats fixtures have, on `nixos`, two plain live rows (one
   under dtach, one in a person's terminal), one stalled and one blocked, plus a new attachable live row added
   after `up`; on `thinkcentre` one live row. That gives `nixos 3▶ 2⚠ · thinkcentre 1▶ 0⚠ · ↻1`.
3. **Restore rebuilds instead of replacing tagged panes** (decision 13) — `folded`. resurrect does not save tmux
   user options, so a restored pane is untagged and decision 8 would leave it alone forever. A global
   `@fleet-booted-<session>` set by `fleet up` lives only as long as the tmux server, so its absence on an
   existing fleet session means a restore; `fleet up` then kills and rebuilds that session. Windows of the user's
   own belong in other sessions.
4. **The accent is on the border title, not a per-pane border style** (decision 12) — `folded`. Adjacent panes share
   a border line, so a per-pane `pane-border-style` cannot mark one pane; `pane-border-format` colours the title
   of panes with `@fleet-entry` instead, which needs no per-pane setting from `fleet`.
5. **Guests are reached with their host's agentvm key** (decisions 4, 9, 14) — `folded`. Guests trust only the
   per-host key `~/.agentvm/keys/id_ed25519` and their host keys are in no `known_hosts`, so plain `BatchMode`
   ssh to a guest IP was refused. Guest ssh adds `StrictHostKeyChecking=accept-new` and an identity
   (`AGENTVM_KEY`, else the host's own under `--local`), never `IdentitiesOnly`, so the laptop's
   `~/.ssh/config` stanzas per guest subnet supply the key there. Rewritten in *Discovery*.
6. **resurrect saves leave fleet's sessions out** (decision 13) — `folded`. A restore adds panes into sessions
   that already exist, so one after `fleet` started its session left untagged shells and duplicate
   `<host>·<repo>` windows in it. `tmux.conf` sets `@resurrect-hook-post-save-layout` to a `sed` that deletes the
   `pane` and `window` lines of sessions `fleet` and `fleet-*` from the save file (resurrect appends the file's
   path; field 2 is the session). Rewritten in *Sync* and *Plugins, keys, theme*.
7. **A pane follows its socket across hops** (decisions 7, 8) — `folded`. Keyed by entry alone, a sync after a hop
   (new entry, same dtach) added a second pane on the same socket and left the old one attached forever. Panes now
   carry `@fleet-sock`; sync retags a live pane whose entry is gone onto the live entry on its socket, and the hint
   counts a socket with a pane as paned. Panes made before this change have no `@fleet-sock`, so each gets one
   duplicate on its first hop. Rewritten in *Layout* and *Sync*.
8. **Titles lead with a state icon** (decision 7) — `superseded by 10`. Asked by the user (2026-11-05) to make a pane's state
   readable at a glance: one icon per `live` value (🟢 alive, ⏳ waiting, 🟡 stalled, ✋ blocked, 🔴 dead, ⚫ ended,
   ✅ done, 👻 gone, none for `-`/`?`), each a single default-wide code point, since a VS16 emoji (`⚠️`, `⏹️`)
   misaligns tmux borders. agent-methodology's `status.sh` table uses the same icons. Sync now also retitles a pane
   whose entry is still attachable, so its icon follows `live` instead of keeping the one it was made with.
   Rewritten in decision 7. Superseded by Clarification 10.
9. **An ended pane closes; a socket has one pane** (decisions 7, 8) — `folded`. Reported by the user (2026-11-05):
   two live `impl/machine-3` panes on `agentvm-thinkrepos`, scrolling together, and a `session ended; prefix F
   syncs` pane that a sync left in place. The first was clarification 7's duplicate: the pane predated
   `@fleet-sock` and the chain hopped twice (a move, then a hand-off), and sync, keyed by entry, never closed the
   old live pane, whose stale `alive` title kept it looking current. Sync now reads a missing `@fleet-sock` from
   the pane's start command and closes a second live pane on one socket. The second was decision 8 as written: an
   ended pane whose entry was blocked or stopped stayed, retitled, until its row went away, which for a `dead` or
   `done` row can take days; it now closes, the overview still showing the state. `prefix F` had shown nothing at
   the end, so a sync that changed nothing (status.sh can take 13 s on a guest with many blocked rows) looked like
   none ran; it now shows the line `sync` prints. Rewritten in decision 8 and *Sync*.
10. **herdr-style glyphs, a gruvbox theme, no `·` in tabs** (decisions 6, 7, 10, 12) — `folded`. Asked by the user
   (2026-11-05): a gruvbox theme, better pane titles, no `·` divider in tab names, and icons like herdr's. herdr
   draws state as one narrow Unicode glyph (`●○◐✓×`) coloured by its theme, not as emoji or Nerd Font icons, so it
   needs no font change; Clarification 8's emoji were double-width and fixed-colour. fleet now tags each agent pane
   with a glyph, a gruvbox colour, its branch and live value (the guest dropped: the window already names host and
   repo), and `tmux.conf` draws them; windows are named for the repo alone and carry the host as `@fleet-host` and
   a colour (`@fleet-host-colour`: tmux resolves a pane option before a window one, so it cannot share
   `@fleet-colour`), which tabs and the hint use instead of `<host>·`. catppuccin is dropped for a gruvbox palette
   in `tmux.conf`, matching nvim and doom. agent-methodology's `status.sh` table (its PR #71) is to take the same
   glyphs. Rewritten in decisions 6, 7, 10, 12, *Layout*, *Hint* and *Plugins, keys, theme*.
11. **Emoji back, overview borders, an update that reaches running fleets** (decisions 6, 7, 8, 12) — `folded`.
   Reported by the user (2026-11-05) after updating the laptop: "it looks wrong", no glyphs, an agent window's
   panes with no titles, and the overview's titles unchanged. Reproduced in the VM by starting the pre-10 fleet with
   catppuccin, then `source-file` of the new config (their `prefix r`) and screenshots of real alacritty: the panes
   still carried the old tags, which the new border format drew as nothing; sync renamed a `<host>·<repo>` tab only
   when it added a pane there; the overview panes and the hint loop kept running the old fleet's code (a pull
   changes the file, not a running process), so the old `== guest` headers and `2▶ 2⚠` hint stayed. Now: the border
   falls back to the entry, a sync renames every such tab, respawns old overview panes and replaces an old hint
   loop, and the hint loop calls the fleet on disk. Overview borders take the herdr look (guest in its host's
   colour, host, `●N ◆M`, ip and time; the `==` header is gone). The user then chose the emoji over the glyphs
   ("let's use your original approach, i could even change terminal to make it look better"), as
   agent-methodology's `status.sh` table now does; the hint keeps `●`/`◆`. Truecolor was a suspect too: tmux 3.8
   with a current alacritty finds it by asking the terminal, and `terminal-features ",alacritty*:RGB"` covers an
   older pair. Then (same day) the user found no sign of which host an agent pane runs on, and a gap in the
   agent-methodology border, which was its `?` branch: the border now ends with the host in its colour and leaves
   a `?` branch out (`@fleet-branch` keeps it, decision 15). And the emoji showed without colour on the laptop:
   colour emoji come from the font, which fontconfig's fallback picks, not tmux. The user chose the glyphs again
   (tmux colours them, any font), so the emoji above lasted one day. Rewritten in decisions 6, 7, 8, 12, *Layout*, *Sync*
   and *Plugins, keys, theme*.
12. **Discover skips the forge** (decision 5) — `folded`. Reported by the user (2026-11-05): prefix F was slow.
   `status.sh --json` spent most of its time on forge calls one after another (13 s in all on agentvm-repos);
   agent-methodology #72 runs them at once and adds `--no-forge`, which discover now passes (the user: "let's do
   both"; a cache was rejected, it would show stale data). An older `status.sh` reads only its first argument, so
   `--json` stays first. Rewritten in decision 5 and *Discovery*.

13. **Overview rows in colour** (decision 6) — `folded`. Reported by the user (2026-11-06): "still no colors on the
   status from the fleet tmux session, i can see the glyphs not colors". `status.sh` colours only on a tty, and over
   `ssh … bash -s` its stdout is a pipe. fleet now colours the table itself (`colour_table`, from `live_look`'s
   colours, so the pane borders and the rows can't disagree): each row by its leading glyph, the header bold, the
   rule and the supervisor line grey, anything already coloured or not a table row as is. Forcing colour in
   `status.sh` over ssh was rejected: it would need an agent-methodology change and still use the basic ANSI colours,
   not fleet's gruvbox ones. The overview pane's version goes to 3, so a sync restarts the panes an older fleet
   started.

14. **The pane that ran `claudes -d` becomes its pane** (decision 8) — `folded`. Asked by the user (2026-11-06):
   after opening a pane, ssh-ing into a guest and running `claudes -d`, prefix F added the session's pane beside it,
   and the first pane had to be closed by hand. `claudes -d` now attaches in its own terminal once it has started the
   chain under `dtach` (nixed, agentvm), and prefix F passes its pane (`-p "#{pane_id}"`): a plain shell pane of the
   fleet session ssh'd into a guest is respawned as fleet's attach to that guest's newest attended session with no
   pane, so a later sync adds no second pane on its socket. Attended only: the supervisor's unattended sessions get
   their own panes, as before. A guest-side signal to the laptop's tmux, with no prefix F at all, was rejected: the
   guest can't reach it, a terminal title is overwritten by Claude Code, and ssh's source port need not survive the
   tailnet's NAT.

15. **Each guest's resources beside its status** (decision 6) — `folded`. Asked by the user (2026-11-06): "a nice
   bashtop or htop to the overview pane on the right side of the status … an overview of the resources, VM exhausted
   or not, by checking CPU, RAM, disk". Each overview pane gets a second pane to its right (`@fleet-res-guest`)
   running btop over ssh with only its cpu and mem boxes (mem holds the disks): btop's four boxes need 80x24, more
   than a pane beside a status table has (checked by rendering it: "Terminal size too small" at 79x23), and those two
   fit down to 70x20. Rendered at 200 columns, the status table runs to 110, so the resources pane is 72 wide and the
   status gets the rest (half each on a window too narrow for that). One row per guest, built with
   break-pane/even-vertical/join-pane: tiled pairs them only for two guests, and tmux 3.8 changed the layout
   string's format. Sync adds them to a fleet from before them; a guest with no btop gets htop.

16. **Panes follow hops between syncs** (decisions 8, 10) — `folded`. Reported by the user (2026-11-06): "when a pane
   hops then the pane on the tmux isn't updated and we have to manually do refresh again; panes should be updated
   to each hop when a session closes and is handed over, whether due to ctx or limit or whatever." A hop under one
   `chain.sh` (a hand-off, a usage-limit account move) is a new entry on the same dtach, so the attach went on but
   its border kept the old entry's tags until a sync; a hop or resume with a dtach of its own ended the attach, and
   the next sync closed that pane and added the successor's elsewhere. The hint loop's tick now follows both in place
   (*Hint*), and a sync does the same first (*Sync* step 3). This narrows the rejected auto-sync, not reverses it:
   nothing appears, closes or moves, and a respawned pane is one whose attach had already ended, so no typing goes
   astray. The successor link is `status.sh --json`'s `prev`, already there (agent-methodology #86), so that repo
   needs no change.

17. **Each session in a window of its own** (decision 6) — `folded`. Asked by the user (2026-11-06): "open another PR
   to have each session on a window and not split panes within one". A repo's window tiled every session in it, each
   pane smaller with every session added, until tmux refused the split. Sync now opens a window per attachable
   session, named for its repo and tagged with its host as before, right after that host's last window for the repo,
   so the tabs still group by host and repo; and it breaks an older fleet's tiled window apart (`break-pane`, the
   attaches going on, a hand-opened shell staying), so a `git pull` and one prefix F reach a running fleet. The
   pane cap of the follow-up *Caps* is moot; its window cap stays a follow-up. Rewritten in decision 6, *Layout* and
   *Sync* step 2.

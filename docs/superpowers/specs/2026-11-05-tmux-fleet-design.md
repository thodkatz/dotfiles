# tmux fleet view: observing agent sessions across hosts

**Status:** approved by the user, 2026-11-05. **Repos touched:** `dotfiles` (slices 1–2), `nixed` (slice 3).
`agent-methodology` is consumed, not changed. Since layout C (agent-methodology's D20) the session has two
windows, Agent Deck's TUI and an overview, and no sync: Clarification 20.

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
laptop: window `deck` runs Agent Deck's TUI, every guest one of its remotes, where a session is listed and attached;
window `overview` shows every guest's open inbox items and supervisor rows (Clarification 20). It discovers hosts' guests live from
`/etc/agentvm/projects.json`, reads each guest's sessions from the supervisor's own `status.sh --json`, and shows a
cached status-bar hint of what is live and what needs you. The same tool runs
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
| 6 | Session `fleet` (`fleet-<host>` under `--local`): window `deck` first when `agent-deck` is installed, running its TUI, then window `overview`, its loop and the first guest's btop beside; no other windows (Clarification 20) | *Layout* | bats: `"fleet start makes the deck and overview windows only"`: `list-windows -F '#W\|#{window_panes}'` prints `deck\|1`, `overview\|2`; without agent-deck, `overview` alone |
| 7 | A session is attached in deck's TUI (Enter on its row, over deck's own ssh to the guest), not in a fleet pane; window `overview` lists each guest's open inbox items and its status rows, `<branch> <mode> <activity> [kind] [gated #n]` (Clarification 20) | *Layout* | bats: `"overview lists both guests' open items and status rows"` prints both guests' blocks from the fixtures |
| 8 | No sync: `fleet sync` is an unknown command and `prefix F` is unbound. What moves on its own is one thing: when the TUI was attached to a session that handed off (a viewed hop) and is back on its list, the overview's loop opens the successor in it, once (*Hops*, Clarification 20) | *Hops* | bats: `"fleet sync is unknown"` (exit 2, usage); `"a viewed hop opens its successor in the TUI once"`, `"an unviewed hop moves nothing"`, `"a hop this TUI wasn't attached to moves nothing"`, `"two hops in a row are followed in order"`, `"a hop reported while its attach is still open is followed once it ends"`, `"a TUI that left its session live is not moved by its later hop"`, `"a focus --attach that fails selects the successor instead"` |
| 9 | One unreachable host or guest never fails `fleet up` or a round: ssh runs with `BatchMode=yes`, `ConnectTimeout=5`, guests in parallel, and the failure becomes one `unreachable` overview line | *Discovery* | bats: the stub fails for one guest; `fleet up` exits 0, and `fleet status <failed>` prints `unreachable` |
| 10 | The status bar shows `fleet hint` from a cache file the overview's loop rewrites every 30 s, so the bar never runs ssh: `<host> ●N ◆M ✉I` per host in tmux styles (● a row whose `activity` is working, idle or asking; ◆ asking, hidden at 0; ✉ the guests' open inbox items, hidden at 0; the host in its colour; `✗` unreachable) | *Hint* | bats: `"hint counts live, asking, open from status --json's activity"`; from the fixtures `nixos ●3 ◆1  thinkcentre ●1 ✉1` with the styles |
| 11 | Keys (prefix `C-a`, `C-a C-a` sends it, so the guest's tmux keeps `C-b`; nothing else rebound): `f` sessionx, `Tab` extrakto, `y` in copy mode tmux-yank; fleet binds none (deck's own keys attach and detach) (Clarification 22) | *Plugins, keys, theme* | `tmux show -g prefix` prints `prefix C-a`; `tmux list-keys -T prefix` shows `C-a` as `send-prefix`, `f`, `Tab` bound as stated and `h j k l r c " %` unchanged |
| 12 | Theme: gruvbox, written in `tmux.conf` (no theme plugin); `pane-border-status top` naming fleet's overview and resources panes, else the pane's command and directory; the focused pane's border is blue | *Plugins, keys, theme* | Early output (below): the user looks at the laptop session and can tell fleet's panes from their own shells |
| 13 | resurrect leaves `ssh` out of restored processes (its default) and continuum auto-restores on the laptop only; `fleet` rebuilds a fleet session it finds without its server-lifetime marker `@fleet-booted-<session>` (a restore into a new server), and leaves one with the marker alone (Clarification 3), unless it was built without deck (`@fleet-nodeck`) and deck is now installed (Clarification 21); a deck window closed since is put back alone, first, the other windows kept (Clarification 23) | *Plugins, keys, theme* | bats: with the marker unset, `fleet up` rebuilds the session to the fresh layout and sets it; with it set, a window made by hand survives `fleet up`; `"up: a session built without deck gets the deck window once deck is installed, and keeps it after"`; `tmux show -g @continuum-restore` is `on` on the laptop and not `on` on `nixos` |
| 14 | `fleet doctor` checks each prerequisite (`tmux`, `jq`, `ssh`; this machine's `agent-deck`: on PATH, at `agent-deck-install`'s pin, with its config, `ok … off` when `FLEET_DECK_CMD` is empty (Clarification 21); ssh to each host, the tailnet route to each guest, ssh to each guest and `agent-deck` in its `~/.local/bin`) and names the one that fails | *Discovery* | bats: the stub refuses one guest's ssh; `fleet doctor` exits 1 and its output names that guest and `ssh agentvm@<ip>`; `"doctor: this machine's agent-deck, missing, off the pin or without its config, fails and names the fix"`, `"doctor: the pin is agent-deck-install's, in the checkout fleet runs from"` |
| 15 | `fleet` uses only these `status.sh --json` fields: `repo`, `worktree`, `branch`, `state`, `kind`, `mode`, `activity`, `gate`, `deck_id`, `prev`; a missing field shows `?` (or `-` for activity) and never stops a round | *Contract consumed* | bats: `"overview lists both guests' open items and status rows"` (fixtures in 3a's shape), `"overview: a row missing fields shows ? and -"` |

## Early output

The user's own fleet, on the laptop: `fleet` started with both hosts live, a screenshot or a `tmux capture-pane`
of the overview and of the deck window with a session attached. The user judges whether the overview answers "what
is running, what needs me" at a glance and whether fleet's panes are told apart from their own shells (decision 12).
(Before layout C, after slice 2, this was the overview and one agent window; Clarification 20.) Slice 1 has its own smaller sample: the restyled bar and borders on the laptop.

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
  agent-deck: home-manager links its config and runs `agent-deck-install` from the checkout (nixed's
  `change/host-agent-deck`, Clarification 21).
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
and `◆` counts a row's `activity` (decision 10), which the forge doesn't touch. `fleet status <guest>` keeps the
forge (its PR column).

All ssh calls: `-o BatchMode=yes -o ConnectTimeout=5`, guests in parallel (background jobs, one output file each
in a temporary directory under the session's state directory), then joined; a guest's probe runs under
`timeout` (`FLEET_PROBE_TIMEOUT`, 15 s). Hosts are read in parallel too, joined in the hosts file's order. The probes
and the hosts' `projects.json` reads share one ssh connection per destination (`ControlMaster=auto`,
`ControlPath=<state>/ssh/%C`, `ControlPersist` `FLEET_SSH_PERSIST`, 10m), so a round or a refresh pays no handshake;
the btop pane never does, so a master's end can't take it with it. `FLEET_SSH_MUX=0` turns it off, as does a
state path too long for the 108-byte socket path. State lives in `${XDG_RUNTIME_DIR:-/tmp}/fleet-$UID/<session>/`:
`fleet.json`, `hint`, `deck-attached`, `hops-followed`. The laptop reaches guests directly over the tailnet routes each
host advertises; on a host, over its own bridge.

Guest ssh also adds `-o StrictHostKeyChecking=accept-new`, and `-i "$AGENTVM_KEY"` when that is set, else, under
`--local`, `-i ~/.agentvm/keys/id_ed25519` when it exists (the host's own agentvm key); never `IdentitiesOnly`.
On the laptop the key comes from `~/.ssh/config`: one stanza per guest subnet (`192.168.122.*` nixos,
`192.168.123.*` thinkcentre) naming `User agentvm` and a copy of that host's key; `fleet doctor` shows ssh's own
error for a guest it can't reach (Clarification 5).

## Layout

Session `fleet`, or `fleet-<host>` under `--local`, built by `fleet` (or `fleet up`) and marked
`@fleet-booted-<session>` = `c`; a session without that value (resurrect's, or an older fleet's per-session windows)
is killed and rebuilt, and an older fleet's hint loop (`hintloop.pid`) stopped. So is one built without deck (session
option `@fleet-nodeck` 1) once deck is on PATH. A deck window closed later (the TUI quit) is put back by the next
`fleet`, alone and first, the session's other windows kept (Clarification 23).

- Window `deck`, first, when `agent-deck` (`FLEET_DECK_CMD`) is installed: its TUI, run with `TMUX` unset and
  `AGENT_DECK_ALLOW_OUTER_TMUX=1`, the guests its `[remotes.<name>]` (the laptop's deck config); window option
  `@fleet-deck` 1. Without it (`FLEET_DECK_CMD` set but not on PATH) `fleet` says so on stderr, naming
  `agent-deck-install`, and builds the overview alone.
- Window `overview`: a loop (`@fleet-overview` 1) that every `FLEET_OVERVIEW_INTERVAL` (30 s) runs one round with
  the `fleet` on disk (`fleet _round`), so a pull needs no restart: discover, write the hint, follow the hops, print
  per guest its name and host, each open inbox item (`✉ #<n> <kind> <branch>`, then its `continue`, or what it
  needs), and its status rows, one line each: branch (else the worktree's last part), mode, activity (`-` when
  none), kind and `gated #<n>` when set; `✗ unreachable` for a guest or host that didn't answer. To its right, 72
  columns, the first guest's btop over ssh (`@fleet-res-guest`).

## Hops

The TUI follows a hop it watched (agent-methodology D20, Clarification 5 there). The probe adds, after status.sh's
JSON, a `fleet:hops` line and one `<old id> <successor id> <old's tmux session>` line per row whose `prev` names an
archived deck session marked `am.viewed=1`. Each round, fleet reads what the deck pane is attached to: the first ssh
under its process whose words include the word `attach`, its destination resolved by `ssh -G` to a guest; it keeps
the last one seen in `deck-attached`, kept while the TUI is on its list, until that session shows live (`activity`
working, idle or asking) on its guest with nothing attached: the user left it, so its later hop isn't this TUI's. A
hop whose old id or tmux session is in that record, on that guest, while the TUI is attached to nothing, runs
`agent-deck session focus --remote <name> <successor> --attach` (`<name>` the remote deck's config gives that guest;
when that fails, once more without `--attach`, the cursor on the successor), and the record moves to the
successor, so a chain is followed in order. A hop whose old session the TUI is still attached to waits a round.
Each hop is acted on once (`hops-followed`, the newest 200), followed or not, and each decision is a line in
`follow.log`.

## Hint

`status-right` runs `fleet hint`, which only `cat`s the session's `hint` file, and only while its session exists;
the overview's round rewrites it, and `fleet hint --refresh` rediscovers. Format, in tmux styles: one `<host> ●N ◆M
✉I` group per host (the host in its colour, `◆M` and `✉I` left out at 0; `<host> ✗` when unreachable), two spaces
between. `●` counts rows whose `activity` is working, idle or asking, `◆` asking, `✉` the guests' open inbox items.

## Plugins, keys, theme

| Plugin | Why | Key / option |
|---|---|---|
| tmux-sessionx | fuzzy jump to any session/window with preview | `prefix f` (not its default `O`) |
| extrakto | pick hashes, paths, URLs, `#PR` from agent output | `prefix Tab` (its default) |
| tmux-yank | copy mode to the system clipboard on the laptop | `y` in copy mode; hosts keep OSC 52 (`set-clipboard on`) |
| tmux-resurrect | restore the user's own windows after a laptop reboot | `@resurrect-processes` without `ssh`; `@resurrect-hook-post-save-layout` drops `fleet`/`fleet-*` from each save (Clarification 6) |
| tmux-continuum | save every 15 min; auto-restore on the laptop only | `@continuum-restore on` in the laptop's `plugins.tmux` only |

Theme: gruvbox dark, set in `tmux.conf` itself, so the status line stays fleet's and the laptop and the hosts look
the same. `pane-border-status top`; the format names fleet's overview pane and its resources pane's guest, and shows
any other pane's command and directory (Clarification 4). The focused pane's border is blue.

## Contract consumed

From agent-methodology: `status.sh --json` (its slice 3a, D20) prints an array of rows with `repo`, `worktree`,
`branch`, `state`, `kind`, `mode`, `activity`, `gate`, `deck_id`, `prev`, among others fleet ignores; on a guest, deck's
`list --json` (`id`, `archived`, `tmux_session`) and `session annotate <id> --json` (`hints["am.viewed"]`) for the
hops. And nixed's `agent-supervisor` extra defines the `agent-supervise` user unit whose `ExecStart` is the supervising
checkout's `supervise.sh`. A row missing a field is shown with `?`.

## Testing

- **dotfiles, every slice:** `bash -n` and `shellcheck` on `fleet`; `bats tests/fleet.bats`, which runs against a
  private tmux server (`tmux -L fleet-test`, killed in teardown) with a stub `ssh` first on `PATH` that answers
  from `tests/fixtures/` by host or IP and command. The checks in the decisions table are its cases.
- **Laptop, manual (slice 2):** `fleet doctor` passes; `fleet` shows both hosts; deck's TUI attaches a session and
  follows its hop (Clarification 20).
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

- **Marking the consumed `status.sh --json` fields as a stable interface**, with a test, in agent-methodology:
  optional, its own change; until then decision 15's tolerance covers drift.

## Clarifications

1. **Pane title is `@fleet-title`, not `pane_title`** (decision 7) — `superseded by 20`. An agent CLI sets the terminal
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
7. **A pane follows its socket across hops** (decisions 7, 8) — `superseded by 20`. Keyed by entry alone, a sync after a hop
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
9. **An ended pane closes; a socket has one pane** (decisions 7, 8) — `superseded by 20`. Reported by the user (2026-11-05):
   two live `impl/machine-3` panes on `agentvm-thinkrepos`, scrolling together, and a `session ended; prefix F
   syncs` pane that a sync left in place. The first was clarification 7's duplicate: the pane predated
   `@fleet-sock` and the chain hopped twice (a move, then a hand-off), and sync, keyed by entry, never closed the
   old live pane, whose stale `alive` title kept it looking current. Sync now reads a missing `@fleet-sock` from
   the pane's start command and closes a second live pane on one socket. The second was decision 8 as written: an
   ended pane whose entry was blocked or stopped stayed, retitled, until its row went away, which for a `dead` or
   `done` row can take days; it now closes, the overview still showing the state. `prefix F` had shown nothing at
   the end, so a sync that changed nothing (status.sh can take 13 s on a guest with many blocked rows) looked like
   none ran; it now shows the line `sync` prints. Rewritten in decision 8 and *Sync*.
10. **herdr-style glyphs, a gruvbox theme, no `·` in tabs** (decisions 6, 7, 10, 12) — `folded`, its pane tags and window colours superseded by 20. Asked by the user
   (2026-11-05): a gruvbox theme, better pane titles, no `·` divider in tab names, and icons like herdr's. herdr
   draws state as one narrow Unicode glyph (`●○◐✓×`) coloured by its theme, not as emoji or Nerd Font icons, so it
   needs no font change; Clarification 8's emoji were double-width and fixed-colour. fleet now tags each agent pane
   with a glyph, a gruvbox colour, its branch and live value (the guest dropped: the window already names host and
   repo), and `tmux.conf` draws them; windows are named for the repo alone and carry the host as `@fleet-host` and
   a colour (`@fleet-host-colour`: tmux resolves a pane option before a window one, so it cannot share
   `@fleet-colour`), which tabs and the hint use instead of `<host>·`. catppuccin is dropped for a gruvbox palette
   in `tmux.conf`, matching nvim and doom. agent-methodology's `status.sh` table (its PR #71) is to take the same
   glyphs. Rewritten in decisions 6, 7, 10, 12, *Layout*, *Hint* and *Plugins, keys, theme*.
11. **Emoji back, overview borders, an update that reaches running fleets** (decisions 6, 7, 8, 12) — `superseded by 20`.
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

13. **Overview rows in colour** (decision 6) — `superseded by 20`. Reported by the user (2026-11-06): "still no colors on the
   status from the fleet tmux session, i can see the glyphs not colors". `status.sh` colours only on a tty, and over
   `ssh … bash -s` its stdout is a pipe. fleet now colours the table itself (`colour_table`, from `live_look`'s
   colours, so the pane borders and the rows can't disagree): each row by its leading glyph, the header bold, the
   rule and the supervisor line grey, anything already coloured or not a table row as is. Forcing colour in
   `status.sh` over ssh was rejected: it would need an agent-methodology change and still use the basic ANSI colours,
   not fleet's gruvbox ones. The overview pane's version goes to 3, so a sync restarts the panes an older fleet
   started.

14. **The pane that ran `claudes -d` becomes its pane** (decision 8) — `superseded by 20`. Asked by the user (2026-11-06):
   after opening a pane, ssh-ing into a guest and running `claudes -d`, prefix F added the session's pane beside it,
   and the first pane had to be closed by hand. `claudes -d` now attaches in its own terminal once it has started the
   chain under `dtach` (nixed, agentvm), and prefix F passes its pane (`-p "#{pane_id}"`): a plain shell pane of the
   fleet session ssh'd into a guest is respawned as fleet's attach to that guest's newest attended session with no
   pane, so a later sync adds no second pane on its socket. Attended only: the supervisor's unattended sessions get
   their own panes, as before. A guest-side signal to the laptop's tmux, with no prefix F at all, was rejected: the
   guest can't reach it, a terminal title is overwritten by Claude Code, and ssh's source port need not survive the
   tailnet's NAT.

15. **Each guest's resources beside its status** (decision 6) — `folded`, its one btop per guest superseded by 20 (the first guest's only). Asked by the user (2026-11-06): "a nice
   bashtop or htop to the overview pane on the right side of the status … an overview of the resources, VM exhausted
   or not, by checking CPU, RAM, disk". Each overview pane gets a second pane to its right (`@fleet-res-guest`)
   running btop over ssh with only its cpu and mem boxes (mem holds the disks): btop's four boxes need 80x24, more
   than a pane beside a status table has (checked by rendering it: "Terminal size too small" at 79x23), and those two
   fit down to 70x20. Rendered at 200 columns, the status table runs to 110, so the resources pane is 72 wide and the
   status gets the rest (half each on a window too narrow for that). One row per guest, built with
   break-pane/even-vertical/join-pane: tiled pairs them only for two guests, and tmux 3.8 changed the layout
   string's format. Sync adds them to a fleet from before them; a guest with no btop gets htop.

16. **Panes follow hops between syncs** (decisions 8, 10) — `superseded by 20`. Reported by the user (2026-11-06): "when a pane
   hops then the pane on the tmux isn't updated and we have to manually do refresh again; panes should be updated
   to each hop when a session closes and is handed over, whether due to ctx or limit or whatever." A hop under one
   `chain.sh` (a hand-off, a usage-limit account move) is a new entry on the same dtach, so the attach went on but
   its border kept the old entry's tags until a sync; a hop or resume with a dtach of its own ended the attach, and
   the next sync closed that pane and added the successor's elsewhere. The hint loop's tick now follows both in place
   (*Hint*), and a sync does the same first (*Sync* step 3). This narrows the rejected auto-sync, not reverses it:
   nothing appears, closes or moves, and a respawned pane is one whose attach had already ended, so no typing goes
   astray. The successor link is `status.sh --json`'s `prev`, already there (agent-methodology #86), so that repo
   needs no change.

17. **Each session in a window of its own** (decision 6) — `superseded by 20`. Asked by the user (2026-11-06): "open another PR
   to have each session on a window and not split panes within one". A repo's window tiled every session in it, each
   pane smaller with every session added, until tmux refused the split. Sync now opens a window per attachable
   session, named for its repo and tagged with its host as before, right after that host's last window for the repo,
   so the tabs still group by host and repo; and it breaks an older fleet's tiled window apart (`break-pane`, the
   attaches going on, a hand-opened shell staying), so a `git pull` and one prefix F reach a running fleet. The
   pane cap of the follow-up *Caps* is moot; its window cap stays a follow-up. Rewritten in decision 6, *Layout* and
   *Sync* step 2.
18. **A window says what its session works on** (decision 6) — `superseded by 20`. Asked by the user (2026-11-07): a fleet
   window's title should say what its session works on, not only its repo; every agent-methodology window read
   `agent-methodology`, the branch only on the pane border. Windows are now named `<repo>/<branch>`, the branch's
   last `/`-part (`change/accounts-view-2` gives `agent-methodology/accounts-view-2`), at most 24 characters, and
   renamed on every sync and tick when the branch changes, a hop's or the worktree's (agent-methodology's
   `status.sh` follows a session that moved worktrees, branch `change/status-follow-hop-worktree`). `/`, not `·`:
   Clarification 10 dropped `·` from tabs, and `<host>·<repo>` is the old name the migration renames. With the name
   no longer the repo, a window carries `@fleet-repo`, which groups a repo's windows, and `@fleet-name`, the name
   fleet gave it, so one a person renamed is left alone. Rewritten in decision 6, *Layout* and *Sync* step 2.
19. **Layout C's overview and hint** (decisions 6, 10) — `folded`, its window name `overview2` superseded by 20. agent-methodology's Agent Deck adoption (its
   #127, D20; slice 0, dotfiles PR #6) adds layout C beside fleet's own windows: window `deck` (Agent Deck's TUI,
   the guests as its remotes) and `overview2` (each guest's open inbox items, read from the item files, which carry
   `continue`, unlike INBOX.md's lines). Discovery's probe reads the inbox in the same ssh (mode `inbox-json`), so
   the hint gains `✉I` per host from it; live and asking come from a row's `activity` once status.sh reports deck's,
   the old rules until then; the overview borders' `●N ◆M` count the same way. Rewritten in decisions 6 and 10
   (their checks gain `overview2|` and `✉1`), *Layout* and *Hint*.
20. **Layout C whole: the session windows and sync go** (decisions 6, 7, 8, 10, 11, 12, 14, 15) — `folded`.
   agent-methodology's Agent Deck adoption (D20, slice 3b) makes deck's TUI the place to attach a session, so fleet's
   own session machinery goes: the per-session windows and their panes, `fleet sync` and `prefix F`, the hint loop and
   its hop following in panes, the per-guest overview panes and their colours. Window `overview2` takes the name
   `overview`; its loop writes the hint, from the rows' `activity` only. In their place, the TUI follows a hop it was
   attached to (*Hops*). This supersedes Clarifications 1, 7, 9, 11, 13, 14, 16, 17 and 18, and in part 10 (pane
   tags, window colours), 15 (one btop per guest) and 19 (`overview2`), which stay as written; the out-of-scope items
   about auto-sync, read-only panes, the all-down overview pane, a window cap and agent sessions under tmux (deck's, now) went with them. The user approved
   the change in agent-methodology's spec (D20). Rewritten in the decisions named, *Layout*, *Hops*, *Hint*, the theme and *Contract
   consumed*; *Sync* is gone.
21. **Deck on this machine: doctor checks it; a deck-less session is rebuilt once deck is installed** (decisions 6, 13,
   14) — `folded`; its closed deck window `superseded by 23`. Reported from thinkcentre (2026-11-08): `fleet --local` built the overview alone and `fleet --local
   doctor` passed, with agent-deck not installed on the host; nothing said so. Doctor now checks this machine's
   agent-deck (on PATH, `--version` at the pin in `agent-deck-install` of the checkout fleet runs from, its config), and
   `fleet up` says on stderr when there is no deck window. A session built without deck carries `@fleet-nodeck` and is
   rebuilt once deck is on PATH, killing the user's own windows in it as a layout change does (decision 13); a deck
   window closed later is not, since every `fleet` would then wipe the session. The guests' agent-deck keeps its
   presence check only, with no pin. The hosts get deck from nixed (`change/host-agent-deck`). Rewritten in decisions
   13 and 14, *Layout* and the nixed list. dotfiles PR #8.
22. **Prefix `C-a`** (decision 11) — `folded`. Asked by the user (2026-11-10), after an attach from the deck window
   broke on the laptop: "yes let's do the c-a". The outer tmux and the guest's (where deck attaches a session) both had
   `C-b`, so reaching the attached session took `C-b C-b` (agent-methodology's deck trial, `session-2-notes.md`), and
   agent-methodology's layout C had drawn the laptop's outer tmux with `C-a`. The outer prefix is now `C-a`, with `C-a
   C-a` sending it; the guests keep tmux's default. Rewritten in decision 11 and `README.md`'s tmux section.
23. **A closed deck window comes back with the next `fleet`** (decision 13) — `folded`. Reported from nixos
   (2026-11-10): `fleet --local` showed only the overview. `q` in deck's list quits the TUI, which closes its window,
   and Clarification 21 had left a closed one closed, so only a session rebuilt by hand got it back. Rebuilding the
   session would wipe the user's windows, but nothing needs rebuilding: `fleet` adds the deck window alone, first,
   when deck is on PATH and no window carries `@fleet-deck`. Rewritten in decision 13, *Layout* and `README.md`.

# tmux fleet view: observing agent sessions across hosts

**Status:** draft, awaiting the user's review. **Repos touched:** `dotfiles` (slices 1–2), `nixed` (slice 3).
`agent-methodology` is consumed, not changed.

**Who reads it:** the plan's author, each slice's implementer and reviewers, and the user, who approves the
decisions table.

**Problem.** Agent sessions run inside microVM guests (`agentvm-repos` on host `nixos`, `thinkrepos` on host
`thinkcentre`, more later), each under `dtach`, each guest with its own agent-methodology supervisor. The user
drives both hosts from an Arch laptop on the tailnet, and has no single place to see which agents are running,
which are stalled or blocked, or to jump into one. The host tmux config is also kept by hand in two copies
(this repo's `tmux` package and nixed's `programs.tmux`), which have already drifted (the OSC 52 commit is only
here).

**Decision.** This repo becomes the single source of the tmux config, with plugins (catppuccin, sessionx,
extrakto, yank, resurrect, continuum), and gains a bash tool, `fleet`, that builds one tmux session on the
laptop: window 1 is an overview of every guest's `status.sh`, then one window per host·repo with one
interactive pane per attachable agent session (`ssh -t` + `dtach -a`). It discovers hosts' guests live from
`/etc/agentvm/projects.json`, reads each guest's sessions from the supervisor's own `status.sh --json`, syncs on
a key (never on its own), and shows a cached status-bar hint when the layout is out of date. The same tool runs
on a host as `fleet --local`, for that host's guests only. nixed stops carrying its own copy: home-manager links
`tmux.conf` and `fleet` to the host's `~/repos/dotfiles` checkout (the repo is private, so no flake input), and
generates a `plugins.tmux` that loads the plugins from `pkgs.tmuxPlugins`.

## Decisions taken

| # | Decision | Section | Acceptance check |
|---|---|---|---|
| 1 | One tmux config, `tmux/dot-config/tmux/tmux.conf`, shared by the laptop and the hosts; plugins are loaded from a separate per-platform `plugins.tmux` it sources, so `tmux.conf` names neither TPM nor a Nix path | *Where things live* | `grep -nE 'tpm\|/nix/store' tmux/dot-config/tmux/tmux.conf` prints nothing; `tmux -L t -f tmux/dot-config/tmux/tmux.conf start-server \; show -g @catppuccin_flavor` works on the laptop and on `nixos` after slice 3 |
| 2 | The laptop gets plugins through TPM, from `tmux/dot-config/tmux/plugins.tmux`: catppuccin, tmux-sessionx, extrakto, tmux-yank, tmux-resurrect, tmux-continuum | *Plugins, keys, theme* | On the laptop after stow + `prefix I`: `tmux list-keys \| grep -E 'sessionx\|extrakto'` shows both bindings, and `tmux show -g @continuum-save-interval` prints `15` |
| 3 | nixed drops `programs.tmux` (it writes its own `tmux.conf`, which would clash with the link): `tmux`, `jq`, `fzf` go in `home.packages`; `tmux.conf` and `fleet` are `mkOutOfStoreSymlink`s into `~/repos/dotfiles`; `plugins.tmux` is generated with one `run-shell` per plugin from `pkgs.tmuxPlugins` | *Where things live* | In the VM: `grep -n 'programs.tmux' modules/home.nix` prints nothing. On `nixos` after switch: `readlink ~/.config/tmux/tmux.conf` points into `~/repos/dotfiles`; `grep -c '^run-shell' ~/.config/tmux/plugins.tmux` prints `6`; `tmux list-keys \| grep -E 'sessionx\|extrakto'` shows both |
| 4 | `fleet` discovers hosts from `~/.config/fleet/hosts` and each host's guests from `ssh theo@<host> cat /etc/agentvm/projects.json`; `--local` reads this machine's file and no hosts list | *Discovery* | bats: with a stub `ssh` serving two hosts' `projects.json`, `fleet ls` prints one line per guest with its host; with `--local` and `AGENTVM_PROJECTS=<fixture>`, only that file's guests |
| 5 | Each guest's sessions come from the `status.sh` and `AGENT_SUPERVISE_REPOS` its `agent-supervise` user unit names (`systemctl --user show -p ExecStart -p Environment`); a guest without the unit is shown as `no supervisor` | *Discovery* | bats: the stub returns a unit with `ExecStart=/workspace/agent-methodology/shared/claude/supervise.sh`; `fleet` runs `…/status.sh --json` with that `AGENT_SUPERVISE_REPOS`; a stub with no unit gives the `no supervisor` line and exit 0 |
| 6 | Session `fleet` (`fleet-<host>` under `--local`): window 1 `overview` with one pane per guest, refreshing `fleet status <guest>` every 30 s; then one window per `<host>·<repo>` that has at least one attachable session | *Layout* | bats on `tmux -L fleet-test`: from the fixtures, `list-windows -F '#W'` prints `overview`, `nixos·nixed`, `thinkcentre·agent-methodology` in that order; `overview` has one pane per guest |
| 7 | A session is attachable when its `continue` starts with `dtach -a`; it gets one pane running `ssh -t agentvm@<ip> dtach -a <sock> -e '^]' -r winch`, tagged `@fleet-entry=<entry>` and titled `<guest> · <branch> · <live>`; every other row (own terminal, blocked, stopped) is only an overview row | *Layout* | bats: three rows (one `dtach -a`, one empty `continue`, one blocked) give exactly one pane, whose `#{@fleet-entry}` and `#{pane_title}` match the first row |
| 8 | Sync is explicit (`prefix F` or `fleet sync`) and idempotent: it adds a pane for each attachable entry with none, closes a tagged pane whose attach has exited and whose entry is gone, marks one whose entry is now blocked or stopped, and never touches an untagged pane | *Sync* | bats: a second sync on unchanged fixtures leaves `list-panes -a -F '#{pane_id}'` identical; adding one entry adds one pane; removing one closes it; a pane made by hand in a fleet window survives both |
| 9 | One unreachable host or guest never fails a sync: ssh runs with `BatchMode=yes`, `ConnectTimeout=5`, guests in parallel, and the failure becomes one `unreachable` overview line | *Discovery* | bats: the stub fails for one guest; `fleet sync` exits 0, the other guest's panes exist, and `fleet status <failed>` prints `unreachable` |
| 10 | The status bar shows `fleet hint` from a cache file a background loop in the session refreshes every 60 s, so the bar never runs ssh: `<host> N▶ M⚠ · … · ↻K` (▶ live, ⚠ a `kind` or `blocked`, ↻ attachable entries with no pane; ↻ hidden at 0) | *Hint* | bats: fixtures with 2 live, 1 stalled, 1 blocked on `nixos` and one unpaned attachable entry give `nixos 2▶ 2⚠ · ↻1`; `fleet hint` with no cache prints nothing and exits 0 |
| 11 | Keys (prefix `C-b`, nothing existing rebound): `F` sync, `f` sessionx, `Tab` extrakto, `y` in copy mode tmux-yank; `C-]` detaches dtach in an agent pane, which closes it and leaves the agent running | *Plugins, keys, theme* | `tmux list-keys -T prefix` shows `F`, `f`, `Tab` bound as stated and `h j k l r c " %` unchanged; manual: `C-]` in an agent pane closes it, and the guest's `status.sh` still shows that session `alive` |
| 12 | Theme: catppuccin; `pane-border-status top` showing `#{@fleet-title}` (else the pane command); agent panes get an accent border colour | *Plugins, keys, theme* | Early output (below): the user looks at the laptop session and can tell agent panes from their own shells |
| 13 | resurrect leaves `ssh` out of restored processes and continuum auto-restores on the laptop only; `fleet` on start closes tagged panes that came back as plain shells, then syncs | *Plugins, keys, theme* | bats: a tagged pane running `bash` (as a restore leaves it) is replaced by a fresh attach on `fleet`; `tmux show -g @continuum-restore` is `on` on the laptop and not `on` on `nixos` |
| 14 | `fleet doctor` checks each prerequisite (ssh to each host, ssh to each guest, the tailnet route to each guest subnet, `jq`, `fzf`, `dtach` on the guest) and names the one that fails | *Discovery* | bats: the stub refuses one guest's ssh; `fleet doctor` exits 1 and its output names that guest and `ssh agentvm@<ip>` |
| 15 | `fleet` uses only these `status.sh --json` fields: `repo`, `worktree`, `branch`, `live`, `state`, `kind`, `entry`, `continue`; a missing field shows `?` and never stops a sync | *Contract consumed* | bats: a fixture row with no `kind` and no `branch` still gets its pane, titled `<guest> · ? · <live>` |

## Early output

The user's own fleet, on the laptop, after slice 2: `fleet` started with both hosts live, a screenshot or a
`tmux capture-pane` of the overview and of one `<host>·<repo>` window with at least one agent attached. The user
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
- `README.md`: the Arch setup: `pacman -S tmux jq fzf bash-bats`, clone TPM, stow `tmux`, `tailscale up
  --accept-routes`, `fleet doctor`.

**nixed** (slice 3):

- `modules/home.nix`: `programs.tmux` goes, since it generates `tmux.conf` itself and would collide with the link;
  `tmux`, `jq` and `fzf` go in `home.packages`. `xdg.configFile."tmux/tmux.conf".source` and
  `home.file.".local/bin/fleet".source` are `config.lib.file.mkOutOfStoreSymlink "/home/theo/repos/dotfiles/…"`.
  `xdg.configFile."tmux/plugins.tmux".text` sets the plugins' options (continuum's restore off) and has one
  `run-shell` per plugin, from `pkgs.tmuxPlugins.{catppuccin,tmux-sessionx,extrakto,yank,resurrect,continuum}`
  (attribute names and each plugin's `.tmux` entry path checked against nixpkgs in the plan).
- `docs/guides/tmux.md`: becomes a short host note pointing here for keys and `fleet`.
- `docs/guides/host-operations.md`, new-machine setup: clone dotfiles into `~/repos`.

Why symlinks, not a flake input: dotfiles is private, and a `nixos-rebuild` as root would need a GitHub token
to fetch it. A link to the checkout the host already has needs none, takes edits without a rebuild, and is the
same kind of hand-checked host path as nixed's `repoRoot`. The cost: a host without `~/repos/dotfiles` gets a
dangling `tmux.conf` link, which `fleet doctor` and the guide's setup step cover.

## Discovery

For each host in `~/.config/fleet/hosts` (or, under `--local`, this machine alone, from
`/etc/agentvm/projects.json` directly): read its `projects.json` (guest name, IP). For each guest, over
`ssh agentvm@<ip>`, read the `agent-supervise` unit's `ExecStart` and `Environment`, derive `status.sh` as
`$(dirname ExecStart)/status.sh`, and run it with `--json` and that `AGENT_SUPERVISE_REPOS`. This is the
supervisor's own view by construction: no second list of repos to keep.

All ssh calls: `-o BatchMode=yes -o ConnectTimeout=5`, guests in parallel (background jobs, one output file each
under `$XDG_RUNTIME_DIR/fleet/`), then joined. The laptop reaches guests directly over the tailnet routes each
host advertises; on a host, over its own bridge.

## Layout

Session `fleet`, or `fleet-<host>` under `--local`.

- Window 1 `overview`: one pane per guest (tiled), each a loop of `fleet status <guest>` every 30 s: the
  guest's `status.sh` table, or `unreachable` / `no supervisor`.
- One window per `<host>·<repo>` (repo is the basename of the row's `repo`) with at least one attachable row,
  ordered by host then repo; panes tiled.
- Each attachable row (`continue` starts with `dtach -a`) is one pane: `ssh -t agentvm@<ip>` running the
  `continue` command with `-e '^]'` added, so dtach's detach key is `C-]` and `C-\` stays free. Pane options:
  `@fleet-entry` (the row's `entry`, its identity across syncs), `@fleet-title`.
- Non-attachable rows: a live session in someone's own terminal (`continue` empty), a blocked or stopped run.
  They appear only in the overview.

## Sync

`fleet sync` (bound to `prefix F`), and once on `fleet` start:

1. Discover (above).
2. For each attachable entry with no tagged pane: add the pane to its window, creating the window if missing;
   `select-layout tiled` on that window only.
3. For each tagged pane: if its process has exited and its entry is gone, kill it; if its entry is now blocked
   or stopped, leave it with its last screen and set its title to the new state; if it is a plain shell (a
   resurrect restore), replace it with a fresh attach.
4. Untagged panes and windows not named `<host>·<repo>` are never touched.
5. Refresh the hint cache.

Nothing ever syncs on its own: panes never appear or move while the user types into an agent.

## Hint

A background loop started with the session (`run-shell -b`, one per server, a pid file guards it) runs
discovery every 60 s and writes `$XDG_RUNTIME_DIR/fleet/hint`. `status-right` runs `fleet hint`, which only
`cat`s that file. Format: one `<host> N▶ M⚠` group per host, `·` between, then `↻K` when attachable entries
have no pane.

## Plugins, keys, theme

| Plugin | Why | Key / option |
|---|---|---|
| catppuccin | readable bar with room for the hint, styled pane borders | flavor `mocha` |
| tmux-sessionx | fuzzy jump to any session/window with preview | `prefix f` (not its default `O`) |
| extrakto | pick hashes, paths, URLs, `#PR` from agent output | `prefix Tab` (its default) |
| tmux-yank | copy mode to the system clipboard on the laptop | `y` in copy mode; hosts keep OSC 52 (`set-clipboard on`) |
| tmux-resurrect | restore the user's own windows after a laptop reboot | `@resurrect-processes` without `ssh` |
| tmux-continuum | save every 15 min; auto-restore on the laptop only | `@continuum-restore on` in the laptop's `plugins.tmux` only |

`pane-border-status top`, format `#{?@fleet-title,#{@fleet-title},#{pane_current_command}}`; agent panes
(`@fleet-entry` set) use an accent `pane-border-style`, set per pane by `fleet`.

## Contract consumed

From agent-methodology, as of its session-supervisor spec (`status.sh`, D18): `status.sh --json` prints an
array of rows with `repo`, `worktree`, `branch`, `live`, `state`, `kind`, `entry`, `continue`; `continue` is
`dtach -a <sock> -r winch` for a live run under dtach. And nixed's `agent-supervisor` extra defines the
`agent-supervise` user unit whose `ExecStart` is the supervising checkout's `supervise.sh`. `fleet` reads only
these. A row missing a field is shown with `?`; a `continue` of another shape is treated as not attachable.

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
- **Auto-sync**: rejected (panes would move under the user's typing); the hint replaces it.
- **Read-only agent panes**: rejected for now in favour of interactive attach with distinct borders.

# tmux fleet view Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One tmux config shared by the laptop and the NixOS hosts, with plugins, and a bash tool `fleet` that
builds one tmux session showing every agent session on every host's microVM guests, with an interactive pane
per session running under dtach.

**Architecture:** dotfiles' `tmux` package holds `tmux.conf` (no plugin paths) and a laptop-only `plugins.tmux`
(TPM) that it sources last; nixed links the hosts' `tmux.conf` to their dotfiles checkout and generates their
own `plugins.tmux` from `pkgs.tmuxPlugins`. `fleet` is one bash file: it reads hosts' `projects.json` over ssh,
runs each guest's supervisor `status.sh --json` over ssh (guests in parallel), joins the answers into one
`fleet.json` per session, and lays out tmux windows and panes from it on request (`prefix F`), never on its own.
A background loop refreshes a cached status-bar hint.

**Tech Stack:** tmux 3.8 (≥ 3.2 for pane options and `-x/-y` on `new-session`), bash, jq, ssh, dtach on the
guests; bats 1.14 and shellcheck 0.11 for the tests; TPM on the laptop (Arch); home-manager on the hosts.

**Spec:** `docs/superpowers/specs/2026-11-05-tmux-fleet-design.md` (dotfiles), decisions D1–D15 and
Clarifications 1–3. Read it whole before Task 1.

**Repos:** slices 1–2 in `/workspace/dotfiles` (branch `master`, no PRs: commit and push to `master`; it does
not use agent-methodology), slice 3 in `/workspace/nixed` (change-mode PR `change/tmux-dotfiles`, following
nixed's `AGENTS.md`).

**Running the tests in an agentvm guest.** The guests get `tmux`, `bats` and `shellcheck` from nixed `327b2e3`
once the host has switched to it; until then run every test command through the chroot store, from the dotfiles
root:

```bash
nix --store /var/tmp/nixed-store --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#tmux nixpkgs#bats nixpkgs#shellcheck -c bash -c '<command>'
```

`jq`, `fzf` and `dtach` are already on the guests' PATH. On the laptop, run the commands as they are.

## Global Constraints

- Prefix stays `C-b`; nothing existing is rebound (`h j k l r c " %` keep today's meaning). New keys: `F` sync,
  `f` sessionx, `Tab` extrakto, `y` in copy mode (tmux-yank).
- `tmux/dot-config/tmux/tmux.conf` names neither TPM nor a `/nix/store` path (D1).
- catppuccin flavor `mocha`; `@continuum-save-interval 15`; `@continuum-restore on` in the laptop's
  `plugins.tmux` only, `off` in nixed's generated one (D13).
- Every ssh: `-o BatchMode=yes -o ConnectTimeout=5` (D9). Guest user `agentvm` (`AGENTVM_GUEST_USER`).
- Hosts file `~/.config/fleet/hosts`: one ssh destination per line (`theo@nixos`); the host label is the part
  after `@`. Blank lines and `#` lines are skipped.
- Session `fleet`, or `fleet-<host>` under `--local` (D6). Windows: `overview`, then `<repo>/<branch>` (spec, decision 6), tagged
  `@fleet-host`, `@fleet-host-colour`, `@fleet-repo` and `@fleet-name`.
- Pane user options: `@fleet-entry` (status.sh `entry`), `@fleet-title` (`<guest> · <branch> · <live>`),
  `@fleet-guest` (overview panes), `@fleet-ended` (attach ended). Session option `@fleet-mode local|remote`;
  global `@fleet-booted-<session>` (Clarification 3).
- `status.sh --json` fields used: `repo worktree branch live state kind entry continue` only; a missing one shows
  `?` (D15). Attachable ⇔ `continue` starts with `dtach -a ` (D7); the socket is its third word.
- Agent pane command: `ssh -t … agentvm@<ip> "dtach -a <sock> -e '^]' -r winch"` (D7, D11).
- Hint format: `<host> N▶ M⚠` per host joined by ` · `, then ` · ↻K` when K > 0; `<host> ✗` when every guest of
  the host is unreachable (D10). ▶ = `live == "alive"` and empty `kind`; ⚠ = non-empty `kind` or
  `state == "blocked"`.
- nixed links into `/home/theo/repos/dotfiles` with `config.lib.file.mkOutOfStoreSymlink`; no flake input (D3).

## Review Focus

1. **A guest unreachable for one sync while its agent panes are in use.** Expect the panes to stay: a sync only
   closes a tagged pane whose entry is gone *and* whose attach has ended (`@fleet-ended`). Pinned in Task 3
   ("a guest unreachable for one sync keeps its live panes").
2. **`prefix F` pressed in a session fleet did not make** (the binding passes that session's name). Expect it to
   sync `fleet` (or `fleet-<host>`) and leave the current session alone; the status bar there shows fleet's
   hint. Pinned in Task 4 ("sync and hint from a session fleet did not make…").
3. **`fleet sync` before any `fleet` run.** Expect `no fleet session; start one with: fleet` and exit 1, not a
   tmux error. Pinned in Task 3.
4. **A hosts file with a comment or a blank line.** Expect them skipped, not ssh'd to. Pinned by the fixture
   `tests/fixtures/hosts` (Task 2) and the `ls` test.
5. **Stow folding `~/.local/bin` or `~/.config/fleet` into the repo on a fresh laptop.** If `~/.local/bin` does not
   exist, stow links the whole directory to the repo, and anything else installed there lands in dotfiles.
   Expect the README's setup to create it first (`mkdir -p ~/.local/bin`). Pinned in Task 5's README step and its
   manual check.

---

# Slice 1 (dotfiles): config and plugins

### Task 1: one `tmux.conf`, the laptop's `plugins.tmux`, README

Covers D1, D2, D11 (minus the fleet behaviour), D12 (border format), D13's options.

**Files:**
- Modify: `tmux/dot-config/tmux/tmux.conf` (whole file below)
- Create: `tmux/dot-config/tmux/plugins.tmux`
- Create: `.gitignore`
- Modify: `README.md` (add the `stow` package list's `tmux` note and a `## tmux` section)

**Interfaces:**
- Produces: the pane-border format reads `@fleet-entry`, `@fleet-title`, `@fleet-guest` (set by `fleet` in
  Task 3); `prefix F` runs `fleet sync -t "#{session_name}"`; `status-right` runs
  `fleet hint -t "#{session_name}"` (Task 4), both with `$HOME/.local/bin` prepended to PATH because the NixOS
  hosts do not have it on PATH. Until Task 3 lands, `fleet` is not found and both are silent.
- Order inside `tmux.conf` matters: plugin options → status line → borders → `source-file -q
  ~/.config/tmux/plugins.tmux` **last**. catppuccin 2.1.3 sets `pane-border-style` (and `pane-border-format` only
  when its own pane-status option is on, which we leave off), never `status-left/right`; continuum appends its
  save hook to `status-right` as it loads, so it must load after `status-right` is set. The status line uses
  `#{E:@catppuccin_status_session}` and `#{E:@catppuccin_status_date_time}`, evaluated at draw time, with a
  plain fallback when the plugin is absent.
- Gotcha (cost a retry while planning): inside **double** quotes tmux expands `$HOME`/`$PATH` when it loads the
  file, freezing the loading shell's PATH into `status-right`. The `#( … )` command must be in single quotes.

- [ ] **Step 1: Write the check that fails today**

From the dotfiles root:

```bash
grep -nE 'tpm|/nix/store' tmux/dot-config/tmux/tmux.conf; \
test -f tmux/dot-config/tmux/plugins.tmux && grep -q 'continuum-restore' tmux/dot-config/tmux/plugins.tmux \
  && grep -q '^source-file -q ~/.config/tmux/plugins.tmux' tmux/dot-config/tmux/tmux.conf && echo PASS || echo FAIL
```

Expected now: `FAIL` (no `plugins.tmux`, no `source-file`).

- [ ] **Step 2: Replace `tmux/dot-config/tmux/tmux.conf` with**

```tmux
# One tmux config for the laptop and the NixOS hosts. Plugins load from
# plugins.tmux, sourced last: TPM's on the laptop (this package), Nix store
# paths on the hosts (generated by nixed's modules/home.nix). This file names
# neither, and works with no plugins at all.

# True color
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"

# vi-style keys in copy mode and the command prompt
setw -g mode-keys vi
set -g status-keys vi

# Windows/panes start at 1, not 0 - matches shell tab numbering
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

set -g mouse on
set -g set-clipboard on

set -g history-limit 50000
set -sg escape-time 0
set -g focus-events on

# Split panes keeping the current pane's working directory
bind '"' split-window -v -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux config reloaded"

# vi-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# fleet (~/.local/bin/fleet): prefix F syncs the fleet session's panes. On the
# NixOS hosts ~/.local/bin is not on PATH, hence the prefix.
bind F run-shell -b 'PATH="$HOME/.local/bin:$PATH" fleet sync -t "#{session_name}"'

# Plugin options, read when plugins.tmux loads the plugins
set -g @catppuccin_flavor "mocha"
set -g @sessionx-bind "f"
set -g @extrakto_key "tab"
set -g @continuum-save-interval "15"

# Status line: catppuccin's modules when it is loaded, plain text otherwise.
# #{E:...} expands at draw time, after plugins.tmux has run.
set -g status-interval 5
set -g status-left-length 40
set -g status-right-length 120
set -g status-left "#{?@catppuccin_status_session,#{E:@catppuccin_status_session},#[bold]#S }"
# Single quotes: tmux would expand $HOME and $PATH inside double quotes at load.
set -g status-right '#(PATH="$HOME/.local/bin:$PATH" fleet hint -t "#{session_name}") #{?@catppuccin_status_date_time,#{E:@catppuccin_status_date_time},%Y-%m-%d %H:%M}'
set -g status-style "bg=colour234,fg=colour137"
setw -g window-status-current-style "bg=colour238,fg=colour81,bold"

# Pane borders: fleet's agent panes show their title in an accent colour
# (@fleet-title, set by fleet), its overview panes their guest, every other
# pane its command.
set -g pane-border-status top
set -g pane-border-format "#{?@fleet-entry,#[fg=colour208#,bold] #{@fleet-title} ,#{?@fleet-guest, #{@fleet-guest} , #{pane_current_command} }}"

# Last: the plugins (continuum hooks status-right as it loads, so it must
# come after the status line above). -q: no plugins.tmux, no plugins.
source-file -q ~/.config/tmux/plugins.tmux
```

- [ ] **Step 3: Create `tmux/dot-config/tmux/plugins.tmux`**

```tmux
# Laptop plugins, through TPM (git clone https://github.com/tmux-plugins/tpm
# ~/.config/tmux/plugins/tpm, then prefix I). Sourced last by tmux.conf, which
# sets their options. The NixOS hosts get a generated plugins.tmux instead.
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'catppuccin/tmux#v2.1.3'
set -g @plugin 'omerxx/tmux-sessionx'
set -g @plugin 'laktak/extrakto'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# Auto-restore the last save when the laptop's tmux server starts (hosts: off).
set -g @continuum-restore 'on'

run '~/.config/tmux/plugins/tpm/tpm'
```

- [ ] **Step 4: Create `.gitignore`**

```gitignore
# TPM clones plugins here; stow folds ~/.config/tmux into this repo
tmux/dot-config/tmux/plugins/
```

- [ ] **Step 5: README.** In `## Install`, leave the stow line as it is (it already lists `tmux`) and add, after
the paragraph about the `git` package, this section:

````markdown
## tmux

`tmux/` is the one tmux config for this laptop and the NixOS hosts: nixed links each host's
`~/.config/tmux/tmux.conf` to its own checkout of this repo (`~/repos/dotfiles`). `tmux.conf` sources
`plugins.tmux` last; here that file loads the plugins through TPM, on the hosts nixed generates one that loads
them from nixpkgs. Prefix is `C-b`.

Laptop (Arch) setup, once:

```shell
sudo pacman -S tmux jq fzf
mkdir -p ~/.config/fleet ~/.local/bin      # so stow links files into them, not the directories themselves
stow -t "$HOME" --dotfiles -R tmux
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
tmux                                  # then prefix I installs the plugins
```

| Key | Does |
|---|---|
| `prefix f` | sessionx: fuzzy-jump to any session or window, with preview |
| `prefix Tab` | extrakto: pick a hash, path, URL or `#PR` from the pane's text |
| `y` (copy mode) | tmux-yank: copy to the system clipboard |
| `prefix F` | `fleet sync` (below) |
| `prefix h/j/k/l`, `"`, `%`, `c`, `r` | as before: vi pane moves, splits and windows in the current directory, reload |

tmux-resurrect saves every 15 minutes (continuum) and the laptop restores the last save when its tmux server
starts; `ssh` panes are not restored (resurrect's default), so fleet rebuilds its own session (below).
````

- [ ] **Step 6: Run the checks**

```bash
# Step 1's check
grep -nE 'tpm|/nix/store' tmux/dot-config/tmux/tmux.conf; \
test -f tmux/dot-config/tmux/plugins.tmux && grep -q 'continuum-restore' tmux/dot-config/tmux/plugins.tmux \
  && grep -q '^source-file -q ~/.config/tmux/plugins.tmux' tmux/dot-config/tmux/tmux.conf && echo PASS || echo FAIL
# The config loads with no plugins (HOME points at an empty dir), keys are bound, fallbacks render
H=$(mktemp -d); mkdir -p "$H/.config/tmux"; cp tmux/dot-config/tmux/tmux.conf "$H/.config/tmux/"
HOME=$H tmux -L t1 -f "$H/.config/tmux/tmux.conf" new-session -d -x 200 -y 50 \
  && tmux -L t1 list-keys -T prefix | grep -E ' (F|h|j|k|l|r|c|%|") ' \
  && tmux -L t1 show -g status-right && tmux -L t1 display -p '#{E:status-left}|#{T:status-right}'
tmux -L t1 kill-server
# plugins.tmux parses
tmux -L t2 -f /dev/null start-server \; source-file -n tmux/dot-config/tmux/plugins.tmux && echo PARSE-OK
```

Expected: the grep prints nothing, then `PASS`; `list-keys` shows `F` bound to `run-shell -b
"PATH=\"\$HOME/.local/bin:\$PATH\" fleet sync -t \"#{session_name}\""` and `h j k l r c % "` as before;
`status-right` still contains the literal `$HOME/.local/bin:$PATH` (not an expanded path); the display line is
`#[bold]0 | <date> <time>` (fleet's hint is empty: no `fleet` yet); `PARSE-OK`.

With the plugins (in an agentvm guest, through the chroot store, using nixpkgs' copies in place of TPM):

```bash
H=$(mktemp -d); mkdir -p "$H/.config/tmux"; cp tmux/dot-config/tmux/tmux.conf "$H/.config/tmux/"
{ echo "set -g @continuum-restore 'off'"
  for p in catppuccin tmux-sessionx extrakto yank resurrect continuum; do
    echo "run-shell $(nix --store /var/tmp/nixed-store --extra-experimental-features 'nix-command flakes' \
      eval --raw nixpkgs#tmuxPlugins.$p.rtp)"; done; } > "$H/.config/tmux/plugins.tmux"
# then, inside the chroot-store shell:
HOME=$H tmux -L t3 -f "$H/.config/tmux/tmux.conf" new-session -d -x 200 -y 50
tmux -L t3 show -g @catppuccin_flavor; tmux -L t3 show -g @continuum-save-interval
tmux -L t3 list-keys | grep -cE 'sessionx|extrakto'; tmux -L t3 list-keys -T prefix | grep -E ' (f|Tab) '
tmux -L t3 show -g status-right | grep -c continuum_save; tmux -L t3 kill-server
```

Expected: `@catppuccin_flavor mocha`, `@continuum-save-interval 15`, `2`, `f` bound to sessionx and `Tab` to
extrakto, `1` (continuum's hook is in `status-right`, so it loaded last).

- [ ] **Step 7: Commit and push**

```bash
git add tmux/dot-config/tmux/tmux.conf tmux/dot-config/tmux/plugins.tmux .gitignore README.md
git commit -m "tmux: one config for laptop and hosts, plugins from plugins.tmux

tmux.conf no longer names a plugin path: it sources plugins.tmux last, TPM's
here and a nixpkgs one on the hosts (nixed), so both use this file. Adds
catppuccin, sessionx (prefix f), extrakto, yank, resurrect and continuum
(auto-restore on the laptop only), pane titles on the borders, and prefix F
for fleet (next commits). Spec: docs/superpowers/specs/2026-11-05-tmux-fleet-design.md"
git push origin master
```

- [ ] **Step 8: Early output (slice 1).** Ask the user to restow on the laptop, `prefix I`, and look at the
restyled bar and borders. Their judgement on readability gates nothing, but say in the message what to look at.

---

# Slice 2 (dotfiles): `fleet`

`fleet` is built in four tasks, each adding functions to one file, `tmux/dot-local/bin/fleet`, and cases to its
`main`. Put new functions above `usage()` in the order given; `main` stays last. Tests live in
`tests/fleet.bats`, with stubs in `tests/stub/` (first on PATH) and fixtures in `tests/fixtures/` (copied per
test to `$BATS_TEST_TMPDIR/fx`). Every test runs a private tmux server (`FLEET_TMUX_SOCKET`, config
`/dev/null`) killed in teardown, and `fleet` never runs a hint loop under test (`FLEET_NO_HINTLOOP=1`).

Test-only environment `fleet` reads: `FLEET_HOSTS_FILE`, `AGENTVM_PROJECTS` (the `--local` projects file),
`FLEET_HOSTNAME` (`--local`'s host label, default `uname -n`), `FLEET_STATE` (default
`${XDG_RUNTIME_DIR:-/tmp}/fleet-$UID`), `FLEET_TMUX_SOCKET` (→ `tmux -L`), `FLEET_TMUX_CONF` (→ `tmux -f`),
`FLEET_NO_HINTLOOP`, `FLEET_HINT_INTERVAL` (60), `FLEET_OVERVIEW_INTERVAL` (30), `AGENTVM_GUEST_USER`
(`agentvm`). The tmux server copies the starting client's environment into its global environment, so panes
and `run-shell` jobs inherit these.

State per session: `$FLEET_STATE/<session>/fleet.json` (`[{host, guest, ip, status, rows}]`, `status` one of
`ok unreachable no-supervisor error`), `hint`, `hintloop.pid`.

Contract facts (checked while planning, against agentvm-repos):
- `/etc/agentvm/projects.json` = `{ "<name>": { "vmName": "agentvm-<name>", "ip", "path", "mac", "extras", "tap",
  "stateDir" } }`; the guest name is `vmName`.
- `systemctl --user show agent-supervise.service -p ExecStart --value` →
  `{ path=/workspace/agent-methodology/shared/claude/supervise.sh ; argv[]=… }`; `-p Environment --value` quotes
  values with spaces as a whole (`"AGENT_SUPERVISE_REPOS=/workspace/a /workspace/b" … TMPDIR=/var/tmp`); a
  missing unit gives `-p LoadState --value` = `not-found`.
- `status.sh` prints `continue` as `printf 'dtach -a %q -r winch'` for a live run under dtach, empty for a live run
  in a person's terminal; blocked rows have `live: "blocked #4"`, `state: "blocked"`, often `branch: ""`.
- The probe runs as `bash -s` (not `bash -l`: NixOS's `/etc/profile` resets PATH, which would drop the test stubs
  and isn't needed on the guests).

### Task 2: skeleton, discovery and the guest probe

Covers D4, D5, D9 (host side), D15 (via `?`, used from Task 3).

**Files:**
- Create: `tmux/dot-local/bin/fleet` (mode 755)
- Create: `tmux/dot-config/fleet/hosts`
- Create: `tests/fleet.bats`, `tests/stub/{ssh,systemctl,ip}` (mode 755)
- Create: `tests/fixtures/{hosts,projects-nixos.json,projects-thinkcentre.json,guest-192.168.122.51.json,guest-192.168.123.51.json}`,
  `tests/fixtures/am/shared/claude/status.sh` (mode 755)

**Interfaces:**
- Produces (used by Tasks 3–5): `tmx ARGS…` (tmux on the fleet's server); `self_cmd ARGS…` (a quoted command line
  running this script); `local_host`; `default_session` (`fleet` / `fleet-<host>`); `sdir SESSION` (its state
  dir); `hosts_file`; `guests` (stdout: `host guest ip` lines, `host - -` for an unreachable host); `probe IP
  json|table` (the guest's `status.sh` output, or `fleet:no-supervisor`; non-zero when ssh fails); `status_of
  GUEST IP` (table, `unreachable` or `no supervisor`); globals `LOCAL` (0/1), `SSH_OPTS`, `GUEST_USER`, `STATE`,
  `FLEET_SELF`.
- Stub ssh protocol (Tasks 3–5 rely on it): logs `ssh <args>` to `$FLEET_FIXTURES/ssh.log`; `fail-<host-or-ip>`
  → exit 255; `nosup-<ip>` → `fleet:no-supervisor`; `attach-exits` → `dtach -a` returns at once, else it sleeps
  600 s; `sock-alive` → `test -S` succeeds.

- [ ] **Step 1: Stubs and fixtures**

`tests/stub/ssh`:

```bash
#!/usr/bin/env bash
# Stub ssh for tests/fleet.bats: answers from $FLEET_FIXTURES by destination
# and command, and logs every call to $FLEET_FIXTURES/ssh.log.
fx=$FLEET_FIXTURES
echo "ssh $*" >> "$fx/ssh.log"
while [ $# -gt 0 ]; do
  case $1 in -o) shift 2 ;; -t|-T) shift ;; *) break ;; esac
done
dest=${1#*@}; shift
cmd="$*"
[ ! -e "$fx/fail-$dest" ] || exit 255
case $cmd in
  'cat /etc/agentvm/projects.json') cat "$fx/projects-$dest.json" ;;
  'bash -s -- json'|'bash -s -- table')
    cat >/dev/null
    if [ -e "$fx/nosup-$dest" ]; then echo fleet:no-supervisor
    elif [ "$cmd" = 'bash -s -- json' ]; then cat "$fx/guest-$dest.json"
    else echo "table of $dest"; fi ;;
  'dtach -a '*) [ -e "$fx/attach-exits" ] && exit 0; exec sleep 600 ;;
  'test -S '*) [ -e "$fx/sock-alive" ] ;;
  true|'command -v dtach') exit 0 ;;
  *) echo "stub ssh: unexpected command: $cmd" >&2; exit 1 ;;
esac
```

`tests/stub/systemctl`:

```bash
#!/usr/bin/env bash
# Stub systemctl for the probe-script test: an agent-supervise user unit
# whose ExecStart is $FLEET_FIXTURES/am/shared/claude/supervise.sh.
fx=$FLEET_FIXTURES
case "$*" in
  *'-p LoadState'*) if [ -e "$fx/unit-missing" ]; then echo not-found; else echo loaded; fi ;;
  *'-p ExecStart'*) echo "{ path=$fx/am/shared/claude/supervise.sh ; argv[]=$fx/am/shared/claude/supervise.sh ; ignore_errors=no ; status=0 }" ;;
  *'-p Environment'*) echo '"AGENT_CONTINUE_BINS=claude claude2" "AGENT_SUPERVISE_REPOS=/workspace/a /workspace/b" DISABLE_AUTOUPDATER=1 TMPDIR=/var/tmp' ;;
esac
```

`tests/stub/ip` (used by Task 5):

```bash
#!/usr/bin/env bash
# Stub ip for fleet doctor: every guest is routed over the tailnet.
echo "$3 dev tailscale0 table 52 src 100.64.0.2 uid 1000"
```

`tests/fixtures/am/shared/claude/status.sh`:

```bash
#!/usr/bin/env bash
# Fake status.sh: shows what the probe script ran it with.
echo "repos=$AGENT_SUPERVISE_REPOS tmpdir=$TMPDIR args=$*"
```

`tests/fixtures/hosts`:

```text
# ssh destinations, one per line
theo@nixos

theo@thinkcentre
```

`tests/fixtures/projects-nixos.json`:

```json
{
  "repos": {
    "vmName": "agentvm-repos", "ip": "192.168.122.51", "path": "/home/theo/repos",
    "mac": "02:00:00:00:00:51", "extras": ["agent-supervisor"], "tap": "vm-repos", "stateDir": "/var/lib/microvms/agentvm-repos"
  }
}
```

`tests/fixtures/projects-thinkcentre.json`:

```json
{
  "thinkrepos": {
    "vmName": "agentvm-thinkrepos", "ip": "192.168.123.51", "path": "/home/theo/repos",
    "mac": "02:00:00:00:01:51", "extras": ["agent-supervisor"], "tap": "vm-thinkrepos", "stateDir": "/var/lib/microvms/agentvm-thinkrepos"
  }
}
```

`tests/fixtures/guest-192.168.122.51.json` (Clarification 2's `nixos` rows: plain live under dtach, live in a
person's terminal, blocked, stalled under dtach):

```json
[
  {"repo": "/workspace/nixed", "worktree": "/workspace/nixed", "branch": "main", "live": "alive", "state": "running",
   "kind": "", "entry": "e-nixed-1", "continue": "dtach -a /var/tmp/agent-sessions/e-nixed-1.sock -r winch"},
  {"repo": "/workspace/nixed", "worktree": "/workspace/nixed", "branch": "main", "live": "alive", "state": "running",
   "kind": "", "entry": "e-nixed-term", "continue": ""},
  {"repo": "/workspace/nixed", "worktree": "", "branch": "", "live": "blocked #4", "state": "blocked",
   "kind": "", "entry": "e-nixed-blocked", "continue": ""},
  {"repo": "/workspace/nixed", "worktree": "/workspace/nixed/.claude/worktrees/impl-x", "branch": "impl/x", "live": "alive",
   "state": "running", "kind": "stall", "entry": "e-nixed-stall", "continue": "dtach -a /var/tmp/agent-sessions/e-nixed-stall.sock -r winch"}
]
```

`tests/fixtures/guest-192.168.123.51.json` (no `branch`, no `kind`: D15):

```json
[
  {"repo": "/workspace/agent-methodology", "worktree": "/workspace/agent-methodology", "live": "alive", "state": "running",
   "entry": "e-am-1", "continue": "dtach -a /var/tmp/agent-sessions/e-am-1.sock -r winch"}
]
```

`tmux/dot-config/fleet/hosts`:

```text
theo@nixos
theo@thinkcentre
```

`chmod +x tests/stub/* tests/fixtures/am/shared/claude/status.sh`.

- [ ] **Step 2: Write the failing tests.** Create `tests/fleet.bats` with this head (setup, teardown, helpers used
by later tasks too):

```bash
#!/usr/bin/env bats
# fleet against a private tmux server and stub ssh/systemctl/ip (tests/stub),
# answering from a copy of tests/fixtures. Run from the repo root: bats tests/

setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  FLEET=$ROOT/tmux/dot-local/bin/fleet
  export FLEET_FIXTURES=$BATS_TEST_TMPDIR/fx
  cp -r "$ROOT/tests/fixtures" "$FLEET_FIXTURES"
  export PATH="$ROOT/tests/stub:$PATH"
  export FLEET_HOSTS_FILE=$FLEET_FIXTURES/hosts
  export FLEET_STATE=$BATS_TEST_TMPDIR/state
  export FLEET_TMUX_SOCKET=fleet-test-$$-$BATS_TEST_NUMBER
  export FLEET_TMUX_CONF=/dev/null
  export FLEET_NO_HINTLOOP=1 FLEET_HINT_INTERVAL=3600 FLEET_OVERVIEW_INTERVAL=3600
  unset TMUX TMUX_PANE
}

teardown() { tmux -L "$FLEET_TMUX_SOCKET" kill-server 2>/dev/null || true; }

t() { tmux -L "$FLEET_TMUX_SOCKET" "$@"; }

# Append one row to a guest's status.sh fixture.
add_row() { jq --argjson r "$2" '. + [$r]' "$FLEET_FIXTURES/guest-$1.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-$1.json"; }
drop_row() { jq --arg e "$2" 'map(select(.entry != $e))' "$FLEET_FIXTURES/guest-$1.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-$1.json"; }
NEW_ROW='{"repo": "/workspace/nixed", "worktree": "/workspace/nixed", "branch": "impl/y", "live": "alive", "state": "running", "kind": "", "entry": "e-nixed-2", "continue": "dtach -a /var/tmp/agent-sessions/e-nixed-2.sock -r winch"}'

entries() { t list-panes -s -t =fleet -F '#{@fleet-entry}' | grep . | sort; }

# Poll up to 5 s until every agent pane has @fleet-ended set.
wait_ended() {
  local i
  for i in $(seq 50); do
    [ -n "$(entries)" ] && ! t list-panes -s -t =fleet -F '#{@fleet-entry}|#{@fleet-ended}' | grep -q '^e-.*|$' && return 0
    sleep 0.1
  done
  return 1
}

# Poll up to 5 s until the attach for entry $1 has reached the stub ssh.
wait_attached() {
  local i
  for i in $(seq 50); do
    grep -q "dtach -a /var/tmp/agent-sessions/$1.sock" "$FLEET_FIXTURES/ssh.log" && return 0
    sleep 0.1
  done
  return 1
}
```

and these tests:

```bash
@test "ls: one line per guest with its host (D4)" {
  run "$FLEET" ls
  [ "$status" -eq 0 ]
  [ "$output" = $'nixos agentvm-repos 192.168.122.51\nthinkcentre agentvm-thinkrepos 192.168.123.51' ]
}

@test "ls --local: only this host's projects.json (D4)" {
  AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos run "$FLEET" --local ls
  [ "$status" -eq 0 ]
  [ "$output" = "nixos agentvm-repos 192.168.122.51" ]
  ! grep -q 'cat /etc/agentvm' "$FLEET_FIXTURES/ssh.log"
}

@test "ls: an unreachable host is one '- -' line, not a failure (D9)" {
  touch "$FLEET_FIXTURES/fail-thinkcentre"
  run "$FLEET" ls
  [ "$status" -eq 0 ]
  [ "$output" = $'nixos agentvm-repos 192.168.122.51\nthinkcentre - -' ]
}

@test "probe script runs the unit's status.sh with its AGENT_SUPERVISE_REPOS (D5)" {
  run bash -c "'$FLEET' _probe-script | bash -s -- json"
  [ "$status" -eq 0 ]
  [ "$output" = "repos=/workspace/a /workspace/b tmpdir=/var/tmp args=--json" ]
  run bash -c "'$FLEET' _probe-script | bash -s -- table"
  [ "$output" = "repos=/workspace/a /workspace/b tmpdir=/var/tmp args=" ]
}

@test "probe script with no unit prints the no-supervisor marker (D5)" {
  touch "$FLEET_FIXTURES/unit-missing"
  run bash -c "'$FLEET' _probe-script | bash -s -- json"
  [ "$status" -eq 0 ]
  [ "$output" = "fleet:no-supervisor" ]
}

@test "status: a guest without the unit shows 'no supervisor', exit 0 (D5)" {
  touch "$FLEET_FIXTURES/nosup-192.168.123.51"
  run "$FLEET" status agentvm-thinkrepos
  [ "$status" -eq 0 ]
  [ "$output" = "no supervisor" ]
  run "$FLEET" status agentvm-repos
  [ "$output" = "table of 192.168.122.51" ]
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `bats tests/`
Expected: all 6 fail (`fleet` does not exist: `command not found` / status 127).

- [ ] **Step 4: Write the skeleton.** Create `tmux/dot-local/bin/fleet` (`chmod 755`) with the header:

```bash
#!/usr/bin/env bash
# fleet: one tmux session showing every agent session on the microVM guests of
# the hosts in ~/.config/fleet/hosts (or, with --local, of this host alone).
# Window `overview` has one pane per guest running its supervisor's status.sh;
# then one window per <host>·<repo> with one interactive pane per session
# running under dtach. Syncs only when asked (prefix F, `fleet sync`).
# Design: docs/superpowers/specs/2026-11-05-tmux-fleet-design.md in dotfiles.
set -uo pipefail

FLEET_SELF=$(readlink -f "${BASH_SOURCE[0]}")
GUEST_USER=${AGENTVM_GUEST_USER:-agentvm}
STATE=${FLEET_STATE:-${XDG_RUNTIME_DIR:-/tmp}/fleet-$UID}
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=5)
LOCAL=0

```

then these functions, in this order:

```bash
die() { echo "fleet: $*" >&2; exit 1; }

# tmux on the fleet's server: FLEET_TMUX_SOCKET and FLEET_TMUX_CONF are for
# the tests, which run a private server with no config.
tmx() {
  local a=()
  [ -z "${FLEET_TMUX_SOCKET:-}" ] || a+=(-L "$FLEET_TMUX_SOCKET")
  [ -z "${FLEET_TMUX_CONF:-}" ] || a+=(-f "$FLEET_TMUX_CONF")
  tmux "${a[@]}" "$@"
}

# A command line for a pane: this script, its arguments quoted.
self_cmd() { printf '%q ' "$FLEET_SELF" "$@"; }

local_host() { echo "${FLEET_HOSTNAME:-$(uname -n)}"; }

default_session() { if [ "$LOCAL" = 1 ]; then echo "fleet-$(local_host)"; else echo fleet; fi; }

sdir() { echo "$STATE/$1"; }

hosts_file() { echo "${FLEET_HOSTS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/fleet/hosts}"; }

# --- discovery -----------------------------------------------------------

# projects.json on stdin -> "host guest ip" lines.
projects_lines() { jq -r --arg h "$1" 'to_entries[] | "\($h) \(.value.vmName) \(.value.ip)"' 2>/dev/null; }

# Every guest, one "host guest ip" line each. A host whose projects.json can't
# be read gives "host - -".
guests() {
  if [ "$LOCAL" = 1 ]; then
    projects_lines "$(local_host)" < "${AGENTVM_PROJECTS:-/etc/agentvm/projects.json}"
    return
  fi
  local f dest out
  f=$(hosts_file)
  [ -r "$f" ] || die "no hosts file $f (one ssh destination per line, e.g. theo@nixos), or use --local"
  while read -r dest; do
    case $dest in ''|'#'*) continue ;; esac
    if out=$(ssh "${SSH_OPTS[@]}" "$dest" cat /etc/agentvm/projects.json </dev/null 2>/dev/null) && [ -n "$out" ]; then
      projects_lines "${dest#*@}" <<<"$out"
    else
      echo "${dest#*@} - -"
    fi
  done < "$f"
}

# The script a guest runs (`bash -s -- json|table`): find the agent-supervise
# user unit's status.sh and AGENT_SUPERVISE_REPOS, then run it. Not `bash -l`:
# NixOS's /etc/profile resets PATH.
probe_script() {
  cat <<'EOF'
mode=${1:-table}
unit=agent-supervise.service
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
if [ "$(systemctl --user show "$unit" -p LoadState --value 2>/dev/null)" != loaded ]; then
  echo fleet:no-supervisor; exit 0
fi
exec_start=$(systemctl --user show "$unit" -p ExecStart --value)
path=${exec_start#*path=}; path=${path%% *}
env=$(systemctl --user show "$unit" -p Environment --value)
# A value with spaces is quoted as a whole ("NAME=a b"); others are bare words.
envval() {
  local v
  v=$(sed -n "s/.*\"$1=\([^\"]*\)\".*/\1/p" <<<"$env")
  [ -n "$v" ] || v=$(tr ' ' '\n' <<<"$env" | sed -n "s/^$1=//p" | head -n 1)
  printf '%s' "$v"
}
status_sh=${path%/*}/status.sh
AGENT_SUPERVISE_REPOS=$(envval AGENT_SUPERVISE_REPOS) TMPDIR=$(envval TMPDIR) "$status_sh" $([ "$mode" = json ] && echo --json)
EOF
}

probe() { probe_script | ssh "${SSH_OPTS[@]}" "$GUEST_USER@$1" bash -s -- "$2" 2>/dev/null; }

# A guest's status.sh table, or why there is none.
status_of() {
  local out
  if [ -z "${2:-}" ] || [ "$2" = - ] || ! out=$(probe "$2" table); then echo unreachable; return; fi
  if [ "$out" = fleet:no-supervisor ]; then echo "no supervisor"; else printf '%s\n' "$out"; fi
}

# --- commands ------------------------------------------------------------

cmd_status() {
  local h g ip
  while read -r h g ip; do
    [ "$g" = "$1" ] && { status_of "$g" "$ip"; return 0; }
  done < <(guests)
  die "no guest $1"
}
```

and last `usage` and `main` (Tasks 3–5 add cases to `main`):

```bash
usage() {
  cat <<'EOF'
usage: fleet [--local] [command]

  (none)        start the fleet session if needed, then attach or switch to it
  up            start the fleet session if needed (no attach)
  sync [-t s]   rediscover and add/close agent panes (prefix F)
  ls            list guests: host guest ip
  status GUEST  that guest's status.sh table, or unreachable / no supervisor
  hint [-t s] [--refresh]   the status-bar hint (cached; --refresh rediscovers)
  doctor        check each prerequisite, name the one that fails
  help          this text

--local: this host's guests only (/etc/agentvm/projects.json), session fleet-<host>.
Hosts: ~/.config/fleet/hosts, one ssh destination per line (theo@nixos).
In an agent pane, C-] detaches: the pane closes, the agent keeps running.
EOF
}

main() {
  if [ "${1:-}" = --local ]; then LOCAL=1; shift; fi
  local cmd=${1:-attach}
  [ $# -eq 0 ] || shift
  case $cmd in
    ls) guests ;;
    status) [ $# -ge 1 ] || die "usage: fleet status GUEST"; cmd_status "$1" ;;
    help|-h|--help) usage ;;
    _probe-script) probe_script ;;
    *) usage >&2; exit 2 ;;
  esac
}

main "$@"
```

- [ ] **Step 5: Run the tests and shellcheck**

Run: `bats tests/ && shellcheck tmux/dot-local/bin/fleet tests/stub/* && bash -n tmux/dot-local/bin/fleet`
Expected: `6 tests, 0 failures`; shellcheck prints nothing.

- [ ] **Step 6: Check the probe against a real guest.** In an agentvm guest that runs `agent-supervise`
(agentvm-repos does):

Run: `tmux/dot-local/bin/fleet _probe-script | bash -s -- json | jq -e 'type == "array" and length > 0'`
Expected: `true`. And `… | bash -s -- table | head -3` prints the `status.sh` table header.

- [ ] **Step 7: Commit and push**

```bash
git add tmux/dot-local/bin/fleet tmux/dot-config/fleet/hosts tests/
git commit -m "fleet: discover hosts' guests and read each guest's supervisor

fleet ls lists guests from each host's /etc/agentvm/projects.json (or
--local, this host's); fleet status runs the guest's status.sh as its
agent-supervise unit names it, so there is no second list of repos. An
unreachable host or guest is a line, never a failure. Bats suite with stub
ssh/systemctl answering from tests/fixtures."
git push origin master
```

### Task 3: the session: up, sync, agent and overview panes

Covers D6, D7, D8, D9 (sync side), D11 (detach closes the pane), D13 (re-adopt), D15 (title `?`).

**Files:**
- Modify: `tmux/dot-local/bin/fleet` (add functions after `status_of`, cases in `main`)
- Modify: `tests/fleet.bats` (append tests)

**Interfaces:**
- Consumes: Task 2's `tmx`, `self_cmd`, `sdir`, `default_session`, `local_host`, `guests`, `probe`, `status_of`,
  `LOCAL`.
- Produces: `discover FILE` (writes `fleet.json` atomically); `attachable FILE` (tab-separated `entry host guest
  ip repo branch live sock`, `?` for a missing field); `use_session S` (sets `LOCAL` from `@fleet-mode`; non-zero
  when S is not a fleet session); `target_session [S]` (prints the session to act on; run it as `$(…)` and call
  `use_session` on the result, since the subshell loses `LOCAL`); `sync_layout S`; `cmd_up`; `cmd_sync [S]`.
  Task 4 adds a `hint_write "$s"` line to the end of `cmd_up` and `cmd_sync`, and the hint-loop start to
  `cmd_up`.
- tmux target syntax (cost a retry while planning): session **options** need `-t "=$s:"` (with the colon);
  `show -t =fleet` / `set -t =fleet` fail with `no such session: =fleet`, while `has-session`, `kill-session`,
  `list-panes -s`, `list-windows` take `=fleet`.

Sync rules (spec *Sync*, refined while planning): for each tagged pane (`@fleet-entry` set) — entry still
attachable: keep it, unless `@fleet-ended` is 1, then kill it (the add step re-creates it); entry present but not
attachable (blocked, stopped, now in a person's terminal): set its `@fleet-title` from the row, leave the pane;
entry absent (gone, or its guest unreachable this time): kill it only if `@fleet-ended` is 1, so a probe that
fails once never closes a pane in use. Then add a pane for every attachable entry with none, into the last
window named `<host>·<repo>` (`split-window -d`, then `select-layout tiled` on that window), or a new window when
there is none or the split fails (too small). Untagged panes are never touched. Detaching with `C-]` closes the
pane (the attach exits 0 while the socket is still there); the next sync re-adds it.

- [ ] **Step 1: Write the failing tests.** Append to `tests/fleet.bats`:

```bash
@test "up: overview, then one window per host·repo in order (D6)" {
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'overview\nnixos·nixed\nthinkcentre·agent-methodology' ]
  run t list-panes -t =fleet:overview -F '#{@fleet-guest}'
  [ "$output" = $'agentvm-repos\nagentvm-thinkrepos' ]
}

@test "up: only dtach rows get panes, tagged and titled (D7, D15)" {
  "$FLEET" up
  run entries
  [ "$output" = $'e-am-1\ne-nixed-1\ne-nixed-stall' ]
  run t list-panes -s -t =fleet -F '#{@fleet-entry}|#{@fleet-title}'
  [[ "$output" == *'e-nixed-1|agentvm-repos · main · alive'* ]]
  [[ "$output" == *'e-am-1|agentvm-thinkrepos · ? · alive'* ]]
  wait_attached e-nixed-1
  grep -q "ssh -t -o BatchMode=yes -o ConnectTimeout=5 agentvm@192.168.122.51 dtach -a /var/tmp/agent-sessions/e-nixed-1.sock -e '^]' -r winch" "$FLEET_FIXTURES/ssh.log"
}

@test "sync: idempotent, adds new entries, leaves untagged panes alone (D8)" {
  "$FLEET" up
  t split-window -d -t =fleet:2 'sleep 600'
  before=$(t list-panes -a -F '#{pane_id}')
  run "$FLEET" sync -t fleet
  [ "$status" -eq 0 ]
  [ "$(t list-panes -a -F '#{pane_id}')" = "$before" ]
  add_row 192.168.122.51 "$NEW_ROW"
  "$FLEET" sync -t fleet
  [ "$(t list-panes -a -F '#{pane_id}' | wc -l)" -eq $(($(wc -l <<<"$before") + 1)) ]
  run entries
  [ "$output" = $'e-am-1\ne-nixed-1\ne-nixed-2\ne-nixed-stall' ]
  [ "$(t list-panes -t =fleet:2 -F '#{@fleet-entry}' | grep -c '^$')" -eq 1 ]
}

@test "sync: a gone entry whose attach ended is closed; a blocked one is retitled (D8)" {
  touch "$FLEET_FIXTURES/attach-exits"
  "$FLEET" up
  wait_ended
  # e-nixed-1 is gone; e-nixed-stall is now blocked (no continue).
  drop_row 192.168.122.51 e-nixed-1
  jq 'map(if .entry == "e-nixed-stall" then .live = "blocked #9" | .state = "blocked" | .continue = "" else . end)' \
    "$FLEET_FIXTURES/guest-192.168.122.51.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.122.51.json"
  "$FLEET" sync -t fleet
  run t list-panes -s -t =fleet -F '#{@fleet-entry}|#{@fleet-title}'
  [[ "$output" != *'e-nixed-1|'* ]]
  [[ "$output" == *'e-nixed-stall|agentvm-repos · impl/x · blocked #9'* ]]
}

@test "sync: an ended pane of a still-attachable entry is replaced (D8)" {
  touch "$FLEET_FIXTURES/attach-exits"
  "$FLEET" up
  wait_ended
  old=$(t list-panes -s -t =fleet -F '#{pane_id} #{@fleet-entry}' | awk '$2 == "e-am-1" { print $1 }')
  rm "$FLEET_FIXTURES/attach-exits"
  "$FLEET" sync -t fleet
  new=$(t list-panes -s -t =fleet -F '#{pane_id} #{@fleet-entry} #{@fleet-ended}' | awk '$2 == "e-am-1"')
  [ -n "$new" ] && [ "${new%% *}" != "$old" ]
  [[ "$new" != *' 1' ]]
}

@test "attach: a detach (socket still there) closes the pane (D11)" {
  touch "$FLEET_FIXTURES/attach-exits" "$FLEET_FIXTURES/sock-alive"
  "$FLEET" up
  for i in $(seq 50); do [ -z "$(entries)" ] && break; sleep 0.1; done
  [ -z "$(entries)" ]
}

@test "sync: one unreachable guest never fails it (D9)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run entries
  [ "$output" = $'e-nixed-1\ne-nixed-stall' ]
  run "$FLEET" status agentvm-thinkrepos
  [ "$output" = unreachable ]
}

@test "up: rebuilds a session without the boot marker, keeps one with it (D13)" {
  "$FLEET" up
  t new-window -d -t =fleet: -n mine 'sleep 600'
  "$FLEET" up
  t list-windows -t =fleet -F '#W' | grep -qx mine
  t set -gu @fleet-booted-fleet
  "$FLEET" up
  ! t list-windows -t =fleet -F '#W' | grep -qx mine
  [ "$(t show -gv @fleet-booted-fleet)" = 1 ]
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'overview\nnixos·nixed\nthinkcentre·agent-methodology' ]
}

@test "up --local: session fleet-<host>, this host's guests only (D4, D6)" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  run "$FLEET" --local up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet-nixos -F '#W'
  [ "$output" = $'overview\nnixos·nixed' ]
  [ "$(t show -t =fleet-nixos: -v @fleet-mode)" = local ]
  run "$FLEET" sync -t fleet-nixos
  [ "$status" -eq 0 ]
  ! grep -q 'theo@' "$FLEET_FIXTURES/ssh.log"
}

@test "sync: no fleet session says so, exit 1" {
  run "$FLEET" sync
  [ "$status" -eq 1 ]
  [[ "$output" == *'no fleet session'* ]]
}

@test "sync: a guest unreachable for one sync keeps its live panes" {
  "$FLEET" up
  wait_attached e-am-1
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  "$FLEET" sync -t fleet
  [[ "$(entries)" == *e-am-1* ]]
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `bats tests/`
Expected: the 6 Task 2 tests pass; the 11 new ones fail (`fleet up` prints the usage, exit 2).

- [ ] **Step 3: Add discovery's join and the attachable list** (after `status_of`):

```bash
# Probe every guest in parallel; write [{host, guest, ip, status, rows}] to $1
# atomically (sync and the hint loop may run at once). status: ok,
# unreachable, no-supervisor or error (status.sh printed no JSON array).
discover() {
  local out=$1 tmp i=0 h g ip
  mkdir -p "${out%/*}"
  tmp=$(mktemp -d "${out%/*}/.discover.XXXXXX")
  while read -r h g ip; do
    i=$((i + 1))
    (
      rows='[]' status=unreachable r=''
      if [ "$g" != - ] && r=$(probe "$ip" json); then
        if [ "$r" = fleet:no-supervisor ]; then status=no-supervisor
        elif jq -e 'type == "array"' >/dev/null 2>&1 <<<"$r"; then status=ok rows=$r
        else status=error; fi
      fi
      jq -n --arg host "$h" --arg guest "$g" --arg ip "$ip" --arg status "$status" --argjson rows "$rows" \
        '{host: $host, guest: $guest, ip: $ip, status: $status, rows: $rows}' > "$tmp/$(printf %04d "$i").json"
    ) &
  done < <(guests)
  wait
  local files=("$tmp"/*.json)
  if [ -e "${files[0]}" ]; then jq -s . "${files[@]}"; else echo '[]'; fi > "$tmp/fleet.json"
  mv -f "$tmp/fleet.json" "$out"
  rm -rf "$tmp"
}

# Attachable rows (continue starts with `dtach -a `), one tab-separated line
# each: entry host guest ip repo branch live sock. A missing field is `?`.
attachable() {
  jq -r 'def q: if . == null or . == "" then "?" else tostring end;
    .[] | . as $g | select(.status == "ok") | .rows[]
    | select((.continue // "") | startswith("dtach -a "))
    | [(.entry | q), $g.host, $g.guest, $g.ip, ((.repo // "") | split("/") | last | q),
       (.branch | q), (.live | q), (.continue | split(" ")[2])]
    | join("\t")' "$1"
}
```

- [ ] **Step 4: Add the session functions** (after `attachable`):

```bash
# --- session -------------------------------------------------------------

# Point LOCAL at the mode the session was made in.
use_session() {
  local m
  m=$(tmx show -t "=$1:" -v @fleet-mode 2>/dev/null) || return 1
  if [ "$m" = local ]; then LOCAL=1; else LOCAL=0; fi
}

# The session a sync or hint acts on: -t, else the current one, else the
# default; a session fleet did not make falls back to fleet or fleet-<host>.
# Called as $(...), so the caller runs use_session on the result.
target_session() {
  local s=${1:-}
  [ -n "$s" ] || [ -z "${TMUX:-}" ] || s=$(tmx display -p '#S' 2>/dev/null)
  [ -n "$s" ] || s=$(default_session)
  if use_session "$s"; then echo "$s"; return; fi
  for s in fleet "fleet-$(local_host)"; do
    if use_session "$s"; then echo "$s"; return; fi
  done
  return 1
}

# Lay the session out from its fleet.json; see the spec's *Sync*.
sync_layout() {
  local s=$1 d json g pid entry ended host guest ip repo branch live sock title w wid have
  d=$(sdir "$s"); json=$d/fleet.json
  # Overview: one pane per guest.
  have=$(tmx list-panes -t "=$s:overview" -F '#{@fleet-guest}' 2>/dev/null)
  while read -r g; do
    grep -qxF -- "$g" <<<"$have" && continue
    pid=$(tmx split-window -d -t "=$s:overview" -P -F '#{pane_id}' "$(self_cmd _overview "$s" "$g")") || continue
    tmx set -p -t "$pid" @fleet-guest "$g"
    tmx select-layout -t "=$s:overview" tiled >/dev/null
  done < <(jq -r '.[] | select(.guest != "-") | .guest' "$json")

  declare -A att=() paned=()
  while IFS=$'\t' read -r entry _; do att[$entry]=1; done < <(attachable "$json")
  # Tagged agent panes.
  while IFS=$'\t' read -r pid entry ended; do
    [ -n "$entry" ] || continue
    if [ -n "${att[$entry]:-}" ]; then
      if [ "$ended" = 1 ]; then tmx kill-pane -t "$pid"; else paned[$entry]=1; fi
      continue
    fi
    title=$(jq -r --arg e "$entry" 'def q: if . == null or . == "" then "?" else tostring end;
      first(.[] | .guest as $g | .rows[]? | select(.entry == $e) | "\($g) · \(.branch | q) · \(.live | q)") // empty' "$json")
    if [ -n "$title" ]; then tmx set -p -t "$pid" @fleet-title "$title"   # blocked or stopped
    elif [ "$ended" = 1 ]; then tmx kill-pane -t "$pid"                   # gone, and its attach has ended
    fi
  done < <(tmx list-panes -s -t "=$s" -F $'#{pane_id}\t#{@fleet-entry}\t#{@fleet-ended}')

  # A pane for each attachable entry that has none, by host then repo.
  while IFS=$'\t' read -r entry host guest ip repo branch live sock; do
    [ -z "${paned[$entry]:-}" ] || continue
    w="$host·$repo" pid=''
    wid=$(tmx list-windows -t "=$s" -F $'#{window_id}\t#{window_name}' | awk -F '\t' -v n="$w" '$2 == n { id = $1 } END { print id }')
    if [ -n "$wid" ] && pid=$(tmx split-window -d -t "$wid" -P -F '#{pane_id}' "$(self_cmd _attach "$ip" "$sock")" 2>/dev/null); then
      tmx select-layout -t "$wid" tiled >/dev/null
    else
      pid=$(tmx new-window -d -t "=$s:" -n "$w" -P -F '#{pane_id}' "$(self_cmd _attach "$ip" "$sock")") || continue
    fi
    tmx set -p -t "$pid" @fleet-entry "$entry" 2>/dev/null
    tmx set -p -t "$pid" @fleet-title "$guest · $branch · $live" 2>/dev/null
  done < <(attachable "$json" | sort -t $'\t' -k2,2 -k5,5)
}
```

- [ ] **Step 5: Add the commands and pane commands** (after `cmd_status`'s section header, before
`cmd_status`):

```bash
cmd_up() {
  local s pid first
  s=$(default_session)
  if tmx has-session -t "=$s" 2>/dev/null; then
    # The marker lives as long as the server: a session without it was
    # restored by resurrect into a new server, untagged, so rebuild it.
    [ "$(tmx show -gv "@fleet-booted-$s" 2>/dev/null)" = 1 ] && return 0
    tmx kill-session -t "=$s"
  fi
  echo "fleet: discovering guests..." >&2
  discover "$(sdir "$s")/fleet.json"
  first=$(jq -r '[.[] | select(.guest != "-")][0].guest // "-"' "$(sdir "$s")/fleet.json")
  pid=$(tmx new-session -d -s "$s" -n overview -x 200 -y 50 -P -F '#{pane_id}' "$(self_cmd _overview "$s" "$first")") \
    || die "could not start tmux session $s"
  tmx set -p -t "$pid" @fleet-guest "$first"
  if [ "$LOCAL" = 1 ]; then tmx set -t "=$s:" @fleet-mode local; else tmx set -t "=$s:" @fleet-mode remote; fi
  tmx set -g "@fleet-booted-$s" 1
  sync_layout "$s"
}

cmd_sync() {
  local s
  s=$(target_session "${1:-}") || die "no fleet session; start one with: fleet"
  use_session "$s"   # target_session ran in a subshell
  discover "$(sdir "$s")/fleet.json"
  sync_layout "$s"
}
```

and after `cmd_status`:

```bash
# Pane command: attach to one session's dtach. C-] detaches (the pane closes,
# the agent runs on); when the session itself ends, the pane stays, marked
# @fleet-ended, until the next sync.
cmd__attach() {
  local ip=$1 sock=$2
  ssh -t "${SSH_OPTS[@]}" "$GUEST_USER@$ip" "dtach -a $(printf %q "$sock") -e '^]' -r winch"
  # shellcheck disable=SC2029  # $sock is quoted here on purpose, for the remote shell
  if ssh "${SSH_OPTS[@]}" "$GUEST_USER@$ip" "test -S $(printf %q "$sock")" </dev/null 2>/dev/null; then exit 0; fi
  tmx set -p -t "${TMUX_PANE:-}" @fleet-ended 1
  echo "[fleet] session ended; prefix F syncs"
  exec tail -f /dev/null
}

# Pane command: one guest's status, every FLEET_OVERVIEW_INTERVAL seconds.
cmd__overview() {
  local s=$1 g=$2 ip out
  while :; do
    ip=$(jq -r --arg g "$g" 'first(.[] | select(.guest == $g) | .ip) // "-"' "$(sdir "$s")/fleet.json" 2>/dev/null)
    out=$(status_of "$g" "$ip")
    clear
    printf '== %s (%s) %s\n%s\n' "$g" "$ip" "$(date +%H:%M:%S)" "$out"
    sleep "${FLEET_OVERVIEW_INTERVAL:-30}"
  done
}
```

and these cases in `main`, after `case $cmd in`:

```bash
    attach)
      cmd_up || exit 1
      if [ -n "${TMUX:-}" ]; then tmx switch-client -t "=$(default_session)"
      else exec tmux ${FLEET_TMUX_SOCKET:+-L "$FLEET_TMUX_SOCKET"} attach -t "=$(default_session)"; fi ;;
    up) cmd_up ;;
    sync) if [ "${1:-}" = -t ]; then cmd_sync "${2:-}"; else cmd_sync; fi ;;
    _overview) cmd__overview "$@" ;;
    _attach) cmd__attach "$@" ;;
```

- [ ] **Step 6: Run the tests and shellcheck**

Run: `bats tests/ && shellcheck tmux/dot-local/bin/fleet tests/stub/*`
Expected: `17 tests, 0 failures`; shellcheck prints nothing. Run `bats tests/` twice more: the ended/attached
tests poll, and must not flake.

- [ ] **Step 7: Commit and push**

```bash
git add tmux/dot-local/bin/fleet tests/fleet.bats
git commit -m "fleet: the fleet session, synced on request

fleet up builds session fleet (fleet-<host> with --local): an overview pane
per guest, then a <host>·<repo> window per repo with one pane per session
running under dtach, attached over ssh with C-] as detach key. fleet sync
adds panes for new sessions, closes ended panes whose session is gone,
retitles blocked ones, and never touches a pane it did not make; a guest
failing one probe keeps its panes. A session restored into a new tmux
server (no @fleet-booted marker) is rebuilt."
git push origin master
```

### Task 4: the status-bar hint

Covers D10.

**Files:**
- Modify: `tmux/dot-local/bin/fleet`
- Modify: `tests/fleet.bats`

**Interfaces:**
- Consumes: `discover`, `attachable`, `target_session`, `use_session`, `sdir`, `tmx` (Tasks 2–3).
- Produces: `hint_write S` (writes `<state>/S/hint` from `fleet.json`, no ssh); `hint_refresh S` (discover, then
  write); `fleet hint [-t S] [--refresh]` (cats S's hint, else `fleet`'s; always exit 0; prints nothing with no
  cache); `fleet _hintloop S` (started by `cmd_up` through `run-shell -b`; a pid file keeps it to one per
  session; loops while the session exists).

- [ ] **Step 1: Write the failing tests.** Append to `tests/fleet.bats`:

```bash
@test "hint: counts per host and unpaned entries (D10)" {
  "$FLEET" up
  add_row 192.168.122.51 "$NEW_ROW"
  run "$FLEET" hint -t fleet --refresh
  [ "$status" -eq 0 ]
  [ "$output" = "nixos 3▶ 2⚠ · thinkcentre 1▶ 0⚠ · ↻1" ]
  run "$FLEET" hint -t fleet
  [ "$output" = "nixos 3▶ 2⚠ · thinkcentre 1▶ 0⚠ · ↻1" ]
}

@test "hint: an unreachable host shows ✗; no cache prints nothing (D10)" {
  run "$FLEET" hint -t fleet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  "$FLEET" up
  run "$FLEET" hint -t fleet
  [ "$output" = "nixos 2▶ 2⚠ · thinkcentre ✗" ]
}

@test "sync and hint from a session fleet did not make act on fleet's (prefix F anywhere)" {
  "$FLEET" up
  t new-session -d -s mine 'sleep 600'
  add_row 192.168.122.51 "$NEW_ROW"
  run "$FLEET" sync -t mine
  [ "$status" -eq 0 ]
  [[ "$(entries)" == *e-nixed-2* ]]
  [ "$(t list-panes -t =mine -F x | wc -l)" -eq 1 ]
  run "$FLEET" hint -t mine
  [ "$output" = "nixos 3▶ 2⚠ · thinkcentre 1▶ 0⚠" ]
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `bats tests/`
Expected: 17 pass; the 3 new ones fail (`fleet hint` prints the usage).

- [ ] **Step 3: Add the hint functions** (after `sync_layout`):

```bash
# --- hint ----------------------------------------------------------------

# Write <state>/<s>/hint from its fleet.json: `<host> N▶ M⚠` per host, then
# `↻K` for attachable entries with no pane.
hint_write() {
  local s=$1 d k entry
  d=$(sdir "$s")
  declare -A paned=()
  while read -r entry; do [ -z "$entry" ] || paned[$entry]=1; done \
    < <(tmx list-panes -s -t "=$s" -F '#{@fleet-entry}' 2>/dev/null)
  k=0
  while IFS=$'\t' read -r entry _; do [ -n "${paned[$entry]:-}" ] || k=$((k + 1)); done < <(attachable "$d/fleet.json")
  jq -r --argjson k "$k" '
    group_by(.host) | map(.[0].host as $h
      | if all(.[]; .status != "ok") then "\($h) ✗"
        else [.[] | select(.status == "ok") | .rows[]] as $r
          | "\($h) \([$r[] | select(.live == "alive" and (.kind // "") == "")] | length)▶ \([$r[] | select((.kind // "") != "" or .state == "blocked")] | length)⚠"
        end)
    | join(" · ") + (if $k > 0 then " · ↻\($k)" else "" end)' "$d/fleet.json" > "$d/hint.tmp" && mv -f "$d/hint.tmp" "$d/hint"
}

hint_refresh() { discover "$(sdir "$1")/fleet.json" && hint_write "$1"; }
```

`cmd_hint` after `cmd_sync`, and `cmd__hintloop` after `cmd__overview`:

```bash
cmd_hint() {
  local t='' refresh=0 s
  while [ $# -gt 0 ]; do
    case $1 in -t) t=${2:-}; shift ;; --refresh) refresh=1 ;; esac
    shift
  done
  if [ "$refresh" = 1 ]; then
    s=$(target_session "$t") || exit 0
    use_session "$s"
    hint_refresh "$s"
  fi
  [ -n "$t" ] && [ -r "$(sdir "$t")/hint" ] && { cat "$(sdir "$t")/hint"; exit 0; }
  cat "$(sdir fleet)/hint" 2>/dev/null
  exit 0
}

# Background (run-shell -b): refresh the hint while the session lives.
cmd__hintloop() {
  local s=$1 pidf
  pidf=$(sdir "$s")/hintloop.pid
  mkdir -p "$(sdir "$s")"
  if [ -r "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then return 0; fi
  echo $$ > "$pidf"
  use_session "$s" || return 0
  while tmx has-session -t "=$s" 2>/dev/null; do
    hint_refresh "$s"
    sleep "${FLEET_HINT_INTERVAL:-60}"
  done
  rm -f "$pidf"
}
```

In `cmd_up`, after `tmx set -g "@fleet-booted-$s" 1`, add

```bash
  [ -n "${FLEET_NO_HINTLOOP:-}" ] || tmx run-shell -b "$(self_cmd _hintloop "$s")"
```

and as the last line of both `cmd_up` and `cmd_sync` add `  hint_write "$s"`. In `main` add:

```bash
    hint) cmd_hint "$@" ;;
    _hintloop) cmd__hintloop "$@" ;;
```

- [ ] **Step 4: Run the tests and shellcheck**

Run: `bats tests/ && shellcheck tmux/dot-local/bin/fleet tests/stub/*`
Expected: `20 tests, 0 failures`.

- [ ] **Step 5: Smoke the loop and the overview pane** (bats sets `FLEET_NO_HINTLOOP`, so the loop is untested
there):

```bash
fx=$(mktemp -d); cp -r tests/fixtures/. "$fx"
export FLEET_FIXTURES=$fx PATH="$PWD/tests/stub:$PATH" FLEET_HOSTS_FILE=$fx/hosts FLEET_STATE=$fx/state \
  FLEET_TMUX_SOCKET=smoke FLEET_TMUX_CONF=/dev/null FLEET_HINT_INTERVAL=1 FLEET_OVERVIEW_INTERVAL=1
unset TMUX
tmux/dot-local/bin/fleet up; sleep 3
ls "$fx/state/fleet"; cat "$fx/state/fleet/hint"; echo
tmux -L smoke capture-pane -p -t =fleet:overview.0 | head -3
tmux -L smoke kill-server
```

Expected: `fleet.json hint hintloop.pid`; `nixos 2▶ 2⚠ · thinkcentre 1▶ 0⚠`; the pane shows
`== agentvm-repos (192.168.122.51) HH:MM:SS` then `table of 192.168.122.51`. (The pid file outlives a killed
server; the next loop sees its pid is not running and takes over.)

- [ ] **Step 6: Commit and push**

```bash
git add tmux/dot-local/bin/fleet tests/fleet.bats
git commit -m "fleet: status-bar hint from a cached file

A loop per fleet session rediscovers every 60 s and writes
'<host> N▶ M⚠ · … · ↻K' to a file; status-right only cats it, so drawing the
bar never runs ssh. ↻K counts sessions that have no pane yet: prefix F adds
them."
git push origin master
```

### Task 5: `fleet doctor`, README, the user's first run

Covers D14, the README's fleet setup, and the spec's *Early output*.

**Files:**
- Modify: `tmux/dot-local/bin/fleet`
- Modify: `tests/fleet.bats`
- Modify: `README.md` (append to the `## tmux` section)

**Interfaces:**
- Consumes: `guests`, `hosts_file`, `SSH_OPTS`, `GUEST_USER`, `LOCAL` (Task 2).
- Produces: `fleet doctor`: one `ok    …` / `FAIL  …` line per check, exit 1 when any failed. Checks: `tmux jq ssh
  fzf` on PATH; remote mode: `ssh <dest> true` per hosts line, and `ip route get <ip>` mentions `tailscale` per
  guest (failure names `tailscale up --accept-routes`); every mode: `ssh agentvm@<ip> command -v dtach` per guest,
  its failure naming `ssh agentvm@<ip> (<guest>)`.

- [ ] **Step 1: Write the failing tests.** Append:

```bash
@test "doctor: names the guest whose ssh fails, exits 1 (D14)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL  ssh agentvm@192.168.123.51 (agentvm-thinkrepos)'* ]]
  [[ "$output" == *'ok    ssh agentvm@192.168.122.51 (agentvm-repos)'* ]]
}

@test "doctor: all good exits 0 (D14)" {
  run "$FLEET" doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *FAIL* ]]
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `bats tests/`
Expected: 20 pass, the 2 doctor tests fail.

- [ ] **Step 3: Implement.** Add after `cmd_hint`:

```bash
cmd_doctor() {
  local fail=0 c dest h g ip
  ok() { echo "ok    $*"; }
  bad() { echo "FAIL  $*"; fail=1; }
  for c in tmux jq ssh fzf; do
    if command -v "$c" >/dev/null; then ok "$c"; else bad "$c not on PATH"; fi
  done
  if [ "$LOCAL" = 0 ]; then
    if [ -r "$(hosts_file)" ]; then
      while read -r dest; do
        case $dest in ''|'#'*) continue ;; esac
        if ssh "${SSH_OPTS[@]}" "$dest" true </dev/null >/dev/null 2>&1; then ok "ssh $dest"; else bad "ssh $dest"; fi
      done < "$(hosts_file)"
    else
      bad "no hosts file $(hosts_file)"
    fi
  fi
  while read -r h g ip; do
    [ "$g" != - ] || continue
    if [ "$LOCAL" = 0 ]; then
      if ip route get "$ip" 2>/dev/null | grep -q tailscale; then ok "route to $ip via tailscale"
      else bad "no tailnet route to $ip ($g on $h): tailscale up --accept-routes"; fi
    fi
    if ssh "${SSH_OPTS[@]}" "$GUEST_USER@$ip" command -v dtach </dev/null >/dev/null 2>&1; then ok "ssh $GUEST_USER@$ip ($g): dtach"
    else bad "ssh $GUEST_USER@$ip ($g): no ssh, or no dtach there"; fi
  done < <(guests)
  return "$fail"
}
```

and in `main`:

```bash
    doctor) cmd_doctor ;;
```

(Inside a `while read` loop every ssh needs `</dev/null`, or it eats the loop's input; and the loop reads
`done < <(guests)`, not a pipe, so `fail` survives it.)

- [ ] **Step 4: Run all checks**

Run: `bats tests/ && shellcheck tmux/dot-local/bin/fleet tests/stub/* && bash -n tmux/dot-local/bin/fleet`
Expected: `22 tests, 0 failures`; shellcheck silent.

- [ ] **Step 5: README.** Append to the `## tmux` section:

````markdown
### fleet: every agent session in one tmux session

`fleet` (`tmux/dot-local/bin/fleet`) builds a tmux session `fleet`: window `overview` shows each microVM guest's
supervisor table (`status.sh`, refreshed every 30 s), then one window per `<host>·<repo>` with one pane per agent
session running under dtach, attached over ssh. The hosts are in `~/.config/fleet/hosts` (one ssh destination
per line, from this package). On a host itself, `fleet --local` shows that host's guests in `fleet-<host>`.

Setup on the laptop, after the tmux setup above: `tailscale up --accept-routes` (the guests are reached over the
hosts' advertised routes), then `fleet doctor`, which names the first thing missing.

| | |
|---|---|
| `fleet` | start the session if needed, then attach (or switch to it from inside tmux) |
| `prefix F` / `fleet sync` | add panes for new sessions, close panes of sessions that ended; nothing syncs on its own |
| `C-]` in an agent pane | detach: the pane closes, the agent keeps running; `prefix F` brings the pane back |
| status bar `nixos 3▶ 2⚠ · ↻1` | per host: live sessions, sessions needing you (stalled or blocked); `↻`: sessions with no pane yet (`prefix F`); `✗`: host unreachable |
| `fleet ls`, `fleet status <guest>`, `fleet help` | guests, one guest's table, the rest |

Agent panes have an orange title on their border (`<guest> · <branch> · <state>`); your own panes show their
command. After a laptop reboot resurrect restores your sessions, and `fleet` rebuilds its own.

Tests: `sudo pacman -S bash-bats shellcheck`, then `bats tests/` from the repo root (stub ssh, private tmux
server; nothing reaches a real host).
````

- [ ] **Step 6: Commit and push**

```bash
git add tmux/dot-local/bin/fleet tests/fleet.bats README.md
git commit -m "fleet: doctor, and the README's fleet setup

fleet doctor checks each prerequisite (tools, ssh to hosts and guests, the
tailnet route to each guest, dtach on it) and names the one that fails."
git push origin master
```

- [ ] **Step 7: Early output: the user's first run (manual, on the laptop).** Ask the user to: `git pull`;
`mkdir -p ~/.local/bin ~/.config` if missing, then `stow -t "$HOME" --dotfiles -R tmux` and check
`readlink ~/.local/bin/fleet` and `readlink ~/.config/fleet/hosts` point at single files in the repo (not
`~/.local/bin` itself); `fleet doctor`; `fleet`. Then send a screenshot or `tmux capture-pane -p` of the
overview and of one `<host>·<repo>` window with an agent attached. Their checks (spec *Testing*, laptop):
typing in an agent pane reaches the agent; `C-]` leaves it running (`fleet status <guest>` still shows it
`alive`); a session started in a guest afterwards shows as `↻1` within a minute, then as a pane after
`prefix F`; agent panes are told apart from their own shells (D12). Fix what they report before slice 3.

---

# Slice 3 (nixed): the hosts use dotfiles' config

### Task 6: `modules/home.nix` links to dotfiles; guides

Covers D3. Change mode in nixed: branch `change/tmux-dotfiles`, its own worktree, draft PR, local review round,
merge (nixed's `AGENTS.md`, *Development workflow*). Needs the user's `switch` on `nixos` and deploy to
`thinkcentre`, with `~/repos/dotfiles` cloned on `thinkcentre` first.

**Files (nixed):**
- Modify: `modules/home.nix` (drop `programs.tmux`, lines 22–60 today; add the block below)
- Modify: `docs/guides/tmux.md` (rewrite: short host note)
- Modify: `docs/guides/host-operations.md` (*First-time setup on a new machine*: clone dotfiles; *Deploying to
  the ThinkCentre* or *Installing the ThinkCentre*: the one-time clone there)
- Modify: `AGENTS.md` (the *Read on demand* row for `docs/guides/tmux.md` names `programs.tmux`), `BACKLOG.md`
  (*Next*: the switch line)
- grep the repo for `programs.tmux` and `mirrored` and rewrite each current-design mention (nixed's rule: a
  change updates every doc it makes stale).

**Interfaces:**
- Consumes: dotfiles' `tmux/dot-config/tmux/tmux.conf` and `tmux/dot-local/bin/fleet` at
  `/home/theo/repos/dotfiles` on each host.
- Plugin entry files (checked against nixpkgs while planning; each is the attr's `.rtp`):
  `pkgs.tmuxPlugins.{catppuccin (2.1.3), tmux-sessionx, extrakto, yank, resurrect, continuum}`.

**Inputs from slices 1–2's final review:**
- Guest ssh: under `--local`, `fleet` passes `-i ~/.agentvm/keys/id_ed25519` itself when that file exists (it does
  on both hosts), so nothing in nixed has to set up a key for it.
- `~/.local/bin` is not on the hosts' `PATH`: Step 2 adds `home.sessionPath = [ "$HOME/.local/bin" ];`.
- Keeping `fleet`/`fleet-*` out of resurrect's saves is a hook in `tmux.conf` itself; `plugins.tmux` needs
  nothing for it.
- `fleet doctor` cannot catch a dangling `tmux.conf` link (`fleet` is linked the same way, so it dangles too):
  the guide's setup step checks the links with `readlink -e` (Step 4).

- [ ] **Step 1: The check that fails today**

Run (nixed root): `grep -n 'programs.tmux' modules/home.nix`
Expected now: line 24. After the change: nothing.

- [ ] **Step 2: Edit `modules/home.nix`.** Change the first line to `{ config, lib, pkgs, ... }:`, add a `let`
before the attribute set:

```nix
let
  # The tmux config and fleet live in the dotfiles repo, linked to this host's
  # checkout of it rather than taken as a flake input: dotfiles is private, so a
  # root nixos-rebuild would need a GitHub token to fetch it, and a link picks up
  # edits without a rebuild. A host without ~/repos/dotfiles gets a dangling
  # link (docs/guides/host-operations.md, first-time setup).
  dotfiles = "/home/theo/repos/dotfiles";
  linkDotfile = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  # continuum last: it hooks status-right as it loads.
  tmuxPlugins = with pkgs.tmuxPlugins; [ catppuccin tmux-sessionx extrakto yank resurrect continuum ];
in
```

replace the `programs.tmux` block (and its comment) with:

```nix
  # tmux: dotfiles' tmux.conf, which sources plugins.tmux last. Here that file
  # loads the plugins from nixpkgs (the laptop's loads them through TPM); their
  # options are in tmux.conf. No programs.tmux: it writes its own tmux.conf,
  # which would collide with the link. Keys and fleet: dotfiles' README.
  xdg.configFile."tmux/tmux.conf".source = linkDotfile "tmux/dot-config/tmux/tmux.conf";
  xdg.configFile."tmux/plugins.tmux".text = ''
    # Generated by nixed's modules/home.nix. Hosts never auto-restore.
    set -g @continuum-restore 'off'
  '' + lib.concatMapStrings (p: "run-shell ${p.rtp}\n") tmuxPlugins;
  # fleet --local shows this host's guests. tmux.conf's key binding and status
  # bar run ~/.local/bin/fleet by full path; sessionPath puts it on the shell's
  # PATH too, which ~/.local/bin is not on here.
  home.file.".local/bin/fleet".source = linkDotfile "tmux/dot-local/bin/fleet";
  home.sessionPath = [ "$HOME/.local/bin" ];
```

and extend `home.packages` (keep its comment; add a line to it: `tmux, jq and fzf: for dotfiles' tmux config and
fleet`):

```nix
  home.packages = with pkgs; [
    eduvpn-client
    ripgrep fd bat eza dust duf sd yq-go difftastic ast-grep tokei hyperfine
    tmux jq fzf
  ];
```

(`tmux` is also in `modules/common.nix`'s system packages, for root; keep both.)

- [ ] **Step 3: Rewrite `docs/guides/tmux.md`** as a short host note: the config is dotfiles'
`tmux/dot-config/tmux/tmux.conf`, linked by `modules/home.nix` to `~/repos/dotfiles` on each host (edits there
apply on `prefix r`, no rebuild); plugins come from nixpkgs through the generated `~/.config/tmux/plugins.tmux`;
keys, plugins and `fleet` are in dotfiles' README; on a host, `fleet --local` shows that host's guests. Keep the
existing everyday-key sections that still hold (sessions, windows, panes, copy mode), and add `prefix f`
(sessionx), `prefix Tab` (extrakto), `prefix F` (fleet sync).

- [ ] **Step 4: `docs/guides/host-operations.md`.** In *First-time setup on a new machine*, step 1 becomes: clone
this repo **and** dotfiles into `~/repos` (`~/repos/nixed`, `~/repos/dotfiles`), noting that home-manager links
the tmux config and `fleet` into the dotfiles checkout and they dangle without it, so the step ends with a check
that both resolve: `readlink -e ~/.config/tmux/tmux.conf ~/.local/bin/fleet` prints two paths (`fleet doctor`
can't catch this: it is one of the dangling links). Where the guide sets up
`thinkcentre`, add the one-time `git clone <dotfiles remote> ~/repos/dotfiles` as `theo` before the deploy that
carries this change.

- [ ] **Step 5: Stale mentions.** `grep -rn 'programs.tmux\|mirrored by hand\|kept in sync by hand' --exclude-dir=.methodology .`
and rewrite each current-design hit (the `AGENTS.md` *Read on demand* row for `docs/guides/tmux.md` becomes "you
change the host's tmux setup (`modules/home.nix` links dotfiles' config), or want the host's key bindings").
History (handoffs, investigations) stays as written.

- [ ] **Step 6: Run nixed's check** (its `AGENTS.md`, *Setup*, the block that prints each failure), then evaluate
the generated file through the chroot store (`docs/knowledge/vm-nix-eval.md`; slow):

```bash
nix --store /var/tmp/nixed-store --extra-experimental-features 'nix-command flakes' eval --raw \
  "path:$PWD#nixosConfigurations.nixos.config.home-manager.users.theo.xdg.configFile.\"tmux/plugins.tmux\".text"
```

Expected: the check prints nothing; the eval prints the `@continuum-restore 'off'` line and six `run-shell
/nix/store/…/*.tmux` lines, continuum last.

- [ ] **Step 7: Commit, PR, review, merge.** Commit with `git commit -s` (body: why links instead of a flake
input; what the host must do: clone dotfiles on `thinkcentre`, `switch` on `nixos`, deploy `thinkcentre`), push
`change/tmux-dotfiles`, PR body with the plan above and "needs: `nixos-rebuild switch` on `nixos`, deploy
`thinkcentre` after cloning dotfiles there". Local review round, address findings, merge. Add to `BACKLOG.md`
*Next*: `switch for #<n>: hosts use dotfiles' tmux config and fleet (clone ~/repos/dotfiles on thinkcentre first);
waits on the user`.

- [ ] **Step 8: After the user's switch (manual, on `nixos`).** D1/D3's checks:
`readlink -e ~/.config/tmux/tmux.conf ~/.local/bin/fleet` both point into `~/repos/dotfiles`; `grep -c '^run-shell'
~/.config/tmux/plugins.tmux` prints `6`; in a new tmux server `tmux list-keys | grep -E 'sessionx|extrakto'`
shows both and `tmux show -g @continuum-restore` is `off`; `fleet --local` shows `nixos`'s guests. Same on
`thinkcentre`. Then the BACKLOG line goes.

# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a
package whose contents mirror `$HOME`, using Stow's `--dotfiles` convention: a path segment
named `dot-foo` gets symlinked as `.foo`.

## Install

```shell
sudo apt install stow   # if not already installed
stow -t "$HOME" --dotfiles -R zsh vim doom x11 git alacritty autostart dunst i3 nvim picom polybar rofi sxhkd systemd tmux vscode
```

(run from the repo root; `-R` restows, so it's safe to rerun after editing a package or to
apply just the packages you list, e.g. `stow -t "$HOME" --dotfiles -R git` for a single one).

The `git` package includes `dot-config/git/ignore`, which Git treats as the default global
excludes file, so patterns there (currently `.agentvm.yml`) are ignored in every repo without
touching any project's own `.gitignore`.

## tmux

`tmux/` is the one tmux config for this laptop and the NixOS hosts: nixed links each host's
`~/.config/tmux/tmux.conf` to its own checkout of this repo (`~/repos/dotfiles`). `tmux.conf` sources
`plugins.tmux` last; here that file loads the plugins through TPM, on the hosts nixed generates one that loads
them from nixpkgs. Prefix is `C-b`.

Laptop (Arch) setup, once:

```shell
sudo pacman -S tmux jq fzf xclip   # xclip: tmux-yank's clipboard on X11
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
starts. Saves leave out the `fleet` and `fleet-*` sessions (a hook in `tmux.conf`; a restore would merge into a
fleet session already up), and `ssh` panes are not restored anyway (resurrect's default): fleet rebuilds its own
session (below).

### Update and run

After pulling changes to `tmux/` (e.g. the gruvbox theme, which dropped catppuccin):

```shell
# Laptop
cd ~/repos/dotfiles && git pull
stow -t "$HOME" --dotfiles -R tmux    # links any new file; edits to linked ones are live already
# in tmux: prefix alt-u removes plugins no longer listed (catppuccin), then prefix r reloads the config
# and prefix F in the fleet session: its tabs, pane borders, overview and hint take the new look

# Each NixOS host: the config is linked to ~/repos/dotfiles, so a pull is the update
cd ~/repos/dotfiles && git pull
# a plugin added or removed also needs nixed's switch (it lists the hosts' plugins); then, in tmux:
# prefix r, and prefix F in fleet-<host>
```

`prefix r` restyles everything already open; `prefix F` then brings fleet's session forward: it renames tabs from
an older fleet (`nixos·nixed` becomes `nixed`), retags agent panes (until it runs, their borders show the bare
entry id), and restarts the overview panes and the hint loop an older fleet started, since a pull changes the file,
not the processes already running it. (That restart keys on a version stamp, `@fleet-overview` on each
overview pane and the second field of `hintloop.pid`: a change to what either loop does, or how often, bumps its
stamp in `fleet`, or prefix F leaves the old loop running.) If a reload leaves stale styling behind, `tmux kill-server` starts clean;
resurrect brings your own sessions back, and `fleet` rebuilds its own.

Running it: `fleet` on the laptop (every host in `~/.config/fleet/hosts`), `fleet --local` on a host (that host's
guests only). Inside: `prefix F` syncs panes with the running sessions, `C-]` detaches from an agent pane, and
`fleet doctor` says what is missing when something doesn't show. Details in *fleet* below.

### fleet: every agent session in one tmux session

`fleet` (`tmux/dot-local/bin/fleet`) builds a tmux session `fleet`: window `overview` shows each microVM guest's
supervisor table (`status.sh`, refreshed every 15 s), then one window per repo (its tab coloured for its host) with one pane per agent
session running under dtach, attached over ssh. The hosts are in `~/.config/fleet/hosts` (one ssh destination
per line, from this package). On a host itself, `fleet --local` shows that host's guests in `fleet-<host>`.

Setup on the laptop, after the tmux setup above: `tailscale up --accept-routes` (the guests are reached over the
hosts' advertised routes). The guests trust only their own host's agentvm key, so copy each host's key once and
let `~/.ssh/config` pick it by subnet (nixos's guests are on `192.168.122.*`, thinkcentre's on `192.168.123.*`):

```shell
scp theo@nixos:.agentvm/keys/id_ed25519 ~/.ssh/agentvm-nixos
scp theo@thinkcentre:.agentvm/keys/id_ed25519 ~/.ssh/agentvm-thinkcentre
cat >> ~/.ssh/config <<'CONF'
Host 192.168.122.*
  User agentvm
  IdentityFile ~/.ssh/agentvm-nixos
  StrictHostKeyChecking accept-new
Host 192.168.123.*
  User agentvm
  IdentityFile ~/.ssh/agentvm-thinkcentre
  StrictHostKeyChecking accept-new
CONF
```

Then `fleet doctor`, which names the first thing missing (a guest ssh that fails shows ssh's own reason). Guest ssh
always adds `StrictHostKeyChecking=accept-new`; `AGENTVM_KEY=<file>` makes it add `-i <file>` too. On a host,
`fleet --local` uses that host's `~/.agentvm/keys/id_ed25519` by itself.

| | |
|---|---|
| `fleet` | start the session if needed, then attach (or switch to it from inside tmux) |
| `prefix F` / `fleet sync` | add panes for new sessions, close panes of sessions that ended; nothing syncs on its own |
| overview window | one row per guest: its `status.sh` table, and to its right its resources (btop's CPU and memory/disks boxes, over ssh; htop where the guest has no btop) |
| `prefix F` in a pane ssh'd into a guest | after `claudes -d` there: that pane becomes the session's pane, no second one to close |
| `C-]` in an agent pane | detach: the pane closes, the agent keeps running; `prefix F` brings the pane back |
| status bar `nixos ●3 ◆2  ↻1` | per host, in its tab colour: `●` live sessions, `◆` sessions needing you (stalled or blocked); `↻`: sessions with no pane yet (`prefix F`); `✗`: host unreachable |
| `fleet ls`, `fleet status <guest>`, `fleet help` | guests, one guest's table, the rest |

Agent panes show their state and host on their border (`● impl/x alive  nixos`, as of the last sync): `●` alive
(green), `○` waiting for a usage-limit reset, `◐` stalled (yellow), `◆` blocked on you (purple), `✗` dead (red),
`✓` done, `∅` gone (worktree removed), `·` ended early (grey).
Overview panes show their guest in its host's colour, the host, its `●`/`◆` counts and when it last refreshed, and
each `status.sh` row in its glyph's colour. Your
own panes show their command and directory; the focused pane's border is blue. The theme is gruvbox, written into
`tmux.conf` (no theme plugin), and needs no special font. After a laptop reboot resurrect restores your sessions, and `fleet` rebuilds its own.

Tests: `sudo pacman -S bash-bats shellcheck`, then `bats tests/` from the repo root (stub ssh, private tmux
server; nothing reaches a real host).

### xorg-conf (edge case)

`xorg-conf` is the one package that doesn't target `$HOME` — it targets `/etc`, so it needs
root and a separate command instead of being included in the bulk install above:

```shell
sudo stow -t /etc --dotfiles -R xorg-conf
```

The touchpad config is `X11/xorg.conf.d/99-touchpad.conf` (it used to be `70-touchpad.conf`;
if that old symlink is still in `/etc/X11/xorg.conf.d/`, delete it). Restart X to apply it.

## Code

Extensions aren't auto-installed (locally or on remote hosts) — install them on demand:

```shell
cat ./code/extensions.txt | xargs -L1 code --install-extension
```

For a remote SSH host, run the same command from a terminal on the remote (e.g. VS Code's
integrated terminal once connected), or use the `Remote-SSH: Install Local Extensions in SSH
Host...` command from the Command Palette.

After installing/removing extensions locally, run `./code/sync-extensions.sh` to refresh
`extensions.txt` from what's currently installed.

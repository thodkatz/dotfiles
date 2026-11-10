# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a
package whose contents mirror `$HOME`, using Stow's `--dotfiles` convention: a path segment
named `dot-foo` gets symlinked as `.foo`.

## Install

```shell
sudo apt install stow   # if not already installed
mkdir -p ~/.config/agent-deck ~/.local/bin   # so stow links agent-deck's files into them, not the directories
stow -t "$HOME" --dotfiles -R zsh vim doom x11 git alacritty autostart dunst i3 nvim picom polybar rofi sxhkd systemd tmux vscode agent-deck
agent-deck-install      # the pinned Agent Deck (below)
```

(run from the repo root; `-R` restows, so it's safe to rerun after editing a package or to
apply just the packages you list, e.g. `stow -t "$HOME" --dotfiles -R git` for a single one).

The `git` package includes `dot-config/git/ignore`, which Git treats as the default global
excludes file, so patterns there (currently `.agentvm.yml`) are ignored in every repo without
touching any project's own `.gitignore`.

`agent-deck` holds [Agent Deck](https://github.com/asheshgoplani/agent-deck)'s config
(`~/.config/agent-deck/config.toml`: self-updates off, each agentvm guest a `[remotes.<name>]`) and
`agent-deck-install`, which installs the pinned release (v1.16.38, its tarball's sha256 checked) into
`~/.local/bin/agent-deck` and does nothing when that version is already there. Run it on the laptop. Each guest needs the
same version, which deck runs over ssh: installed there by hand (the same URL and sha256) until agent-methodology
pins it for guests. Deck's own writes (`remote add`, its settings screen) replace
the stowed link with a copy: edit the file in dotfiles instead, then `stow -R agent-deck`.

## tmux

`tmux/` is the one tmux config for this laptop and the NixOS hosts: nixed links each host's
`~/.config/tmux/tmux.conf` to its own checkout of this repo (`~/repos/dotfiles`). `tmux.conf` sources
`plugins.tmux` last; here that file loads the plugins through TPM, on the hosts nixed generates one that loads
them from nixpkgs. Prefix is `C-a` (`C-a C-a` types a literal `C-a`). In a session attached from fleet's deck
window, `C-b` is that session's own tmux, on the guest, and Ctrl+Q goes back to deck.

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
mkdir -p ~/.config/agent-deck && stow -t "$HOME" --dotfiles -R tmux agent-deck   # links any new file; edits to linked ones are live already
agent-deck-install                    # once, and again after a pin bump
# in tmux: prefix alt-u removes plugins no longer listed (catppuccin), then prefix r reloads the config

# Each NixOS host: the config is linked to ~/repos/dotfiles, so a pull is the update
cd ~/repos/dotfiles && git pull
# a plugin added or removed also needs nixed's switch (it lists the hosts' plugins); then, in tmux: prefix r
# agent-deck and its config: from nixed's change/host-agent-deck (nixed PR #27), its switch links the config and runs
# agent-deck-install (home-manager), as stow and the line above do here
```

`prefix r` restyles everything already open. fleet's overview loop runs the `fleet` on disk each round, so a pull
reaches it within 30 s, no restart. A session an older fleet built (one window per agent session, kept in step by
`prefix F`) is rebuilt in the new layout by running `fleet` once, from outside that session (from inside it, `fleet`
would kill the session it runs in; detach first, or run it in another session). If a reload leaves stale styling
behind, `tmux kill-server` starts clean; resurrect brings your own sessions back, and `fleet` rebuilds its own.

Running it: `fleet` on the laptop (every host in `~/.config/fleet/hosts`), `fleet --local` on a host (that host's
guests only). Inside: window `deck` lists and attaches the sessions, window `overview` shows what needs you, and
`fleet doctor` says what is missing when something doesn't show. Details in *fleet* below.

### fleet: every agent session in one tmux session

`fleet` (`tmux/dot-local/bin/fleet`) builds a tmux session `fleet` with two windows (layout C, agent-methodology's
D20): window `deck` runs Agent Deck's TUI, each microVM guest one of its remotes (`agent-deck/dot-config/agent-deck/
config.toml`), where you list the agent sessions and attach one; window `overview` shows each guest's open inbox
items and supervisor rows, refreshed every 30 s, with the first guest's resources to its right. The hosts are in
`~/.config/fleet/hosts` (one ssh destination per line, from this package). On a host itself, `fleet --local` shows
that host's guests in `fleet-<host>`.

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

Then `fleet doctor`, which names the first thing missing: this machine's `agent-deck` (on PATH, at
`agent-deck-install`'s pin, with its config), each host's and guest's ssh (a guest ssh that fails shows ssh's own
reason), and each guest's ssh as the deck window makes it (`deck ssh`). Guest ssh
always adds `StrictHostKeyChecking=accept-new`; `AGENTVM_KEY=<file>` makes it add `-i <file>` too. On a host,
`fleet --local` uses that host's `~/.agentvm/keys/id_ed25519` by itself.

Setup on a host: the deck window's agent-deck runs a plain `ssh agentvm@<guest ip>` (no `-i`), so without a block in
`~/.ssh/config` naming the agentvm key it offers your own key, the guest refuses it, and the deck shows the remote as
unreachable (`auth failed`) while the overview, on fleet's `-i`, works. Add once, as theo, with the host's guest subnet
(nixos `192.168.122.*`, thinkcentre `192.168.123.*`):

```shell
cat >> ~/.ssh/config <<'CONF'
Match host 192.168.122.* localuser theo
  User agentvm
  IdentityFile ~/.agentvm/keys/id_ed25519
  StrictHostKeyChecking accept-new
CONF
```

`localuser theo` keeps it to the host: the guests read the host's `~/.ssh/config` too (at `/mnt/host-ssh`), and
there the path doesn't exist and would hide a guest's own key. `fleet --local doctor` then shows `ok    deck ssh`.

| | |
|---|---|
| `fleet` | start the session if needed, then attach (or switch to it from inside tmux) |
| deck window | first, when `agent-deck` is installed (`FLEET_DECK_CMD` names another command, empty for none; without it `fleet` says so and builds the overview alone, and the next `fleet` once it is installed rebuilds the session with it; a deck window you close, or quit with `q`, comes back with the next `fleet`): Agent Deck's TUI, the guests its remotes; Enter attaches a session, Ctrl+Q comes back. When the session you watched hands off (its successor's `prev` names it, and deck marked it viewed), the overview's next round opens the successor in the TUI, if the TUI is back on its list. Its first start asks to add Claude Code hooks (`y` or `n`); a deck already open elsewhere closes the window (one per profile) |
| overview window | each guest's open inbox items (`✉ #n kind branch`, and its `continue` command, or what it needs), then its status rows: `<branch> <mode> <activity> [kind] [gated #n]`; to its right the first guest's resources (btop's CPU and memory/disks boxes, over ssh; htop where the guest has no btop) |
| status bar `nixos ●3 ◆1 ✉1` | per host, in its colour: `●` live sessions (deck's activity working, idle or asking), `◆` asking, `✉` open inbox items (`◆` and `✉` left out at 0); `✗`: host unreachable. Rewritten by the overview's loop |
| `fleet ls`, `fleet status <guest>`, `fleet help` | guests, one guest's table, the rest |

Which session runs unattended shows in the overview's rows (`unattended`) and, inside each session, its own status
line. Your own panes show their command and directory on their border; the focused pane's border is blue. The theme
is gruvbox, written into `tmux.conf` (no theme plugin), and needs no special font. After a laptop reboot resurrect
restores your sessions, and `fleet` rebuilds its own.

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

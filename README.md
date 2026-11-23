# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a
package whose contents mirror `$HOME`, using Stow's `--dotfiles` convention: a path segment
named `dot-foo` gets symlinked as `.foo`.

## Install

```shell
sudo pacman -S stow     # if not already installed
sudo pacman -S otf-monaspace-nerdfonts   # alacritty's font: Monaspace Neon with Nerd Font icons (workmux's); 0.5 GB, all five Monaspace fonts
sudo pacman -S noto-fonts-emoji          # the dashboard's status icons: 🤖 💬 ✅
mkdir -p ~/.config/agent-methodology ~/.config/systemd/user ~/.local/bin   # so stow links files into them, not the directories
stow -t "$HOME" --dotfiles -R zsh vim doom x11 git alacritty autostart dunst i3 nvim picom polybar rofi sxhkd systemd tmux vscode scripts claude
npm install -g --prefix ~/.local @owloops/claude-powerline@1.32.8   # the status line's boxes (below); needs npm (Arch: `sudo pacman -S npm`)
```

(run from the repo root; `-R` restows, so it's safe to rerun after editing a package or to
apply just the packages you list, e.g. `stow -t "$HOME" --dotfiles -R git` for a single one).

The `git` package includes `dot-config/git/ignore`, which Git treats as the default global
excludes file, so patterns there (currently `.agentvm.yml`, and `.claude/worktrees/`, where agents make their
worktrees) are ignored in every repo without touching any project's own `.gitignore`.

`scripts` holds standalone tools in `~/.local/bin`. `battery-notify` sends a notification (via `notify-send`,
shown by dunst) when the battery drops to 20% and 10%, and a critical one at 5%, each once per discharge; plugging
in resets it. The `systemd` package's `battery-notify.timer` runs it every minute:
`systemctl --user enable --now battery-notify.timer` (needs `libnotify`).

`~/.config/systemd/user` must be a real directory (the `mkdir -p` above), not a stow link into this repo: otherwise
`systemctl --user enable` writes its `*.wants/` links into the checkout (they're git-ignored). To move an existing
link out:

```shell
cd ~/repos/dotfiles
stow -t "$HOME" --dotfiles -D systemd
mkdir -p ~/.config/systemd/user
mv systemd/dot-config/systemd/user/*.wants ~/.config/systemd/user/   # keeps what's enabled
stow -t "$HOME" --dotfiles -R systemd
systemctl --user daemon-reload
```

Volume, mic mute and brightness keys (`XF86AudioRaiseVolume`/`LowerVolume`/`Mute`/`MicMute`,
`XF86MonBrightnessUp`/`Down`) work under any window manager: `.xinitrc` (`x11`) starts
`sxhkd -c ~/.config/sxhkd/media-keys` (`sxhkd` package), which runs `media-key` (`scripts`). It steps by 5% and shows
the new level in a dunst notification. It needs `sudo pacman -S sxhkd brightnessctl libpulse` (`libpulse` gives
`pactl`, which works on PulseAudio and PipeWire); if brightness doesn't change, add yourself to the `video` group. Log in again to
start it, or run that `sxhkd` command once now.

## Terminal

Alacritty uses [Monaspace](https://monaspace.githubnext.com/) Neon 12, its Nerd Font build (`sudo pacman -S
otf-monaspace-nerdfonts`, family `Monaspace Neon NF`: the guests' workmux draws Nerd Font icons) with 4px extra
between lines, off-white `#e0e0e0` on `#141414`, and a lighter grey (`#808080`) for the secondary text Claude Code, git
and comments use. Alacritty shapes no ligatures, so neither Neon's nor its texture healing (a contextual alternate) show.
Alacritty reloads `alacritty.toml` on save.

For reading long output:

- In Claude Code, `/config` → theme → **dark-ansi**, so it draws with alacritty's colours (set per machine, in
  `~/.claude.json`, not here). `ctrl+o` opens the full transcript.
- Prose reads best at 80–110 characters a line, and Claude Code wraps to the full width: on a wide screen, run it
  in a tmux split rather than full-screen.
- `glow` (`sudo pacman -S glow`) shows a Markdown file formatted in the terminal.

## tmux

`tmux/` is the one tmux config for this laptop and the NixOS hosts: nixed links each host's
`~/.config/tmux/tmux.conf` to its own checkout of this repo (`~/repos/dotfiles`). `tmux.conf` sources
`plugins.tmux` last; here that file loads the plugins through TPM, on the hosts nixed generates one that loads
them from nixpkgs. Prefix is `C-a` (`C-a C-a` types a literal `C-a`). In fleet's window of a guest, `C-b` is the
guest's own tmux, where its agents run.

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
stow -t "$HOME" --dotfiles -R tmux    # links any new file; edits to linked ones are live already
# in tmux: prefix alt-u removes plugins no longer listed (catppuccin), then prefix r reloads the config

# Each NixOS host: the config is linked to ~/repos/dotfiles, so a pull is the update
cd ~/repos/dotfiles && git pull
# a plugin added or removed also needs nixed's switch (it lists the hosts' plugins); then, in tmux: prefix r
```

Once, after the pull that removed the `agent-deck` package (2026-11-22): on the laptop, its stowed links dangle; take
them off, and Agent Deck with them (a host's go with nixed's switch):

```shell
find ~/.config/agent-deck ~/.local/bin -maxdepth 1 -xtype l -lname '*dotfiles/agent-deck/*' -delete
rm -rf ~/.local/bin/agent-deck ~/.config/agent-deck   # deck itself and its config, if you keep no use for them
```

`prefix r` restyles everything already open. A session an older fleet built (its `deck` or `overview` window) is
rebuilt in the new layout by
running `fleet` once, from outside that session (from inside it, `fleet` says so and stops: detach first, or run it
in another session). If a reload leaves stale styling behind, `tmux kill-server` starts clean;
resurrect brings your own sessions back, and `fleet` rebuilds its own.

Running it: `fleet` on the laptop (every host in `~/.config/fleet/hosts`), `fleet --local` on a host (that host's
guests only), and `fleet doctor` says what is missing when something doesn't show. Details in *fleet* below.

### fleet: every agent session in one tmux session

`fleet` (`tmux/dot-local/bin/fleet`) attaches each microVM guest's own `agents` tmux session over ssh, where
agent-methodology's sessions run on [workmux](https://github.com/raine/workmux), a window per agent. The session
opens on its window `dashboard`, workmux's dashboard of every agent: Enter (or 1–9) on one goes to its window, and
`C-b w` comes back. fleet makes that window when it isn't there, and restarts the dashboard after each jump, which
ends it.

- **One guest, one tmux.** On a host (`fleet --local`: its one guest) or with `fleet attach <guest>`, the guest's tmux
  is attached straight from your terminal. Run it from a terminal outside tmux: inside one, the guest's nests in it
  (fleet says so).
- **Several guests** (the laptop: nixos's `agentvm-repos`, thinkcentre's `agentvm-thinkrepos`): a tmux session
  `fleet` with a window per guest, each attaching its guest. Two guests are two tmux servers on two machines, so
  here the guest's tmux nests in fleet's: `C-a` is fleet's, `C-b` the guest's.

The hosts are in `~/.config/fleet/hosts` (one ssh destination per line, from this package).

The guest's tmux has its own config, `tmux/dot-config/tmux/guest.conf`: the gruvbox look on tmux's own keys (prefix
`C-b`, and agent-methodology's `C-b u` switches a session's mode), windows from 0, the mouse on (the dashboard takes
clicks), the host's name on a dimmed purple on the left, workmux's branch glyph drawn dim. `C-b C-s` opens workmux's
dashboard in a popup over the window you are in; `C-b C-t` turns its sidebar, a column in every window with each
agent's status, on and off (agent-methodology turns it on when it starts the tmux server). The tabs carry workmux's
status icon, drawn as a glyph of the font: a robot (working), a speech bubble (waiting), a check (done). It, the
branch glyph and the dashboard's icons are Nerd Font's (agent-methodology's workmux config, `nerdfont: true`), so the
terminal you look through needs a Nerd Font, alacritty's (*Install*); the dashboard's own status icons are emoji, so
it needs an emoji font too. A host, with no desktop, needs neither. nixed links it as each guest's
`~/.config/tmux/tmux.conf` (nixed#45), so a guest's tmux server starts with it. A server already running reads it, and
its open windows and the agents session take the new tab formats, with:

```shell
tmux source-file ~/.config/tmux/tmux.conf
for w in $(tmux list-windows -t =agents -F '#{window_id}'); do
  tmux set -wu -t "$w" window-status-format; tmux set -wu -t "$w" window-status-current-format
done
tmux set -u -t agents status-left   # the UNATTENDED block comes back at the next start, or C-b u
```

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

Then `fleet doctor`, which names the first thing missing: `tmux`, `jq` and `ssh` here, each host's ssh, the tailnet
route to each guest, and each guest's ssh with tmux there (a guest ssh that fails shows ssh's own reason). Guest ssh always adds `StrictHostKeyChecking=accept-new`; `AGENTVM_KEY=<file>` makes it add `-i <file>`
too. On a host, `fleet --local` uses that host's `~/.agentvm/keys/id_ed25519` by itself: nothing to set up there.

| | |
|---|---|
| `fleet` | the only guest attached from this terminal; with several, start the session if needed, then attach (or switch to it from inside tmux) |
| `fleet attach <guest>` | that guest, attached from this terminal |
| a guest's window | named after the guest: its `agents` tmux session, attached over ssh, on `dashboard`. `C-b` is the guest's tmux there: its bar lists the agents' windows (with workmux's status icons, and `UNATTENDED` on an unattended one), `C-b w` picks one, `C-b d` comes back to a line that attaches again at Enter or in 15 s (also after a dropped link). A host that was down at the start gets a window named after it, which attaches its guest once it answers. A window you closed comes back after `tmux kill-session -t fleet` and `fleet` |
| `fleet ls`, `fleet doctor`, `fleet help` | guests, the checks, the rest |

Your own panes show their command and directory on their border; the focused pane's border is blue. The theme is
gruvbox, written into `tmux.conf` (no theme plugin), and needs no special font; the guests' workmux icons do (above). After a laptop reboot resurrect
restores your sessions, and `fleet` rebuilds its own.

Tests: `sudo pacman -S bats shellcheck`, then `bats tests/` from the repo root (stub ssh, private tmux
server; nothing reaches a real host).

### System files: manjaro-playbook

Everything here is stowed into `$HOME`, without root. Files under `/etc` (the touchpad's X config, TLP and its
battery charge thresholds, which dwmblocks' `sb-bat` pairs with a plug icon on the charger) are provisioned by the
`manjaro-playbook` repo instead (`./run.sh --tags touchpad,tlp`), so each file has one owner. They used to be the
`xorg-conf` and `tlp` packages here; the playbook's copy replaces their old symlinks in `/etc`.

## Claude Code's status line

The `claude` package draws Claude Code's status line in powerline style, gruvbox like alacritty and tmux:

```
 dotfiles  ⎇ master ✓  ✱ Fable 5.2  ✦ high  ◱ 31% (1h 59m)  ◑ 12% (3d 11h)  ctx ██░░░░░░░░ 42k/150k
```

Directory, git branch and its state (`✓` clean, `●` changes), model, effort level, the 5-hour and weekly usage with the time to each reset, then the
context against the session's budget (green, yellow from 80%, red with `HAND OFF` from 100%). The first six are
[claude-powerline](https://github.com/Owloops/claude-powerline)'s, set in `~/.config/claude-powerline/config.json`
(which boxes, their order and colours); the last is drawn by `~/.config/agent-methodology/statusline-render`, which
runs claude-powerline and joins its own box onto the end.
Alacritty draws the arrow between boxes itself, so no special font is needed. On a terminal too narrow for the line,
claude-powerline wraps its boxes onto a second line, and ours follow the last.

agent-methodology's `statusline.sh` runs the renderer when it is there (agent-methodology's settings, merged into
`~/.claude/settings.json`, set the status line to `statusline.sh`). Without claude-powerline or its config, or when it
fails, the line is the plain one.

Set up, per machine where Claude Code runs. The laptop: the two lines in *Install* (the `claude` package, the pinned
claude-powerline). A nixed guest has no stow, so link the renderer from the guest's checkout of dotfiles (it finds
the config beside itself in the checkout):

```shell
mkdir -p ~/.config/agent-methodology
ln -sfn /workspace/dotfiles/claude/dot-config/agent-methodology/statusline-render ~/.config/agent-methodology/
npm install -g --prefix ~/.local @owloops/claude-powerline@1.32.8   # into ~/.local/bin; no dependencies
```

A change to the config or the renderer shows at the line's next refresh. To bump claude-powerline, try the new
version first (`bats tests/statusline.bats` uses a stub, so also run the renderer by hand): the join relies on how it
closes its line, and a line that closes another way gets our box after a gap.

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

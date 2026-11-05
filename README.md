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

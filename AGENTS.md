# dotfiles

The user's dotfiles for an Arch laptop (i3, polybar, alacritty, zsh, nvim, doom, …), for tmux the NixOS hosts too,
and for Claude Code's status line the guests as well, managed with GNU Stow. `README.md` is the people's manual
(installing each package, tmux, `fleet`, the status line): read the section your task touches.

## The code

- **`fleet`** (`tmux/dot-local/bin/fleet`, bash) builds a tmux session with a window per guest, each attaching that
  guest's `agents` tmux session over ssh, the guests read from each host's `/etc/agentvm/projects.json`. Its design, decisions D1–D15
  and clarifications: `docs/fleet-design.md`.
- **`claude/dot-config/agent-methodology/statusline-render`** (bash) draws Claude Code's status line:
  claude-powerline's boxes plus the context budget.

## Working here

- **Stow layout.** Each top-level directory is a stow package mirroring `$HOME` (files under `/etc` belong to
  `manjaro-playbook`, not here), with `--dotfiles`: a path segment `dot-foo` is linked as `.foo`. A new file goes
  under its package's mirrored path, never at the repo root; a new package is added to `README.md`'s install command.
- **`README.md` documents every user-facing change** (a key, a command, a setup step), in the same commit.
- **The tmux config is shared** with the NixOS hosts, which link `tmux.conf` to their checkout of this repo (nixed):
  a change in `tmux/` reaches them on their next pull. A plugin added or removed also needs nixed's plugin list
  changed, as a nixed PR.
- **The trunk is `master`,** not `main`: the hosts' checkouts track it. GitHub; the repo is public, with no CI.
- **Nothing is deployed by a merge.** The laptop and each host apply it by `git pull` in `~/repos/dotfiles`, plus
  `stow -R <package>` for a new file (a guest has no stow: it links the renderer from its checkout). A running fleet
  session keeps the `fleet` it started with: a change to it shows after `tmux kill-session -t fleet` and `fleet`. A
  PR's body says what the user runs on the laptop and the hosts: a pull, a `stow -R`, `prefix r`, `fleet` again, or
  nixed's switch for a plugin change.
- **Notes** go in `docs/knowledge/` (index: its `README.md`); deferred items in `BACKLOG.md`.

## Tests

A session in a guest can't reach the laptop or the hosts' tmux: `fleet` is tested by the bats suite, which stubs
ssh and ip (`tests/stub`) and answers from `tests/fixtures`. Nothing to install in a
nixed-microvm guest (on the laptop: `sudo pacman -S tmux jq fzf bash-bats shellcheck`). From the repo root, about
four minutes, light enough to run without `methodology heavy`:

```bash
bats tests/              # tests/fleet.bats, tests/statusline.bats
shellcheck tmux/dot-local/bin/fleet claude/dot-config/agent-methodology/statusline-render tests/stub/*   # clean: keep it so
```

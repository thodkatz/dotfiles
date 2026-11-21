# dotfiles

The user's dotfiles for an Arch laptop (i3, polybar, alacritty, zsh, nvim, doom, …), for tmux the NixOS hosts too,
and for Claude Code's status line the guests as well, managed with GNU Stow. `README.md` is the people's manual
(installing each package, tmux, `fleet`, the status line): read the section your task touches.

## The code

- **`fleet`** (`tmux/dot-local/bin/fleet`, bash) builds a tmux session with Agent Deck's TUI (every host's microVM
  guests its remotes) and an overview of every guest's open inbox items and status rows, reading each host's
  `/etc/agentvm/projects.json` and each guest's supervisor `status.sh --json` over ssh. Its design, decisions D1–D15
  and clarifications: `docs/fleet-design.md`.
- **`agent-deck/dot-local/bin/agent-deck-config`** (bash and awk), which `fleet` runs to build deck's `config.toml`
  from the shared `settings.toml` and the machine's `remotes.toml`.
- **`claude/dot-config/agent-methodology/statusline-render`** (bash) draws Claude Code's status line:
  claude-powerline's boxes plus the context budget and the inbox count.

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
  `stow -R <package>` for a new file (a guest has no stow: it links the renderer from its checkout). The overview's
  loop runs the `fleet` on disk each round, so a pull reaches a running session. A PR's body says what the user runs
  on the laptop and the hosts: a pull, a `stow -R`, `prefix r`, `fleet` again, or nixed's switch for a plugin change.
- **Notes** go in `docs/knowledge/` (index: its `README.md`); deferred items in `BACKLOG.md`.

## Tests

A session in a guest can't reach the laptop or the hosts' tmux: `fleet` is tested by the bats suite, which stubs
ssh, systemctl, ip and agent-deck (`tests/stub`) and answers from `tests/fixtures`. Nothing to install in a
nixed-microvm guest (on the laptop: `sudo pacman -S tmux jq fzf bash-bats shellcheck`). From the repo root, about
four minutes, light enough to run without `methodology heavy`:

```bash
bats tests/              # tests/fleet.bats, tests/statusline.bats
shellcheck tmux/dot-local/bin/fleet agent-deck/dot-local/bin/* claude/dot-config/agent-methodology/statusline-render tests/stub/*   # clean: keep it so
```

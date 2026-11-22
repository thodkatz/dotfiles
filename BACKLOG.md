# Backlog

Deferred items. One item each, about three lines at most: the item, where it came from (PR, review thread, spec),
and why it waits. The PR that fixes an item deletes its line.

## Next

Due soon: what someone said to do next, and what waits on the user. Keep it short.

<!-- - <item> — from <investigation / review / handoff>; <waits on the user: what> | <due: why soon>. -->
- fleet's window per guest (layout E), the check of agent-methodology's step 5 slice 6: on the laptop and on nixos,
  the branch, the laptop's one-time link cleanup (`README.md`, *Update and run*), then `fleet doctor` and `fleet`
  (`fleet --local` on nixos): each guest's window attaches its `agents` session — from PR #16; waits on the user.
- Claude Code's status line after PR #14, now that agent-methodology#177 (the hook that runs the renderer) has
  merged. A session: check `claude/dot-config/agent-methodology/statusline-render` against the hook as merged
  (`AGENT_STATUSLINE_RENDER`, the path `~/.config/agent-methodology/statusline-render`, `AGENT_SL_PLAIN`, `AGENT_SL_CTX`,
  `AGENT_SL_BUDGET`, where its stderr goes) and fix what differs, as a direct commit. The user, per
  machine: on the laptop `git pull`, `mkdir -p ~/.config/agent-methodology`, `stow -t "$HOME"
  --dotfiles -R claude` and the pinned `npm install` (`README.md`, *Install*); in a guest the three lines of `README.md`,
  *Claude Code's status line*; then look at the line: only they can judge it. If its last line runs past the terminal's
  edge (our boxes take up to 47 columns, claude-powerline keeps 45 free), set `display.widthReserve` in the config —
  from PR #14 and its review (finding 9); waits on the user.
- A gruvbox theme for Claude Code itself, the other half of what the user asked for with the status line (2026-11-15):
  `claude/dot-claude/themes/gruvbox.json` (`base: dark` plus `overrides`; the token names are in
  code.claude.com/docs/en/terminal-config.md, *Create a custom theme* and *Color token reference*), picked with `/theme`;
  their theme is plain `dark` now. Its own small change in the `claude` package — from PR #14's handoff; due: asked for,
  not built.
- The status line on the hosts and in every guest without hand setup, a change in nixed (the user asked how,
  2026-11-15): `modules/home.nix` links the renderer with `linkDotfile` as it does `fleet` (thinkcentre and nixos, one
  switch each) and installs the pinned claude-powerline; `microvms/guest/base.nix` does the same for the guests, where a
  guest whose `/workspace` is one project has no `/workspace/dotfiles` to link from, so nixed has to carry the renderer
  there. To check first: that the renderer finds its config through home-manager's link, and that Claude Code on a host
  runs `statusline.sh` outside a methodology repo — from PR #14's session; after #14 and agent-methodology#177.

## Unscheduled

<!-- - <item> — from <PR #n / review thread / spec Inputs for>, waits because <reason>. -->
- Spinner verbs for Claude Code (`spinnerVerbs` in the settings), offered to the user with the status line and not asked
  for — from PR #14's handoff; waits on the user: whether they want them.
- Two gotchas in `docs/knowledge/claude-code-appearance.md` belong in agent-methodology's `tooling-gotchas.md`, being
  about Claude Code and bash in any repo: a `! <command>` prints escape codes as text (show colours in a
  `tmux display-popup -E`), and `$'\ue0b0'` follows the locale while the Write tool turns `\ue0b0` into the glyph (write
  the bytes). Carry them as a change there, then cut them from the note — from PR #14's review (finding 20).

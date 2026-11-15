# Handoff: the powerline status line (change/claude-powerline-statusline, #14), at the context budget

Written 2026-11-15, mid-unit: the code is pushed, the review round has not started.

## What the user asked for and decided (in the session, 2026-11-15)

To restyle Claude Code: the status line and the colours. They chose: the powerline look, by wrapping
claude-powerline and adding our own boxes for what it lacks; gruvbox; boxes for the directory, git branch and effort
level too. They saw the demo in a tmux popup and said it looks nice.

## Where it stands

- **dotfiles #14** (this branch, draft, plan in its body): commit `a9e79ca` adds the `claude` package
  (`claude/dot-config/agent-methodology/statusline-render`, `claude/dot-config/claude-powerline/config.json`),
  `tests/statusline.bats` with `tests/stub/claude-powerline`, and the `README.md` and `AGENTS.md` text. A second
  commit adds this handoff and the note `docs/knowledge/claude-code-appearance.md`.
  `bats tests/statusline.bats`: 9 of 9. `shellcheck` (the line in `AGENTS.md`, *Setup*): clean. The renderer was run by
  hand against the real claude-powerline 1.32.8 in its three states. The whole `bats tests/` was started and its
  result not read: run it again.
- **agent-methodology #177** (`change/statusline-render-hook`): the hook that makes `statusline.sh` run a renderer.
  An unattended session was started for it with `methodology next --new` (the supervisor's, not ours to watch). The
  contract it was given, which the renderer is written against: the executable at `$AGENT_STATUSLINE_RENDER`, else
  `~/.config/agent-methodology/statusline-render`; Claude Code's JSON on stdin; `AGENT_SL_PLAIN`, `AGENT_SL_CTX`,
  `AGENT_SL_BUDGET`, `AGENT_SL_INBOX` in the environment; a failure, empty output or a hang prints the plain line.

## Next, in order

1. `bats tests/`, then give #14 its title, mark it ready and run the local review round (correctness; methodology),
   post the findings, fix and reply (`development-workflow.md`, *Review and merge*).
2. Before the merge, look once at agent-methodology #177 (`gh pr view 177 -R thodkatz/agent-methodology`): #14
   depends on its contract, so it merges after #177 has. If #177 changed a name or the path, change the renderer, its
   tests and `README.md` to match first. If #177 is still open, end with `methodology next --end --blocked` as the
   guides say for a unit that waits, naming it; don't poll it.
3. After the merge and cleanup, set this guest up as `README.md`, *Claude Code's status line*, says (the `ln -sfn`
   and the pinned `npm install -g --prefix ~/.local`; the user agreed to the npm install), and tell the user what
   they run on the laptop and that `methodology update` brings the hook. The line can only be judged by the user
   looking at it: ask them to.
4. Still owed to the user, each its own small change in the `claude` package:
   - a gruvbox theme for Claude Code itself: `claude/dot-claude/themes/gruvbox.json` (`base: dark` plus
     `overrides`; the token names are in code.claude.com/docs/en/terminal-config.md, *Create a custom theme* and
     *Color token reference*), picked with `/theme`. The user's theme is plain `dark` now.
   - optional: spinner verbs (`spinnerVerbs`), offered, not asked for.

## Notes

`docs/knowledge/claude-code-appearance.md`: why not tweakcc, why a `statusLine` setting does nothing here, how to
show the user colours (a tmux popup), the arrow as bytes.

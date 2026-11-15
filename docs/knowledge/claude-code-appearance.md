# Claude Code's appearance: what can be changed here, and how to show the user colours

Found 2026-11-15 (Claude Code 2.1.322, a nixed-microvm guest), while building the `claude` package (#14).

- **The status line is pinned by the managed settings** (`/etc/claude-code/managed-settings.json` runs
  agent-methodology's `statusline.sh`): a `statusLine` in `~/.claude/settings.json` or a repo's settings is never
  run, so ccstatusline, claude-powerline and the like can't be set the way their READMEs say. The way in is the
  renderer `statusline.sh` runs (agent-methodology#177): `claude/dot-config/agent-methodology/statusline-render`.
- **tweakcc doesn't fit a guest**: it patches Claude Code's own files, and `claude` is in `/nix/store`, a read-only
  `erofs` mount (`findmnt -T /nix/store`). Themes and spinner verbs, its main draw, are built in now: a theme is a
  JSON file, `~/.claude/themes/<slug>.json` (`base` plus `overrides`), picked with `/theme`; `spinnerVerbs` is a
  setting. Claude Code paints no background of its own beyond user-message, bash and memory rows and diffs: the
  rest is the terminal's (alacritty's `#282828`).
- **A `! <command>` in the prompt prints escape codes as text**, so the user can't judge colours from it. Show them
  in a tmux popup, which they run themselves (it opens over what they type):
  `! tmux display-popup -w 110 -h 10 -E '<script>; read -r'`. The popup's grey background is tmux 3.8's
  `popup-style` (`bg=themedarkgrey`), not the script's.
- **`$''` follows the locale, and the Write tool turns `` in a file's text into the glyph itself**:
  write the powerline arrow as bytes, `$'\xee\x82\xb0'`.
- **claude-powerline closes its line** with a reset, an arrow in its last box's colour, a reset
  (`\e[0m\e[38;2;R;G;Bm<U+E0B0>\e[0m`): the renderer strips that to join its own boxes. Check it again on a
  version bump (1.32.8 here). It has no segment that runs a command; `env` shows one variable, one such box a line.

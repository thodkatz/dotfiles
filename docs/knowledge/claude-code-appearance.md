# Claude Code's appearance: what can be changed here, and how to show the user colours

Found 2026-11-15 (Claude Code 2.1.322, a nixed-microvm guest), while building the `claude` package (#14).

- **The status line is pinned by the managed settings** (`tooling-gotchas.md`, *A `statusLine` in
  `.claude/settings.local.json` does nothing under the managed settings*), so ccstatusline, claude-powerline and the
  like can't be set the way their READMEs say. The way in is the renderer `statusline.sh` runs
  (agent-methodology#177): `claude/dot-config/agent-methodology/statusline-render`.
- **tweakcc doesn't fit a guest**: it patches Claude Code's own files, and `claude` is in `/nix/store`, a read-only
  `erofs` mount (`findmnt -T /nix/store`). Themes and spinner verbs, its main draw, are built in now: a theme is a
  JSON file, `~/.claude/themes/<slug>.json` (`base` plus `overrides`), picked with `/theme`; `spinnerVerbs` is a
  setting. Claude Code paints no background of its own beyond user-message, bash and memory rows and diffs: the
  rest is the terminal's (alacritty's `#282828`).
- **Why not ccstatusline** (2.2.34, tried 2026-11-15 for #14's review): it has all six boxes, hex colours and a
  Custom Command widget that inherits the environment and hides on empty output, but a widget's background is fixed
  (the budget box's green, yellow and red would be three widgets and scripts), it takes 0.75 to 1 s a run with the
  commands against the renderer's 0.3 to 0.4, and once the transcript's last reply is over 3 minutes old it reads
  `.credentials.json` and calls `api.anthropic.com/api/oauth/usage`, with no setting to stop it.
- **A `! <command>` in the prompt prints escape codes as text**, so the user can't judge colours from it. Show them
  in a tmux popup, which they run themselves (it opens over what they type):
  `! tmux display-popup -w 110 -h 10 -E '<script>; read -r'`. The popup's grey background is tmux 3.8's
  `popup-style` (`bg=themedarkgrey`), not the script's.
- **`$'\ue0b0'` follows the locale, and the Write tool turns `\ue0b0` in a file's text into the glyph itself**:
  write the powerline arrow as bytes, `$'\xee\x82\xb0'`.
- **claude-powerline has no segment that runs a command** (`env` shows one variable, one such box a line), so our
  boxes are joined onto its line by the renderer, which relies on how 1.32.8 closes it (the renderer's comment;
  `README.md`, *Claude Code's status line*). It recolours the 5-hour and weekly boxes with the theme's
  `contextWarning` and `contextCritical` from 50% and 80%: a custom theme without them gets its dark theme's there.

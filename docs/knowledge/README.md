# Project knowledge index

<!-- One line per entry: [topic.md](topic.md) — the symptom or question, and the answer in brief. See
     AGENTS.md, "Project knowledge", for what belongs here. -->
- [agent-deck-in-tmux.md](agent-deck-in-tmux.md) — deck in a tmux pane: "You are inside tmux" exit 1, then "restart refused: this session still owns processes" on attach; run `env -u TMUX -u TMUX_PANE AGENT_DECK_ALLOW_OUTER_TMUX=1 agent-deck`; one TUI per profile; the first-start hooks prompt

# Project knowledge index

<!-- One line per entry: [topic.md](topic.md) — the symptom or question, and the answer in brief. See
     AGENTS.md, "Project knowledge", for what belongs here. -->
- [agent-deck-in-tmux.md](agent-deck-in-tmux.md) — deck in a tmux pane: "You are inside tmux" exit 1, then "restart refused: this session still owns processes" on attach; run `env -u TMUX -u TMUX_PANE AGENT_DECK_ALLOW_OUTER_TMUX=1 agent-deck`; one TUI per profile; the first-start hooks prompt; one config.toml, no includes (agent-deck-config merges); `[hotkeys] switch_session` does nothing on a remote's session (only Ctrl+Q is caught)
- [deck-remote-auth-failed.md](deck-remote-auth-failed.md) — deck remote `unreachable` `auth failed` on a host (`Connection closed by 192.168.122.1 … [preauth]` in the guest's sshd log) while the overview works: agent-deck has no `-i`; add the `Match host <guest subnet> localuser theo` IdentityFile block, `fleet doctor`'s `deck ssh`

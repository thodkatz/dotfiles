# `session remove` refuses a dead session as `idle`

**Symptom.** After a guest reboots, every deck session from before it shows as `error` in `agent-deck list` and the TUI,
but removing one fails:

```
Error: session 'bright-star' is in state 'idle'; only stopped/error sessions may be removed without --force
```

(or `in state 'starting'` for a Claude session).

**Why.** `list` computes the status live (`"status_source": "live"`): its tmux session is gone, so it shows `error`.
`session remove` checks the stored `status` column in `~/.local/share/agent-deck/profiles/default/state.db`, the last
value written before the reboot, and nothing updates it afterwards. Seen on agent-deck 1.16.38. Tracked in #13 (label
`agent-deck`).

**Fix.** Check that the tmux session really is gone, then force the removal:

```bash
agent-deck list --json | jq -r '.[] | select(.status=="error") | [.id,.title,.tmux_session] | @tsv'
tmux has-session -t "=<tmux_session>" || agent-deck session remove --force <id>
```

A dead Claude session still points to a conversation deck can resume (`claude_session_id`): `session start <id>`
brings it back, `remove` drops that link (the transcript stays under `~/.claude/projects/`).

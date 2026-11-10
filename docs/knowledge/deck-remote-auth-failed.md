# Deck on a host: a remote `unreachable` / `auth failed` while the overview works

Symptom (2026-11-10, nixos, `fleet --local`): the deck window shows the `repos` remote (`agentvm@192.168.122.51`)
unreachable, `auth failed`; the overview and `fleet doctor`'s guest ssh were fine. The guest's `journalctl -u sshd`
shows `Connection closed by 192.168.122.1 port … [preauth]` about every 6 s (the deck's refresh), beside fleet's
`Accepted publickey … ED25519 SHA256:NKYF…` (the agentvm key).

Cause: a guest trusts only its host's `~/.agentvm/keys/id_ed25519`. fleet passes it with `-i`; agent-deck runs a plain
`ssh -o ControlPersist=600 -o ConnectTimeout=10 -o BatchMode=yes <user@host>` and its `[remotes.*]` has no key field,
so only `~/.ssh/config` can name it. nixos's had a `thinkrepos` alias and nothing for `192.168.122.*`, so ssh offered
`theo@nixos`'s own key.

Fix: the `Match host 192.168.122.* localuser theo` block in `README.md`, *Setup on a host*. `localuser theo`
because a guest reads the host's `~/.ssh/config` too (`/mnt/host-ssh/config`), where an `IdentityFile` it lacks
hides its own default key. `fleet doctor`'s `deck ssh` line checks the deck's way in.

From a guest you can read a host's ssh config at `/mnt/host-ssh/config` and its sshd's view of the host in the
guest's own `journalctl -u sshd`: no need to reach the host to diagnose this.

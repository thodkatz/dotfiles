#!/usr/bin/env bats
# fleet against a private tmux server and stub ssh/systemctl/ip/agent-deck (tests/stub),
# answering from a copy of tests/fixtures. Run from the repo root: bats tests/

setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  FLEET=$ROOT/tmux/dot-local/bin/fleet
  export FLEET_FIXTURES=$BATS_TEST_TMPDIR/fx
  cp -r "$ROOT/tests/fixtures" "$FLEET_FIXTURES"
  export PATH="$ROOT/tests/stub:$PATH"
  export FLEET_HOSTS_FILE=$FLEET_FIXTURES/hosts
  export FLEET_STATE=$BATS_TEST_TMPDIR/state
  export FLEET_TMUX_SOCKET=fleet-test-$$-$BATS_TEST_NUMBER
  export FLEET_TMUX_CONF=/dev/null
  export FLEET_DECK_CMD=agent-deck-not-in-tests FLEET_DECK_CONFIG=$FLEET_FIXTURES/deck-config.toml
  export FLEET_DECK_INSTALL=$FLEET_FIXTURES/agent-deck-install
  export FLEET_NO_LOOP=1 FLEET_OVERVIEW_INTERVAL=3600
  export HOME=$BATS_TEST_TMPDIR/home   # no real ~/.agentvm key leaks in
  mkdir -p "$HOME"
  unset AGENTVM_KEY
  unset TMUX TMUX_PANE
}

teardown() {
  rm -f "$FLEET_FIXTURES/deck-attach"   # ends a stub TUI's attach
  tmux -L "$FLEET_TMUX_SOCKET" kill-server 2>/dev/null || true
}

t() { tmux -L "$FLEET_TMUX_SOCKET" "$@"; }

# The hint without its tmux styles.
plain() { sed 's/#\[[^]]*\]//g'; }

# Poll up to 5 s until the stub ssh has logged a line matching $1.
wait_log() {
  local i
  for i in $(seq 50); do
    grep -q -- "$1" "$FLEET_FIXTURES/ssh.log" 2>/dev/null && return 0
    sleep 0.1
  done
  return 1
}

@test "ls: one line per guest with its host (D4)" {
  run "$FLEET" ls
  [ "$status" -eq 0 ]
  [ "$output" = $'nixos agentvm-repos 192.168.122.51\nthinkcentre agentvm-thinkrepos 192.168.123.51' ]
}

@test "ls --local: only this host's projects.json (D4)" {
  AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos run "$FLEET" --local ls
  [ "$status" -eq 0 ]
  [ "$output" = "nixos agentvm-repos 192.168.122.51" ]
  ! grep -q 'cat /etc/agentvm' "$FLEET_FIXTURES/ssh.log"
}

@test "ls: an unreachable host is one '- -' line, not a failure (D9)" {
  touch "$FLEET_FIXTURES/fail-thinkcentre"
  run "$FLEET" ls
  [ "$status" -eq 0 ]
  [ "$output" = $'nixos agentvm-repos 192.168.122.51\nthinkcentre - -' ]
}

@test "probe script runs the unit's status.sh with its AGENT_SUPERVISE_REPOS, json without the forge (D5)" {
  run bash -c "'$FLEET' _probe-script | bash -s -- json"
  [ "$status" -eq 0 ]
  [ "$output" = "repos=/workspace/a /workspace/b tmpdir=/var/tmp args=--json --no-forge" ]
  run bash -c "'$FLEET' _probe-script | bash -s -- table"
  [ "$output" = "repos=/workspace/a /workspace/b tmpdir=/var/tmp args=" ]
}

@test "probe script with no unit prints the no-supervisor marker (D5)" {
  touch "$FLEET_FIXTURES/unit-missing"
  run bash -c "'$FLEET' _probe-script | bash -s -- json"
  [ "$status" -eq 0 ]
  [ "$output" = "fleet:no-supervisor" ]
}

@test "probe script inbox-json: the inbox's items not closed, a line per key, then status.sh's JSON, then the hops" {
  export XDG_STATE_HOME=$BATS_TEST_TMPDIR/xdg
  mkdir -p "$XDG_STATE_HOME/agent-sessions"
  cp -r "$FLEET_FIXTURES/inbox-192.168.123.51" "$XDG_STATE_HOME/agent-sessions/inbox"
  echo 3 > "$XDG_STATE_HOME/agent-sessions/inbox/.next"
  run bash -c "'$FLEET' _probe-script | bash -s -- inbox-json"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = fleet:inbox ]
  [ "${lines[1]}" = $'21\topened=1794100000' ]
  [ "$(grep -c $'^21\t' <<<"$output")" -eq 12 ]
  ! grep -q $'^20\t' <<<"$output"
  [ "${lines[13]}" = fleet:status ]
  [ "${lines[14]}" = "repos=/workspace/a /workspace/b tmpdir=/var/tmp args=--json --no-forge" ]
  [ "${lines[15]}" = fleet:hops ]
  [ "${#lines[@]}" -eq 16 ]
  touch "$FLEET_FIXTURES/unit-missing"; rm -r "$XDG_STATE_HOME/agent-sessions/inbox"
  run bash -c "'$FLEET' _probe-script | bash -s -- inbox-json"
  [ "$output" = $'fleet:inbox\nfleet:status\nfleet:no-supervisor' ]
}

@test "status: a guest without the unit shows 'no supervisor', exit 0 (D5)" {
  touch "$FLEET_FIXTURES/nosup-192.168.123.51"
  run "$FLEET" status agentvm-thinkrepos
  [ "$status" -eq 0 ]
  [ "$output" = "no supervisor" ]
  run "$FLEET" status agentvm-repos
  [ "$output" = "table of 192.168.122.51" ]
}

@test "status: a hung status.sh times out as unreachable" {
  touch "$FLEET_FIXTURES/hang-192.168.122.51"
  FLEET_PROBE_TIMEOUT=1 run "$FLEET" status agentvm-repos
  [ "$status" -eq 0 ]
  [ "$output" = unreachable ]
}

@test "status: an unknown guest dies with 'no guest'" {
  run "$FLEET" status nope
  [ "$status" -eq 1 ]
  [ "$output" = "fleet: no guest nope" ]
}

# --- the session (layout C, agent-methodology D20) -------------------------

@test "fleet start makes the deck and overview windows only" {
  export FLEET_DECK_CMD=agent-deck
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet -F '#W|#{window_panes}|#{@fleet-deck}'
  [ "$output" = $'deck|1|1\noverview|2|' ]
  [ "$(t show -gv @fleet-booted-fleet)" = c ]
  [ "$(t show -t =fleet: -v @fleet-mode)" = remote ]
  # no agent-deck: the overview alone, and fleet says why
  t kill-server
  FLEET_DECK_CMD=agent-deck-not-in-tests run "$FLEET" up
  [ "$status" -eq 0 ]
  [[ "$output" == *"fleet: agent-deck-not-in-tests is not on PATH, so no deck window: install it with $FLEET_DECK_INSTALL, then run fleet again"* ]]
  run t list-windows -t =fleet -F '#W'
  [ "$output" = overview ]
}

@test "up: a session built without deck gets the deck window once deck is installed, and keeps it after" {
  "$FLEET" up
  export FLEET_DECK_CMD=agent-deck
  t new-window -d -t =fleet: -n mine 'sleep 600'
  "$FLEET" up
  run t list-windows -t =fleet -F '#W|#{@fleet-deck}'
  [ "$output" = $'deck|1\noverview|' ]
  t new-window -d -t =fleet: -n mine 'sleep 600'
  "$FLEET" up
  t list-windows -t =fleet -F '#W' | grep -qx mine
}

@test "up: window overview runs its loop, the first guest's btop to its right" {
  "$FLEET" up
  run t list-panes -t =fleet:overview -F '#{@fleet-overview}|#{@fleet-res-guest}|#{pane_left}|#{pane_width}'
  [ "${lines[0]}" = '1||0|127' ]
  [ "${lines[1]}" = '|agentvm-repos|128|72' ]
  [[ "$(t list-panes -t =fleet:overview -F '#{pane_start_command}' | head -1)" == *_overview*fleet* ]]
  wait_log 'agentvm@192.168.122.51 .*btop'
  grep -q 'ssh -t .*agentvm@192.168.122.51 .*btop' "$FLEET_FIXTURES/ssh.log"
}

@test "deck: its TUI starts outside fleet's tmux, allowed to run inside one" {
  export FLEET_DECK_CMD=$BATS_TEST_TMPDIR/deckbin/agent-deck
  mkdir -p "${FLEET_DECK_CMD%/*}"
  printf '#!/bin/sh\nenv > "$0.env"; exec sleep 600\n' > "$FLEET_DECK_CMD"; chmod +x "$FLEET_DECK_CMD"
  "$FLEET" up
  # deck refuses to start inside tmux without the allowance, and with TMUX set looks for its sessions on fleet's server
  for _ in $(seq 25); do [ -s "$FLEET_DECK_CMD.env" ] && break; sleep 0.2; done
  grep -qx AGENT_DECK_ALLOW_OUTER_TMUX=1 "$FLEET_DECK_CMD.env"
  ! grep -q '^TMUX=' "$FLEET_DECK_CMD.env"
  [[ "$(t display -p -t =fleet:deck '#{pane_start_command}')" == *deckbin/agent-deck* ]]
}

@test "up: keeps its own session; rebuilds one an older fleet built or resurrect restored, and stops an old hint loop (D13)" {
  "$FLEET" up
  t new-window -d -t =fleet: -n mine 'sleep 600'
  "$FLEET" up
  t list-windows -t =fleet -F '#W' | grep -qx mine
  # an older fleet's session (marker 1) and its hint loop
  t set -g @fleet-booted-fleet 1
  sleep 600 & old=$!
  echo "$old 5" > "$FLEET_STATE/fleet/hintloop.pid"
  "$FLEET" up
  ! t list-windows -t =fleet -F '#W' | grep -qx mine
  ! kill -0 "$old" 2>/dev/null
  [ ! -e "$FLEET_STATE/fleet/hintloop.pid" ]
  [ "$(t show -gv @fleet-booted-fleet)" = c ]
  # resurrect's (no marker)
  t new-window -d -t =fleet: -n mine 'sleep 600'
  t set -gu @fleet-booted-fleet
  "$FLEET" up
  run t list-windows -t =fleet -F '#W'
  [ "$output" = overview ]
}

@test "up --local: session fleet-<host>, this host's guests only (D4, D6)" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  run "$FLEET" --local up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet-nixos -F '#W'
  [ "$output" = overview ]
  [ "$(t show -t =fleet-nixos: -v @fleet-mode)" = local ]
  ! grep -q 'theo@' "$FLEET_FIXTURES/ssh.log"
}

@test "up: one unreachable guest never fails it (D9)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run "$FLEET" status agentvm-thinkrepos
  [ "$output" = unreachable ]
}

@test "fleet sync is unknown" {
  run "$FLEET" sync
  [ "$status" -eq 2 ]
  [[ "$output" == 'usage: fleet'* ]]
}

# --- window overview ---------------------------------------------------------

OV_REPOS=$'agentvm-repos · nixos\n  (no open items)\n  status: 4 rows
    main  attended  working
    main  unattended  idle
    nixed  unattended  -  gated #4
    impl/x  unattended  asking  stall'
OV_THINK_ITEM=$'agentvm-thinkrepos · thinkcentre\n  ✉ #21 death impl/x-1\n      cd /workspace/agent-methodology/.claude/worktrees/impl-x-1 && /home/agentvm/.local/share/agent-methodology/gen/b80f91c6/shared/methodology next --resume /workspace/agent-methodology/.claude/worktrees/impl-x-1 --here'
OV_THINK_ROWS=$'  status: 1 row\n    agent-methodology  attended  working'

@test "overview lists both guests' open items and status rows" {
  run "$FLEET" _overview fleet --once
  [ "$status" -eq 0 ]
  [ "$output" = "$OV_REPOS"$'\n\n'"$OV_THINK_ITEM"$'\n'"$OV_THINK_ROWS" ]
  # one ssh per guest, over the shared connection
  [ "$(grep -c 'agentvm@192.168.123.51 bash -s -- inbox-json' "$FLEET_FIXTURES/ssh.log")" -eq 1 ]
  grep 'agentvm@192.168.123.51 bash -s -- inbox-json' "$FLEET_FIXTURES/ssh.log" | grep -q ControlMaster=auto
  # the round also writes the hint
  [ "$(plain < "$FLEET_STATE/fleet/hint")" = "nixos ●3 ◆1  thinkcentre ●1 ✉1" ]
}

@test "overview: a row missing fields shows ? and -" {
  echo '[{"repo": "/workspace/agent-methodology", "state": "running"}]' > "$FLEET_FIXTURES/guest-192.168.123.51.json"
  run "$FLEET" _overview fleet --once
  [ "$status" -eq 0 ]
  [[ "$output" == *$'  status: 1 row\n    ?  ?  -' ]]
}

@test "overview: an item with no continue shows what it needs" {
  sed -i '/^continue=/d' "$FLEET_FIXTURES/inbox-192.168.123.51/21"
  run "$FLEET" _overview fleet --once
  [[ "$output" == *$'✉ #21 death impl/x-1\n      needs: The session died (state running, exit none).\n'* ]]
}

@test "overview says no open items" {
  rm -r "$FLEET_FIXTURES/inbox-192.168.123.51"
  run "$FLEET" _overview fleet --once
  [ "$status" -eq 0 ]
  [ "$output" = "$OV_REPOS"$'\n\nagentvm-thinkrepos · thinkcentre\n  (no open items)\n'"$OV_THINK_ROWS" ]
}

@test "overview marks an unreachable guest, an unreachable host and a guest with no supervisor" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" _overview fleet --once
  [ "$status" -eq 0 ]
  [ "$output" = "$OV_REPOS"$'\n\nagentvm-thinkrepos · thinkcentre\n  ✗ unreachable' ]
  rm "$FLEET_FIXTURES/fail-192.168.123.51"; touch "$FLEET_FIXTURES/fail-thinkcentre" "$FLEET_FIXTURES/nosup-192.168.122.51"
  run "$FLEET" _overview fleet --once
  [ "$output" = $'agentvm-repos · nixos\n  (no open items)\n  status: no supervisor\n\nthinkcentre\n  ✗ unreachable' ]
}

# --- the hint ----------------------------------------------------------------

@test "hint counts live, asking, open from status --json's activity" {
  jq '[.[0], .[0] + {deck_id: "a2", activity: "asking"}, .[0] + {deck_id: "a3", activity: "idle"},
    .[0] + {deck_id: "a4", activity: "quota"}, .[0] + {deck_id: "a5", activity: ""}, (.[0] + {deck_id: "a6"} | del(.activity))]' \
    "$FLEET_FIXTURES/guest-192.168.123.51.json" > "$FLEET_FIXTURES/x"
  mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.123.51.json"
  "$FLEET" up
  run "$FLEET" hint -t fleet
  [ "$(plain <<<"$output")" = "nixos ●3 ◆1  thinkcentre ●3 ◆1 ✉1" ]
  [[ "$output" == *"#[fg=#83a598]✉1#[default]"* ]]
}

@test "hint: counts per host, --refresh rediscovers (D10)" {
  "$FLEET" up
  jq '. + [.[0] + {deck_id: "d-nixed-3", activity: "asking"}]' "$FLEET_FIXTURES/guest-192.168.122.51.json" > "$FLEET_FIXTURES/x"
  mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.122.51.json"
  run "$FLEET" hint -t fleet --refresh
  [ "$status" -eq 0 ]
  [ "$(plain <<<"$output")" = "nixos ●4 ◆2  thinkcentre ●1 ✉1" ]
  run "$FLEET" hint -t fleet
  [ "$output" = "#[fg=#8ec07c]nixos#[default] #[fg=#b8bb26]●4#[default] #[fg=#d3869b]◆2#[default]  #[fg=#fe8019]thinkcentre#[default] #[fg=#b8bb26]●1#[default] #[fg=#83a598]✉1#[default]" ]
}

@test "hint: an unreachable host shows ✗; no cache prints nothing (D10)" {
  run "$FLEET" hint -t fleet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  "$FLEET" up
  run "$FLEET" hint -t fleet
  [ "$(plain <<<"$output")" = "nixos ●3 ◆1  thinkcentre ✗" ]
}

@test "hint from a session fleet did not make shows fleet's" {
  "$FLEET" up
  t new-session -d -s mine 'sleep 600'
  run "$FLEET" hint -t mine --refresh
  [ "$status" -eq 0 ]
  [ "$(plain <<<"$output")" = "nixos ●3 ◆1  thinkcentre ●1 ✉1" ]
}

@test "hint: a foreign session under --local falls back to fleet-<host>, not fleet (D6, D10)" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  "$FLEET" --local up
  t new-session -d -s mine 'sleep 600'
  run "$FLEET" hint -t mine
  [ "$status" -eq 0 ]
  [ "$(plain <<<"$output")" = "nixos ●3 ◆1" ]
}

@test "hint: nothing once the session is gone, though its cache remains (D10)" {
  "$FLEET" up
  t new-session -d -s mine 'sleep 600'
  [ -n "$("$FLEET" hint -t mine)" ]
  t kill-session -t =fleet
  [ -r "$FLEET_STATE/fleet/hint" ]
  run "$FLEET" hint -t mine
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- doctor and ssh ----------------------------------------------------------

@test "doctor: names the guest whose ssh fails, exits 1 (D14)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL  ssh agentvm@192.168.123.51 (agentvm-thinkrepos)'* ]]
  [[ "$output" == *'ok    ssh agentvm@192.168.122.51 (agentvm-repos): agent-deck'* ]]
}

@test "doctor: all good exits 0 (D14)" {
  export FLEET_DECK_CMD=agent-deck
  run "$FLEET" doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *FAIL* ]]
  [[ "$output" == *"ok    agent-deck v1.0.0"* ]]
  [[ "$output" == *"ok    agent-deck config $FLEET_DECK_CONFIG"* ]]
}

@test "doctor: this machine's agent-deck, missing, off the pin or without its config, fails and names the fix" {
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  agent-deck-not-in-tests not on PATH, so no deck window: install it with $FLEET_DECK_INSTALL"* ]]
  export FLEET_DECK_CMD=agent-deck
  echo 0.9.0 > "$FLEET_FIXTURES/deck-version"
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  agent-deck: Agent Deck v0.9.0, pinned v1.0.0: run $FLEET_DECK_INSTALL"* ]]
  echo 1.0.0 > "$FLEET_FIXTURES/deck-version"
  rm "$FLEET_FIXTURES/deck-config.toml"
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  no agent-deck config $FLEET_DECK_CONFIG: deck has no guests as remotes"* ]]
  # FLEET_DECK_CMD empty: no deck wanted, nothing to check
  FLEET_DECK_CMD='' run "$FLEET" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok    agent-deck: off (FLEET_DECK_CMD empty)"* ]]
}

@test "doctor: the pin is agent-deck-install's, in the checkout fleet runs from" {
  unset FLEET_DECK_INSTALL
  export FLEET_DECK_CMD=agent-deck
  echo "$(sed -n 's/^version=//p' "$ROOT/agent-deck/dot-local/bin/agent-deck-install")" > "$FLEET_FIXTURES/deck-version"
  run "$FLEET" doctor
  [ "$status" -eq 0 ]
  echo 0.9.0 > "$FLEET_FIXTURES/deck-version"
  run "$FLEET" doctor
  [[ "$output" == *"pinned v"*"run $ROOT/agent-deck/dot-local/bin/agent-deck-install"* ]]
}

@test "doctor: a failed guest ssh shows ssh's own reason (D14)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" doctor
  [[ "$output" == *$'(agentvm-thinkrepos): no ssh, or no agent-deck there\n      ssh: connect to host 192.168.123.51 port 22: Connection timed out'* ]]
}

@test "ssh: guests get accept-new, hosts don't; no -i by default" {
  "$FLEET" status agentvm-repos
  grep -q 'StrictHostKeyChecking=accept-new agentvm@192.168.122.51 bash -s -- table' "$FLEET_FIXTURES/ssh.log"
  ! grep -q 'accept-new theo@' "$FLEET_FIXTURES/ssh.log"
  ! grep -q -- ' -i ' "$FLEET_FIXTURES/ssh.log"
}

@test "ssh: probes and discovery share a connection; the btop pane doesn't" {
  "$FLEET" up
  wait_log 'agentvm@192.168.122.51 .*btop'
  grep -q "ControlPath=$FLEET_STATE/ssh/%C -o ControlPersist=10m -o BatchMode=yes .* agentvm@192.168.122.51 bash -s -- inbox-json" "$FLEET_FIXTURES/ssh.log"
  grep -q "ControlMaster=auto .* theo@nixos cat /etc/agentvm/projects.json" "$FLEET_FIXTURES/ssh.log"
  ! grep 'btop' "$FLEET_FIXTURES/ssh.log" | grep -q ControlMaster
  [ "$(stat -c %a "$FLEET_STATE/ssh")" = 700 ]
}

@test "ssh: no shared connection with FLEET_SSH_MUX=0, or a socket path past 108 bytes" {
  FLEET_SSH_MUX=0 "$FLEET" status agentvm-repos
  ! grep -q ControlMaster "$FLEET_FIXTURES/ssh.log"
  FLEET_STATE=$BATS_TEST_TMPDIR/$(printf 'x%.0s' $(seq 80)) "$FLEET" status agentvm-repos
  ! grep -q ControlMaster "$FLEET_FIXTURES/ssh.log"
}

@test "discovery: reads the hosts at once, in the hosts file's order" {
  "$FLEET" up
  touch "$FLEET_FIXTURES/slow-nixos" "$FLEET_FIXTURES/slow-thinkcentre"
  start=$(date +%s)
  "$FLEET" hint -t fleet --refresh >/dev/null
  [ $(( $(date +%s) - start )) -lt 4 ]
  [ "$(jq -r '(map(.host) | unique == ["nixos", "thinkcentre"]) and .[0].host == "nixos"' "$FLEET_STATE/fleet/fleet.json")" = true ]
}

@test "ssh: AGENTVM_KEY is the guests' identity, in the btop pane too" {
  export AGENTVM_KEY=/keys/agentvm
  "$FLEET" up
  wait_log 'agentvm@192.168.122.51 .*btop'
  grep -q 'accept-new -i /keys/agentvm agentvm@192.168.122.51 bash -s -- inbox-json' "$FLEET_FIXTURES/ssh.log"
  grep -q 'accept-new -i /keys/agentvm agentvm@192.168.122.51 .*btop' "$FLEET_FIXTURES/ssh.log"
  ! grep -q -- '-i /keys/agentvm theo@' "$FLEET_FIXTURES/ssh.log"
}

@test "ssh --local: the host's agentvm key when it exists, in the btop pane too" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  "$FLEET" --local status agentvm-repos
  ! grep -q -- ' -i ' "$FLEET_FIXTURES/ssh.log"
  mkdir -p "$HOME/.agentvm/keys" && touch "$HOME/.agentvm/keys/id_ed25519"
  "$FLEET" --local up
  wait_log 'agentvm@192.168.122.51 .*btop'
  grep -q -- "-i $HOME/.agentvm/keys/id_ed25519 agentvm@192.168.122.51 .*btop" "$FLEET_FIXTURES/ssh.log"
}

@test "tmux.conf: resurrect's post-save hook drops fleet's sessions from a save" {
  t -f "$ROOT/tmux/dot-config/tmux/tmux.conf" start-server \; show -gv @resurrect-hook-post-save-layout > "$BATS_TEST_TMPDIR/hook"
  save=$BATS_TEST_TMPDIR/tmux_resurrect_x.txt
  printf '%s\n' $'pane\tfleet\t1\t1\t:*\t1\tt\t:/\t1\tssh\t1\t0' $'pane\tfleet-nixos\t2\t0\t:-\t1\tt\t:/\t1\tssh\t1\t0' \
    $'pane\tmine\t1\t1\t:*\t1\tt\t:/\t1\tzsh\t1\t0' $'pane\tfleetwood\t1\t1\t:*\t1\tt\t:/\t1\tzsh\t1\t0' \
    $'window\tfleet\t1\t:overview\t1\t:*\ttiled\t:' $'window\tmine\t1\t:zsh\t1\t:*\tlay\t:' $'state\tfleet\tmine' > "$save"
  # As resurrect's execute_hook runs it: eval "$hook <quoted path>".
  eval "$(cat "$BATS_TEST_TMPDIR/hook") $(printf %q "$save")"
  run cut -f 1,2 "$save"
  [ "$output" = $'pane\tmine\npane\tfleetwood\nwindow\tmine\nstate\tfleet' ]
}

# --- hops: the deck TUI follows a viewed hop (D20, Clarification 5) -----------

# fleet with the stub deck, its TUI attached to thinkrepos' d-am-1; one round records the attach.
deck_up() {
  export FLEET_DECK_CMD=agent-deck
  echo "192.168.123.51 d-am-1" > "$FLEET_FIXTURES/deck-attach"
  "$FLEET" up
  wait_log 'agentvm@192.168.123.51 agent-deck session attach d-am-1'
  "$FLEET" _round fleet >/dev/null
}

# The attached session stops (its hand-off): deck's attach ends, the TUI is back on its list.
detach() {
  local i
  rm -f "$FLEET_FIXTURES/deck-attach"
  for i in $(seq 50); do pgrep -f 'agent-deck session attach d-am-1' >/dev/null || return 0; sleep 0.1; done
  return 1
}

# The hops thinkrepos' probe reports, "<old> <successor> <old's tmux session>" each.
hops() { printf '%s\t%s\t%s\n' "$@" > "$FLEET_FIXTURES/hops-192.168.123.51"; }

rounds() { "$FLEET" _round fleet >/dev/null && "$FLEET" _round fleet >/dev/null; }

@test "a viewed hop opens its successor in the TUI once" {
  deck_up
  [[ "$(cat "$FLEET_STATE/fleet/deck-attached")" == $'192.168.123.51\t'*'session attach d-am-1' ]]
  detach
  hops d-am-1 d-am-2 agentdeck_am_1
  rounds
  [ "$(cat "$FLEET_FIXTURES/deck.log")" = "agent-deck session focus --remote thinkrepos d-am-2 --attach" ]
}

@test "an unviewed hop moves nothing" {
  # the probe lists only a hop from an archived session marked am.viewed=1
  echo '[{"deck_id": "d-2", "prev": "d-1"}, {"deck_id": "d-4", "prev": "d-3"}, {"deck_id": "d-6", "prev": "d-5"},
    {"deck_id": "d-7", "prev": ""}]' > "$FLEET_FIXTURES/status-json"
  echo '[{"id": "d-1", "archived": true, "tmux_session": "agentdeck_a"}, {"id": "d-3", "archived": true, "tmux_session": "agentdeck_b"},
    {"id": "d-5", "archived": false, "tmux_session": "agentdeck_c"}]' > "$FLEET_FIXTURES/deck-list.json"
  printf '%s\n' d-1 d-5 > "$FLEET_FIXTURES/deck-viewed"
  run bash -c "'$FLEET' _probe-script | bash -s -- inbox-json"
  [ "$status" -eq 0 ]
  [ "${output#*fleet:hops$'\n'}" = $'d-1\td-2\tagentdeck_a' ]
  # so with no hop reported, the TUI stays
  deck_up
  detach
  rounds
  [ ! -e "$FLEET_FIXTURES/deck.log" ]
}

@test "a hop this TUI wasn't attached to moves nothing" {
  deck_up
  # attached to another session when its old one's hop arrives
  echo "192.168.123.51 d-am-5" > "$FLEET_FIXTURES/deck-attach"
  wait_log 'agentvm@192.168.123.51 agent-deck session attach d-am-5'
  hops d-am-1 d-am-2 agentdeck_am_1
  rounds
  # a hop of another session on its guest, and of the same id on another guest
  rm -f "$FLEET_FIXTURES/deck-attach"
  for i in $(seq 50); do pgrep -f 'agent-deck session attach d-am-5' >/dev/null || break; sleep 0.1; done
  hops d-other d-other-2 agentdeck_other
  printf 'd-am-5\td-am-6\tagentdeck_am_5\n' > "$FLEET_FIXTURES/hops-192.168.122.51"
  rounds
  [ ! -e "$FLEET_FIXTURES/deck.log" ]
}

@test "a hop reported while its attach is still open is followed once it ends" {
  deck_up
  hops d-am-1 d-am-2 agentdeck_am_1
  "$FLEET" _round fleet >/dev/null
  [ ! -e "$FLEET_FIXTURES/deck.log" ]
  detach
  rounds
  [ "$(cat "$FLEET_FIXTURES/deck.log")" = "agent-deck session focus --remote thinkrepos d-am-2 --attach" ]
}

@test "a TUI that left its session live is not moved by its later hop" {
  deck_up
  # Ctrl+Q back to the list, d-am-1 still working: the record goes
  detach
  "$FLEET" _round fleet >/dev/null
  hops d-am-1 d-am-2 agentdeck_am_1
  rounds
  [ ! -e "$FLEET_FIXTURES/deck.log" ]
  grep -q 'd-am-1' "$FLEET_STATE/fleet/hops-followed"
}

@test "a focus --attach that fails selects the successor instead" {
  deck_up
  detach
  touch "$FLEET_FIXTURES/deck-fail-attach"
  hops d-am-1 d-am-2 agentdeck_am_1
  rounds
  [ "$(cat "$FLEET_FIXTURES/deck.log")" = $'agent-deck session focus --remote thinkrepos d-am-2 --attach\nagent-deck session focus --remote thinkrepos d-am-2' ]
  grep -q 'd-am-1: focus --remote thinkrepos d-am-2 --attach failed; selected it' "$FLEET_STATE/fleet/follow.log"
}

@test "two hops in a row are followed in order" {
  deck_up
  detach
  printf 'd-am-1\td-am-2\tagentdeck_am_1\nd-am-2\td-am-3\tagentdeck_am_2\n' > "$FLEET_FIXTURES/hops-192.168.123.51"
  rounds
  [ "$(cat "$FLEET_FIXTURES/deck.log")" = $'agent-deck session focus --remote thinkrepos d-am-2 --attach\nagent-deck session focus --remote thinkrepos d-am-3 --attach' ]
}

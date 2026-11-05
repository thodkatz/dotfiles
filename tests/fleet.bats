#!/usr/bin/env bats
# fleet against a private tmux server and stub ssh/systemctl/ip (tests/stub),
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
  export FLEET_NO_HINTLOOP=1 FLEET_HINT_INTERVAL=3600 FLEET_OVERVIEW_INTERVAL=3600
  unset TMUX TMUX_PANE
}

teardown() { tmux -L "$FLEET_TMUX_SOCKET" kill-server 2>/dev/null || true; }

t() { tmux -L "$FLEET_TMUX_SOCKET" "$@"; }

# Append one row to a guest's status.sh fixture.
add_row() { jq --argjson r "$2" '. + [$r]' "$FLEET_FIXTURES/guest-$1.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-$1.json"; }
drop_row() { jq --arg e "$2" 'map(select(.entry != $e))' "$FLEET_FIXTURES/guest-$1.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-$1.json"; }
NEW_ROW='{"repo": "/workspace/nixed", "worktree": "/workspace/nixed", "branch": "impl/y", "live": "alive", "state": "running", "kind": "", "entry": "e-nixed-2", "continue": "dtach -a /var/tmp/agent-sessions/e-nixed-2.sock -r winch"}'

entries() { t list-panes -s -t =fleet -F '#{@fleet-entry}' | grep . | sort; }

# Poll up to 5 s until every agent pane has @fleet-ended set.
wait_ended() {
  local i
  for i in $(seq 50); do
    [ -n "$(entries)" ] && ! t list-panes -s -t =fleet -F '#{@fleet-entry}|#{@fleet-ended}' | grep -q '^e-.*|$' && return 0
    sleep 0.1
  done
  return 1
}

# Poll up to 5 s until the attach for entry $1 has reached the stub ssh.
wait_attached() {
  local i
  for i in $(seq 50); do
    grep -q "dtach -a /var/tmp/agent-sessions/$1.sock" "$FLEET_FIXTURES/ssh.log" && return 0
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

@test "probe script runs the unit's status.sh with its AGENT_SUPERVISE_REPOS (D5)" {
  run bash -c "'$FLEET' _probe-script | bash -s -- json"
  [ "$status" -eq 0 ]
  [ "$output" = "repos=/workspace/a /workspace/b tmpdir=/var/tmp args=--json" ]
  run bash -c "'$FLEET' _probe-script | bash -s -- table"
  [ "$output" = "repos=/workspace/a /workspace/b tmpdir=/var/tmp args=" ]
}

@test "probe script with no unit prints the no-supervisor marker (D5)" {
  touch "$FLEET_FIXTURES/unit-missing"
  run bash -c "'$FLEET' _probe-script | bash -s -- json"
  [ "$status" -eq 0 ]
  [ "$output" = "fleet:no-supervisor" ]
}

@test "status: a guest without the unit shows 'no supervisor', exit 0 (D5)" {
  touch "$FLEET_FIXTURES/nosup-192.168.123.51"
  run "$FLEET" status agentvm-thinkrepos
  [ "$status" -eq 0 ]
  [ "$output" = "no supervisor" ]
  run "$FLEET" status agentvm-repos
  [ "$output" = "table of 192.168.122.51" ]
}

@test "up: overview, then one window per host·repo in order (D6)" {
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'overview\nnixos·nixed\nthinkcentre·agent-methodology' ]
  run t list-panes -t =fleet:overview -F '#{@fleet-guest}'
  [ "$output" = $'agentvm-repos\nagentvm-thinkrepos' ]
}

@test "up: only dtach rows get panes, tagged and titled (D7, D15)" {
  "$FLEET" up
  run entries
  [ "$output" = $'e-am-1\ne-nixed-1\ne-nixed-stall' ]
  run t list-panes -s -t =fleet -F '#{@fleet-entry}|#{@fleet-title}'
  [[ "$output" == *'e-nixed-1|agentvm-repos · main · alive'* ]]
  [[ "$output" == *'e-am-1|agentvm-thinkrepos · ? · alive'* ]]
  wait_attached e-nixed-1
  grep -q "ssh -t -o BatchMode=yes -o ConnectTimeout=5 agentvm@192.168.122.51 dtach -a /var/tmp/agent-sessions/e-nixed-1.sock -e '^]' -r winch" "$FLEET_FIXTURES/ssh.log"
}

@test "sync: idempotent, adds new entries, leaves untagged panes alone (D8)" {
  "$FLEET" up
  t split-window -d -t =fleet:2 'sleep 600'
  before=$(t list-panes -a -F '#{pane_id}')
  run "$FLEET" sync -t fleet
  [ "$status" -eq 0 ]
  [ "$(t list-panes -a -F '#{pane_id}')" = "$before" ]
  add_row 192.168.122.51 "$NEW_ROW"
  "$FLEET" sync -t fleet
  [ "$(t list-panes -a -F '#{pane_id}' | wc -l)" -eq $(($(wc -l <<<"$before") + 1)) ]
  run entries
  [ "$output" = $'e-am-1\ne-nixed-1\ne-nixed-2\ne-nixed-stall' ]
  [ "$(t list-panes -t =fleet:2 -F '#{@fleet-entry}' | grep -c '^$')" -eq 1 ]
}

@test "sync: a gone entry whose attach ended is closed; a blocked one is retitled (D8)" {
  touch "$FLEET_FIXTURES/attach-exits"
  "$FLEET" up
  wait_ended
  # e-nixed-1 is gone; e-nixed-stall is now blocked (no continue).
  drop_row 192.168.122.51 e-nixed-1
  jq 'map(if .entry == "e-nixed-stall" then .live = "blocked #9" | .state = "blocked" | .continue = "" else . end)' \
    "$FLEET_FIXTURES/guest-192.168.122.51.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.122.51.json"
  "$FLEET" sync -t fleet
  run t list-panes -s -t =fleet -F '#{@fleet-entry}|#{@fleet-title}'
  [[ "$output" != *'e-nixed-1|'* ]]
  [[ "$output" == *'e-nixed-stall|agentvm-repos · impl/x · blocked #9'* ]]
}

@test "sync: an ended pane of a still-attachable entry is replaced (D8)" {
  touch "$FLEET_FIXTURES/attach-exits"
  "$FLEET" up
  wait_ended
  old=$(t list-panes -s -t =fleet -F '#{pane_id} #{@fleet-entry}' | awk '$2 == "e-am-1" { print $1 }')
  rm "$FLEET_FIXTURES/attach-exits"
  "$FLEET" sync -t fleet
  new=$(t list-panes -s -t =fleet -F '#{pane_id} #{@fleet-entry} #{@fleet-ended}' | awk '$2 == "e-am-1"')
  [ -n "$new" ] && [ "${new%% *}" != "$old" ]
  [[ "$new" != *' 1' ]]
}

@test "attach: a detach (socket still there) closes the pane (D11)" {
  touch "$FLEET_FIXTURES/attach-exits" "$FLEET_FIXTURES/sock-alive"
  "$FLEET" up
  for i in $(seq 50); do [ -z "$(entries)" ] && break; sleep 0.1; done
  [ -z "$(entries)" ]
}

@test "sync: one unreachable guest never fails it (D9)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run entries
  [ "$output" = $'e-nixed-1\ne-nixed-stall' ]
  run "$FLEET" status agentvm-thinkrepos
  [ "$output" = unreachable ]
}

@test "up: rebuilds a session without the boot marker, keeps one with it (D13)" {
  "$FLEET" up
  t new-window -d -t =fleet: -n mine 'sleep 600'
  "$FLEET" up
  t list-windows -t =fleet -F '#W' | grep -qx mine
  t set -gu @fleet-booted-fleet
  "$FLEET" up
  ! t list-windows -t =fleet -F '#W' | grep -qx mine
  [ "$(t show -gv @fleet-booted-fleet)" = 1 ]
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'overview\nnixos·nixed\nthinkcentre·agent-methodology' ]
}

@test "up --local: session fleet-<host>, this host's guests only (D4, D6)" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  run "$FLEET" --local up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet-nixos -F '#W'
  [ "$output" = $'overview\nnixos·nixed' ]
  [ "$(t show -t =fleet-nixos: -v @fleet-mode)" = local ]
  run "$FLEET" sync -t fleet-nixos
  [ "$status" -eq 0 ]
  ! grep -q 'theo@' "$FLEET_FIXTURES/ssh.log"
}

@test "sync: no fleet session says so, exit 1" {
  run "$FLEET" sync
  [ "$status" -eq 1 ]
  [[ "$output" == *'no fleet session'* ]]
}

@test "sync: a guest unreachable for one sync keeps its live panes" {
  "$FLEET" up
  wait_attached e-am-1
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  "$FLEET" sync -t fleet
  [[ "$(entries)" == *e-am-1* ]]
}

@test "hint: counts per host and unpaned entries (D10)" {
  "$FLEET" up
  add_row 192.168.122.51 "$NEW_ROW"
  run "$FLEET" hint -t fleet --refresh
  [ "$status" -eq 0 ]
  [ "$output" = "nixos 3▶ 2⚠ · thinkcentre 1▶ 0⚠ · ↻1" ]
  run "$FLEET" hint -t fleet
  [ "$output" = "nixos 3▶ 2⚠ · thinkcentre 1▶ 0⚠ · ↻1" ]
}

@test "hint: an unreachable host shows ✗; no cache prints nothing (D10)" {
  run "$FLEET" hint -t fleet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  "$FLEET" up
  run "$FLEET" hint -t fleet
  [ "$output" = "nixos 2▶ 2⚠ · thinkcentre ✗" ]
}

@test "sync and hint from a session fleet did not make act on fleet's (prefix F anywhere)" {
  "$FLEET" up
  t new-session -d -s mine 'sleep 600'
  add_row 192.168.122.51 "$NEW_ROW"
  run "$FLEET" sync -t mine
  [ "$status" -eq 0 ]
  [[ "$(entries)" == *e-nixed-2* ]]
  [ "$(t list-panes -t =mine -F x | wc -l)" -eq 1 ]
  run "$FLEET" hint -t mine
  [ "$output" = "nixos 3▶ 2⚠ · thinkcentre 1▶ 0⚠" ]
}

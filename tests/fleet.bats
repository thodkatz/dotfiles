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
  export HOME=$BATS_TEST_TMPDIR/home   # no real ~/.agentvm key leaks in
  mkdir -p "$HOME"
  unset AGENTVM_KEY
  unset TMUX TMUX_PANE
}

teardown() { tmux -L "$FLEET_TMUX_SOCKET" kill-server 2>/dev/null || true; }

t() { tmux -L "$FLEET_TMUX_SOCKET" "$@"; }

# Append one row to a guest's status.sh fixture.
add_row() { jq --argjson r "$2" '. + [$r]' "$FLEET_FIXTURES/guest-$1.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-$1.json"; }
drop_row() { jq --arg e "$2" 'map(select(.entry != $e))' "$FLEET_FIXTURES/guest-$1.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-$1.json"; }
NEW_ROW='{"repo": "/workspace/nixed", "worktree": "/workspace/nixed", "branch": "impl/y", "live": "alive", "state": "running", "kind": "", "entry": "e-nixed-2", "continue": "dtach -a /var/tmp/agent-sessions/e-nixed-2.sock -r winch"}'

# An agent pane's tags for its border: entry|glyph colour branch live.
tags() { t list-panes -s -t =fleet -F '#{@fleet-entry}|#{@fleet-glyph} #{@fleet-colour} #{@fleet-branch} #{@fleet-live}'; }
# The hint without its tmux styles.
plain() { sed 's/#\[[^]]*\]//g'; }

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

@test "status: a guest without the unit shows 'no supervisor', exit 0 (D5)" {
  touch "$FLEET_FIXTURES/nosup-192.168.123.51"
  run "$FLEET" status agentvm-thinkrepos
  [ "$status" -eq 0 ]
  [ "$output" = "no supervisor" ]
  run "$FLEET" status agentvm-repos
  [ "$output" = "table of 192.168.122.51" ]
}

@test "up: overview, then one window per repo, tagged with its host, in order (D6)" {
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet -F '#W|#{@fleet-host}|#{@fleet-host-colour}'
  [ "$output" = $'overview||\nnixed|nixos|#8ec07c\nagent-methodology|thinkcentre|#fe8019' ]
  run t list-panes -t =fleet:overview -F '#{@fleet-guest}'
  [ "$output" = $'agentvm-repos\nagentvm-thinkrepos' ]
}

@test "up: only dtach rows get panes, tagged and titled (D7, D15)" {
  "$FLEET" up
  run entries
  [ "$output" = $'e-am-1\ne-nixed-1\ne-nixed-stall' ]
  run tags
  [[ "$output" == *'e-nixed-1|● #b8bb26 main alive'* ]]
  [[ "$output" == *'e-am-1|● #b8bb26 ? alive'* ]]
  wait_attached e-nixed-1
  grep -q "ssh -t -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new agentvm@192.168.122.51 dtach -a /var/tmp/agent-sessions/e-nixed-1.sock -e '^]' -r winch" "$FLEET_FIXTURES/ssh.log"
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

@test "sync: an ended pane whose entry is gone or no longer attachable is closed (D8)" {
  touch "$FLEET_FIXTURES/attach-exits"
  "$FLEET" up
  wait_ended
  # e-nixed-1 is gone; e-nixed-stall is now blocked (no continue): its row stays, its attach has ended all the same.
  drop_row 192.168.122.51 e-nixed-1
  jq 'map(if .entry == "e-nixed-stall" then .live = "blocked #9" | .state = "blocked" | .continue = "" else . end)' \
    "$FLEET_FIXTURES/guest-192.168.122.51.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.122.51.json"
  "$FLEET" sync -t fleet
  run tags
  [[ "$output" != *'e-nixed-1|'* ]]
  [[ "$output" != *'e-nixed-stall|'* ]]
}

@test "sync: a live pane whose entry is now blocked stays, retitled (D8)" {
  "$FLEET" up
  wait_attached e-nixed-stall
  jq 'map(if .entry == "e-nixed-stall" then .live = "blocked #9" | .state = "blocked" | .continue = "" else . end)' \
    "$FLEET_FIXTURES/guest-192.168.122.51.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.122.51.json"
  "$FLEET" sync -t fleet
  run tags
  [[ "$output" == *'e-nixed-stall|◆ #d3869b impl/x blocked #9'* ]]
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

@test "sync: a hop (new entry, same socket) keeps its pane, retagged and retitled" {
  "$FLEET" up
  wait_attached e-nixed-1
  before=$(t list-panes -a -F '#{pane_id}' | sort)
  old=$(t list-panes -s -t =fleet -F '#{pane_id} #{@fleet-entry}' | awk '$2 == "e-nixed-1" { print $1 }')
  # chain.sh's next run: a new registry entry in the same dtach, on another branch; the old entry is no row now.
  jq 'map(if .entry == "e-nixed-1" then .entry = "e-nixed-1b" | .branch = "impl/z" else . end)' \
    "$FLEET_FIXTURES/guest-192.168.122.51.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.122.51.json"
  # Before the sync, the hint already counts the hop's entry as paned: its socket has a pane.
  run "$FLEET" hint -t fleet --refresh
  [[ "$output" != *'↻'* ]]
  "$FLEET" sync -t fleet
  [ "$(t list-panes -a -F '#{pane_id}' | sort)" = "$before" ]
  run t list-panes -s -t =fleet -F '#{pane_id}|#{@fleet-entry}|#{@fleet-glyph} #{@fleet-branch} #{@fleet-live}'
  [[ "$output" == *"$old|e-nixed-1b|● impl/z alive"* ]]
  [[ "$output" != *'|e-nixed-1|'* ]]
}

@test "sync: a hop keeps a pane made before @fleet-sock, its socket read from its command" {
  "$FLEET" up
  wait_attached e-nixed-1
  old=$(t list-panes -s -t =fleet -F '#{pane_id} #{@fleet-entry}' | awk '$2 == "e-nixed-1" { print $1 }')
  t set -p -u -t "$old" @fleet-sock
  before=$(t list-panes -a -F '#{pane_id}' | sort)
  jq 'map(if .entry == "e-nixed-1" then .entry = "e-nixed-1b" else . end)' \
    "$FLEET_FIXTURES/guest-192.168.122.51.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.122.51.json"
  "$FLEET" sync -t fleet
  [ "$(t list-panes -a -F '#{pane_id}' | sort)" = "$before" ]
  run t list-panes -s -t =fleet -F '#{pane_id}|#{@fleet-entry}|#{@fleet-sock}'
  [[ "$output" == *"$old|e-nixed-1b|192.168.122.51 /var/tmp/agent-sessions/e-nixed-1.sock"* ]]
}

@test "sync: of two live panes on one socket, the stale one is closed" {
  "$FLEET" up
  wait_attached e-nixed-1
  # What a hop made of a pane without @fleet-sock: the old pane, still tagged with the hop's previous entry, and a
  # second one on the same socket for the new entry.
  jq 'map(if .entry == "e-nixed-1" then .entry = "e-nixed-1b" else . end)' \
    "$FLEET_FIXTURES/guest-192.168.122.51.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.122.51.json"
  wid=$(t list-panes -s -t =fleet -F '#{window_id} #{@fleet-entry}' | awk '$2 == "e-nixed-1" { print $1 }')
  dup=$(t split-window -d -t "$wid" -P -F '#{pane_id}' 'sleep 600')
  t set -p -t "$dup" @fleet-entry e-nixed-1b
  t set -p -t "$dup" @fleet-sock '192.168.122.51 /var/tmp/agent-sessions/e-nixed-1.sock'
  "$FLEET" sync -t fleet
  run t list-panes -s -t =fleet -F '#{@fleet-entry}|#{@fleet-sock}'
  [ "$(grep -c '|192.168.122.51 /var/tmp/agent-sessions/e-nixed-1.sock$' <<<"$output")" -eq 1 ]
  [[ "$output" == *'e-nixed-1b|'* ]]
}

@test "sync: says what it did" {
  "$FLEET" up
  run "$FLEET" sync -t fleet
  [ "$output" = 'fleet: synced fleet, nothing to change' ]
  add_row 192.168.122.51 "$NEW_ROW"
  drop_row 192.168.122.51 e-nixed-stall
  touch "$FLEET_FIXTURES/attach-exits"
  run "$FLEET" sync -t fleet
  [ "$output" = 'fleet: synced fleet: 1 added' ]
}

@test "sync: a window made before the host tags (<host>·<repo>) is reused, renamed and tagged" {
  "$FLEET" up
  wid=$(t list-windows -t =fleet -F '#{window_id} #W' | awk '$2 == "nixed" { print $1 }')
  t rename-window -t "$wid" 'nixos·nixed' \; set -wu -t "$wid" @fleet-host \; set -wu -t "$wid" @fleet-host-colour
  add_row 192.168.122.51 "$NEW_ROW"
  "$FLEET" sync -t fleet
  run t list-windows -t =fleet -F '#{window_id}|#W|#{@fleet-host}|#{@fleet-host-colour}'
  [[ "$output" == *"$wid|nixed|nixos|#8ec07c"* ]]
  [ "$(grep -c nixed <<<"$output")" -eq 1 ]
  [[ "$(t list-panes -t "$wid" -F '#{@fleet-entry}')" == *e-nixed-2* ]]
}

@test "sync: such a window is renamed even when the sync adds no pane to it, and says so" {
  "$FLEET" up
  wid=$(t list-windows -t =fleet -F '#{window_id} #W' | awk '$2 == "nixed" { print $1 }')
  t rename-window -t "$wid" 'nixos·nixed' \; set -wu -t "$wid" @fleet-host \; set -wu -t "$wid" @fleet-host-colour
  run "$FLEET" sync -t fleet
  [ "$output" = 'fleet: synced fleet: 1 renamed' ]
  [[ "$(t list-windows -t =fleet -F '#{window_id}|#W|#{@fleet-host}|#{@fleet-host-colour}')" == *"$wid|nixed|nixos|#8ec07c"* ]]
}

@test "sync: overview panes carry their guest's host and its colour, also ones made before the tags" {
  "$FLEET" up
  t list-panes -t =fleet:overview -F '#{pane_id}' | while read -r p; do t set -pu -t "$p" @fleet-guest-host \; set -pu -t "$p" @fleet-guest-colour; done
  "$FLEET" sync -t fleet
  run t list-panes -t =fleet:overview -F '#{@fleet-guest}|#{@fleet-guest-host}|#{@fleet-guest-colour}'
  [[ "$output" == *"agentvm-repos|nixos|#8ec07c"* ]]
  [[ "$output" == *"agentvm-thinkrepos|thinkcentre|#fe8019"* ]]
}

@test "sync: an overview pane an older fleet started is restarted, a current one is left running" {
  "$FLEET" up
  old=$(t list-panes -t =fleet:overview -F '#{pane_id}' | head -1)
  cur=$(t list-panes -t =fleet:overview -F '#{pane_id}' | tail -1)
  t set -pu -t "$old" @fleet-overview
  pold=$(t display -p -t "$old" '#{pane_pid}') pcur=$(t display -p -t "$cur" '#{pane_pid}')
  "$FLEET" sync -t fleet
  [ "$(t display -p -t "$old" '#{pane_pid}')" != "$pold" ]
  [ "$(t display -p -t "$old" '#{@fleet-overview}')" = 3 ]
  [ "$(t display -p -t "$cur" '#{pane_pid}')" = "$pcur" ]
}

@test "sync: a pane's glyph and colour follow its live value, refreshed on every sync" {
  "$FLEET" up
  for pair in 'alive:● #b8bb26' 'waiting:○ #fabd2f' 'stalled:◐ #fabd2f' 'blocked #3:◆ #d3869b' 'dead:✗ #fb4934' \
    'dead?:✗ #fb4934' 'ended:· #928374' 'done:✓ #928374' 'gone:∅ #928374' '-:· #928374' '?:· #928374'; do
    live=${pair%:*} look=${pair##*:}
    jq --arg l "$live" 'map(if .entry == "e-nixed-stall" then .live = $l else . end)' \
      "$FLEET_FIXTURES/guest-192.168.122.51.json" > "$FLEET_FIXTURES/x" && mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.122.51.json"
    "$FLEET" sync -t fleet
    run tags
    [[ "$output" == *"e-nixed-stall|$look impl/x $live"* ]] || { echo "$live: $output"; false; }
  done
}

@test "overview colours: each status.sh row in its glyph's colour, header bold, rule and supervisor line grey" {
  table=$'  worktree  live\n  ────────  ────\n● nixed     alive\n◆ nixed/x   blocked #3\n✗ ethaae    dead\n· am        -\nsupervisor: last tick 2m ago'
  run "$FLEET" _colour <<<"$table"
  [ "$status" -eq 0 ]
  e=$'\033'
  [ "${lines[0]}" = "$e[1m  worktree  live$e[0m" ]
  [ "${lines[1]}" = "$e[38;2;146;131;116m  ────────  ────$e[0m" ]
  [ "${lines[2]}" = "$e[38;2;184;187;38m● nixed     alive$e[0m" ]
  [ "${lines[3]}" = "$e[38;2;211;134;155m◆ nixed/x   blocked #3$e[0m" ]
  [ "${lines[4]}" = "$e[38;2;251;73;52m✗ ethaae    dead$e[0m" ]
  [ "${lines[5]}" = "$e[38;2;146;131;116m· am        -$e[0m" ]
  [ "${lines[6]}" = "$e[38;2;146;131;116msupervisor: last tick 2m ago$e[0m" ]
}

@test "overview colours: a line already coloured (status.sh on a tty) or not a table passes through" {
  run "$FLEET" _colour <<<$'\033[32m● x\033[0m\nunreachable'
  [ "${lines[0]}" = $'\033[32m● x\033[0m' ]
  [ "${lines[1]}" = "unreachable" ]
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
  [ "$output" = $'overview\nnixed\nagent-methodology' ]
}

@test "up --local: session fleet-<host>, this host's guests only (D4, D6)" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  run "$FLEET" --local up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet-nixos -F '#W'
  [ "$output" = $'overview\nnixed' ]
  [ "$(t show -t =fleet-nixos: -v @fleet-mode)" = local ]
  run "$FLEET" sync -t fleet-nixos
  [ "$status" -eq 0 ]
  ! grep -q 'theo@' "$FLEET_FIXTURES/ssh.log"
}

@test "sync: no fleet session says so, exit 1" {
  run "$FLEET" sync
  [ "$status" -eq 1 ]
  [ "$output" = "fleet: no fleet session; start one with: fleet" ]
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
  [ "$(plain <<<"$output")" = "nixos ●3 ◆2  thinkcentre ●1  ↻1" ]
  run "$FLEET" hint -t fleet
  [ "$output" = "#[fg=#8ec07c]nixos#[default] #[fg=#b8bb26]●3#[default] #[fg=#d3869b]◆2#[default]  #[fg=#fe8019]thinkcentre#[default] #[fg=#b8bb26]●1#[default]  #[fg=#928374]↻1#[default]" ]
}

@test "hint: an unreachable host shows ✗; no cache prints nothing (D10)" {
  run "$FLEET" hint -t fleet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  "$FLEET" up
  run "$FLEET" hint -t fleet
  [ "$(plain <<<"$output")" = "nixos ●2 ◆2  thinkcentre ✗" ]
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
  [ "$(plain <<<"$output")" = "nixos ●3 ◆2  thinkcentre ●1" ]
}

@test "hint: a foreign session under --local falls back to fleet-<host>, not fleet (D6, D10)" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  "$FLEET" --local up
  t new-session -d -s mine 'sleep 600'
  run "$FLEET" hint -t mine
  [ "$status" -eq 0 ]
  [ "$(plain <<<"$output")" = "nixos ●2 ◆2" ]
}

@test "doctor: names the guest whose ssh fails, exits 1 (D14)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL  ssh agentvm@192.168.123.51 (agentvm-thinkrepos)'* ]]
  [[ "$output" == *'ok    ssh agentvm@192.168.122.51 (agentvm-repos)'* ]]
}

@test "doctor: all good exits 0 (D14)" {
  run "$FLEET" doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *FAIL* ]]
}

@test "doctor: a failed guest ssh shows ssh's own reason (D14)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" doctor
  [[ "$output" == *$'(agentvm-thinkrepos): no ssh, or no dtach there\n      ssh: connect to host 192.168.123.51 port 22: Connection timed out'* ]]
}

@test "ssh: guests get accept-new, hosts don't; no -i by default" {
  "$FLEET" status agentvm-repos
  grep -q 'StrictHostKeyChecking=accept-new agentvm@192.168.122.51 bash -s -- table' "$FLEET_FIXTURES/ssh.log"
  ! grep -q 'accept-new theo@' "$FLEET_FIXTURES/ssh.log"
  ! grep -q -- ' -i ' "$FLEET_FIXTURES/ssh.log"
}

@test "ssh: AGENTVM_KEY is the guests' identity, in panes too" {
  export AGENTVM_KEY=/keys/agentvm
  "$FLEET" up
  wait_attached e-nixed-1
  grep -q 'accept-new -i /keys/agentvm agentvm@192.168.122.51 bash -s -- json' "$FLEET_FIXTURES/ssh.log"
  grep -q 'accept-new -i /keys/agentvm agentvm@192.168.122.51 dtach -a' "$FLEET_FIXTURES/ssh.log"
  ! grep -q -- '-i /keys/agentvm theo@' "$FLEET_FIXTURES/ssh.log"
}

@test "ssh --local: the host's agentvm key when it exists, in panes too" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  "$FLEET" --local status agentvm-repos
  ! grep -q -- ' -i ' "$FLEET_FIXTURES/ssh.log"
  mkdir -p "$HOME/.agentvm/keys" && touch "$HOME/.agentvm/keys/id_ed25519"
  "$FLEET" --local up
  wait_attached e-nixed-1
  grep -q -- "-i $HOME/.agentvm/keys/id_ed25519 agentvm@192.168.122.51 dtach -a" "$FLEET_FIXTURES/ssh.log"
}

@test "attach: a lost link (ssh 255) says so and marks the pane ended" {
  touch "$FLEET_FIXTURES/attach-lost"
  "$FLEET" up
  wait_ended
  pid=$(t list-panes -s -t =fleet -F '#{pane_id} #{@fleet-entry}' | awk '$2 == "e-nixed-1" { print $1 }')
  for i in $(seq 50); do t capture-pane -p -t "$pid" | grep -q 'link lost' && break; sleep 0.1; done
  t capture-pane -p -t "$pid" | grep -qx '\[fleet\] link lost; prefix F syncs'
  ! grep -q 'test -S' "$FLEET_FIXTURES/ssh.log"
}

@test "sync: an ended pane whose guest is unreachable is closed" {
  touch "$FLEET_FIXTURES/attach-exits"
  "$FLEET" up
  wait_ended
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  "$FLEET" sync -t fleet
  run entries
  [ "$output" = $'e-nixed-1\ne-nixed-stall' ]
}

@test "sync: two at once add each pane once; a held lock exits 0 and says so" {
  "$FLEET" up
  add_row 192.168.122.51 "$NEW_ROW"
  "$FLEET" sync -t fleet & "$FLEET" sync -t fleet; wait
  run entries
  [ "$output" = $'e-am-1\ne-nixed-1\ne-nixed-2\ne-nixed-stall' ]
  flock "$FLEET_STATE/fleet/sync.lock" sleep 3 >/dev/null 3>&- &
  holder=$!
  for i in $(seq 50); do ! flock -n "$FLEET_STATE/fleet/sync.lock" true && break; sleep 0.1; done
  add_row 192.168.122.51 "${NEW_ROW//nixed-2/nixed-3}"
  run "$FLEET" sync -t fleet
  [ "$status" -eq 0 ]
  [ "$output" = "fleet: a sync of fleet is already running" ]
  [[ "$(entries)" != *e-nixed-3* ]]
  kill "$holder" 2>/dev/null || true
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

@test "hint loop: removes the hint when its session ends (D10)" {
  "$FLEET" up
  FLEET_HINT_INTERVAL=0.2 "$FLEET" _hintloop fleet &
  for i in $(seq 50); do [ -r "$FLEET_STATE/fleet/hintloop.pid" ] && break; sleep 0.1; done
  t kill-session -t =fleet
  wait
  [ ! -e "$FLEET_STATE/fleet/hint" ]
  [ ! -e "$FLEET_STATE/fleet/hintloop.pid" ]
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

@test "sync: replaces a hint loop an older fleet started (its pid file has no version)" {
  "$FLEET" up
  sleep 600 & old=$!
  echo "$old" > "$FLEET_STATE/fleet/hintloop.pid"
  FLEET_NO_HINTLOOP= "$FLEET" sync -t fleet
  ! kill -0 "$old" 2>/dev/null
  for i in $(seq 50); do grep -q ' 2$' "$FLEET_STATE/fleet/hintloop.pid" 2>/dev/null && break; sleep 0.1; done
  grep -q ' 2$' "$FLEET_STATE/fleet/hintloop.pid"
}

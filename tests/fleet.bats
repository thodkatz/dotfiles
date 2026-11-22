#!/usr/bin/env bats
# fleet against a private tmux server and stub ssh/ip (tests/stub), answering from a copy of tests/fixtures.
# Run from the repo root: bats tests/

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
  export HOME=$BATS_TEST_TMPDIR/home   # no real ~/.agentvm key leaks in
  mkdir -p "$HOME"
  unset AGENTVM_KEY
  unset TMUX TMUX_PANE
}

teardown() {
  tmux -L "$FLEET_TMUX_SOCKET" kill-server 2>/dev/null || true
  # the attach script test's own default server, under its TMUX_TMPDIR
  [ -z "${GUEST_TMUX:-}" ] || TMUX_TMPDIR=$GUEST_TMUX tmux kill-server 2>/dev/null || true
}

t() { tmux -L "$FLEET_TMUX_SOCKET" "$@"; }

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

# --- the session (layout E) --------------------------------------------------

@test "fleet start makes a window per guest, named after it, and nothing else" {
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet -F '#W|#{window_panes}|#{@fleet-guest}'
  [ "$output" = $'agentvm-repos|1|agentvm-repos · nixos\nagentvm-thinkrepos|1|agentvm-thinkrepos · thinkcentre' ]
  [ "$(t show -gv @fleet-booted-fleet)" = e ]
  [ "$(t show -t =fleet: -v @fleet-mode)" = remote ]
}

@test "up: a guest's window attaches its agents session over the guest's ssh, unshared" {
  "$FLEET" up
  [[ "$(t display -p -t =fleet:agentvm-thinkrepos '#{pane_start_command}')" == *fleet*_attach*thinkcentre*agentvm-thinkrepos* ]]
  wait_log 'agentvm@192.168.123.51 .*tmux -u attach -t =agents'
  grep 'tmux -u attach' "$FLEET_FIXTURES/ssh.log" | grep -q 'ssh -t -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new agentvm@192.168.123.51'
  ! grep 'tmux -u attach' "$FLEET_FIXTURES/ssh.log" | grep -q ControlMaster
}

@test "attach: after the attach ends, it says so and attaches again at Enter" {
  # the stub's attach holds; a failing one returns at once
  touch "$FLEET_FIXTURES/fail-192.168.122.51"
  "$FLEET" up
  for _ in $(seq 50); do t capture-pane -p -t =fleet:agentvm-repos | grep -q "not attached" && break; sleep 0.1; done
  t capture-pane -p -t =fleet:agentvm-repos | grep -qx "\[fleet\] agentvm-repos not attached; Enter or 15 s attaches again"
  n=$(grep -c 'agentvm@192.168.122.51 .*tmux -u attach' "$FLEET_FIXTURES/ssh.log")
  t send-keys -t =fleet:agentvm-repos Enter
  for _ in $(seq 50); do [ "$(grep -c 'agentvm@192.168.122.51 .*tmux -u attach' "$FLEET_FIXTURES/ssh.log")" -gt "$n" ] && break; sleep 0.1; done
  [ "$(grep -c 'agentvm@192.168.122.51 .*tmux -u attach' "$FLEET_FIXTURES/ssh.log")" -gt "$n" ]
}

@test "attach: a host down at the start gets a window named after it, which attaches its guest once it answers" {
  touch "$FLEET_FIXTURES/fail-thinkcentre"
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet -F '#W|#{@fleet-guest}'
  [ "$output" = $'agentvm-repos|agentvm-repos · nixos\nthinkcentre|thinkcentre' ]
  for _ in $(seq 50); do t capture-pane -p -t =fleet:thinkcentre | grep -q "not attached" && break; sleep 0.1; done
  t capture-pane -p -t =fleet:thinkcentre | grep -qx "\[fleet\] thinkcentre not attached; Enter or 15 s attaches again"
  rm "$FLEET_FIXTURES/fail-thinkcentre"
  t send-keys -t =fleet:thinkcentre Enter
  wait_log 'agentvm@192.168.123.51 .*tmux -u attach -t =agents'
}

@test "up: keeps its own session; rebuilds one an older fleet built or resurrect restored (D13)" {
  "$FLEET" up
  t new-window -d -t =fleet: -n mine 'sleep 600'
  "$FLEET" up
  t list-windows -t =fleet -F '#W' | grep -qx mine
  # an older fleet's session (layout d, its overview)
  t set -g @fleet-booted-fleet d
  "$FLEET" up
  ! t list-windows -t =fleet -F '#W' | grep -qx mine || false
  [ "$(t show -gv @fleet-booted-fleet)" = e ]
  # resurrect's (no marker)
  t new-window -d -t =fleet: -n mine 'sleep 600'
  t set -gu @fleet-booted-fleet
  "$FLEET" up
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'agentvm-repos\nagentvm-thinkrepos' ]
}

@test "up: an older fleet's session isn't rebuilt from inside it, which would end the pane fleet runs in" {
  "$FLEET" up
  t set -g @fleet-booted-fleet d
  t new-window -d -t =fleet: -n mine "'$FLEET' up > '$BATS_TEST_TMPDIR/out' 2>&1; echo \$? >> '$BATS_TEST_TMPDIR/out'; sleep 600"
  for _ in $(seq 50); do [ -s "$BATS_TEST_TMPDIR/out" ] && grep -qx 1 "$BATS_TEST_TMPDIR/out" && break; sleep 0.1; done
  [ "$(cat "$BATS_TEST_TMPDIR/out")" = $'fleet: fleet is from an older fleet and is rebuilt, which would end this pane: run fleet from another session, or detach first\n1' ]
  t list-windows -t =fleet -F '#W' | grep -qx mine
}

@test "up --local: session fleet-<host>, this host's guests only (D4, D6)" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  run "$FLEET" --local up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet-nixos -F '#W'
  [ "$output" = agentvm-repos ]
  [ "$(t show -t =fleet-nixos: -v @fleet-mode)" = local ]
  ! grep -q 'theo@' "$FLEET_FIXTURES/ssh.log"
}

@test "up: no guest at all is said, and no session" {
  echo '{}' > "$FLEET_FIXTURES/projects-nixos.json"
  AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos run "$FLEET" --local up
  [ "$status" -eq 1 ]
  [[ "$output" == *"fleet: no guests: $FLEET_FIXTURES/projects-nixos.json lists none" ]]
  ! t has-session -t =fleet-nixos 2>/dev/null
}

@test "--local with no projects.json: said once, as what to do, and no session" {
  for c in "" up ls; do
    AGENTVM_PROJECTS=$BATS_TEST_TMPDIR/none.json FLEET_HOSTNAME=nixos run "$FLEET" --local $c
    [ "$status" -eq 1 ]
    [ "$output" = "fleet: no $BATS_TEST_TMPDIR/none.json: no agentvm guests on this machine; drop --local to reach the hosts in $FLEET_HOSTS_FILE" ]
  done
  ! t has-session -t =fleet-nixos 2>/dev/null
  AGENTVM_PROJECTS=$BATS_TEST_TMPDIR/none.json FLEET_HOSTNAME=nixos run "$FLEET" --local attach agentvm-repos
  [ "$output" = "fleet: no $BATS_TEST_TMPDIR/none.json: no agentvm guests on this machine; drop --local to reach the hosts in $FLEET_HOSTS_FILE" ]
}

@test "--local with no projects.json: a running session is still attached" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  "$FLEET" --local up
  AGENTVM_PROJECTS=$BATS_TEST_TMPDIR/none.json run "$FLEET" --local up
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no hosts file: said once" {
  FLEET_HOSTS_FILE=$BATS_TEST_TMPDIR/none run "$FLEET"
  [ "$status" -eq 1 ]
  [ "$output" = "fleet: no hosts file $BATS_TEST_TMPDIR/none (one ssh destination per line, e.g. theo@nixos), or use --local" ]
}

@test "doctor --local names a missing projects.json" {
  AGENTVM_PROJECTS=$BATS_TEST_TMPDIR/none.json FLEET_HOSTNAME=nixos run "$FLEET" --local doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  no $BATS_TEST_TMPDIR/none.json: no agentvm guests on this machine"* ]]
  [[ "$output" != *"No such file"* ]]
}

@test "fleet sync, status and hint are unknown" {
  for c in sync status hint; do
    run "$FLEET" "$c"
    [ "$status" -eq 2 ]
    [[ "$output" == 'usage: fleet'* ]]
  done
}

# --- the attach: one guest from this terminal, the dashboard window ---------------

@test "attach script: the agents session gets one dashboard window, first, workmux's dashboard again after each jump" {
  export GUEST_TMUX=$BATS_TEST_TMPDIR/tt TMUX_TMPDIR=$BATS_TEST_TMPDIR/tt
  mkdir -p "$TMUX_TMPDIR"
  # no tmux server, then one without the agents session: said plainly, nothing made
  run bash -c "'$FLEET' _attach-script | bash"
  [ "$status" -eq 1 ]
  [ "$output" = "no agents on $(hostname) yet: its tmux has no session agents (methodology next starts one)" ]
  ! tmux has-session 2>/dev/null || false
  tmux new-session -d -s other 'sleep 600'
  run bash -c "'$FLEET' _attach-script | bash"
  [ "$status" -eq 1 ] && [[ "$output" == "no agents on "* ]]
  ! tmux has-session -t =agents 2>/dev/null || false
  tmux new-session -d -s agents -n bash 'sleep 600'
  tmux new-window -d -t =agents: -n wm-a 'sleep 600'
  for _ in 1 2; do
    # no terminal here, so the attach itself fails; the window is made first, once, and swapped into the first place
    run bash -c "'$FLEET' _attach-script | bash"
    run tmux list-windows -t =agents -F '#I #W'
    [ "$output" = $'0 dashboard\n1 wm-a\n2 bash' ]
  done
  [[ "$(tmux display -p -t =agents:dashboard '#{pane_start_command}')" == *'while :; do '*'workmux dashboard || sleep 5; done'* ]]
}

@test "attach: the only guest is attached from this terminal, its agents session opening on the dashboard; no fleet session" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  run timeout 3 "$FLEET" --local
  [ "$status" -eq 124 ]   # the stub's attach holds, as a real one does
  grep '^ssh -t .*agentvm@192.168.122.51 ' "$FLEET_FIXTURES/ssh.log" | grep -qF 'tmux -u attach -t =agents \; select-window -t =agents:dashboard'
  ! t has-session -t =fleet-nixos 2>/dev/null
}

@test "attach: a host that is down still counts, so two hosts with one down get the session, not a single attach" {
  touch "$FLEET_FIXTURES/fail-thinkcentre"
  run timeout 3 "$FLEET"   # no terminal here, so its own tmux attach fails; the session is made first
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'agentvm-repos\nthinkcentre' ]
}

@test "attach GUEST: that guest from this terminal, of several; an unknown one dies" {
  run timeout 3 "$FLEET" attach agentvm-thinkrepos
  [ "$status" -eq 124 ]
  grep -q 'agentvm@192.168.123.51 .*tmux -u attach' "$FLEET_FIXTURES/ssh.log"
  ! grep -q 'agentvm@192.168.122.51 .*tmux -u attach' "$FLEET_FIXTURES/ssh.log" || false
  ! t has-session -t =fleet 2>/dev/null || false
  run "$FLEET" attach nope
  [ "$status" -eq 1 ]
  [ "$output" = "fleet: no guest nope" ]
}

# --- doctor and ssh ----------------------------------------------------------

@test "doctor: names the guest whose ssh fails, with ssh's own reason, and one without tmux; exits 1 (D14)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *$'FAIL  ssh agentvm@192.168.123.51 (agentvm-thinkrepos): no ssh, or no tmux there\n      ssh: connect to host 192.168.123.51 port 22: Connection timed out'* ]]
  [[ "$output" == *'ok    ssh agentvm@192.168.122.51 (agentvm-repos): tmux'* ]]
  rm "$FLEET_FIXTURES/fail-192.168.123.51"; touch "$FLEET_FIXTURES/notmux-192.168.122.51"
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL  ssh agentvm@192.168.122.51 (agentvm-repos): no ssh, or no tmux there'* ]]
}

@test "doctor: all good exits 0 (D14)" {
  run "$FLEET" doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *FAIL* ]]
  [[ "$output" == *'ok    ssh theo@nixos'* ]]
  [[ "$output" == *'ok    route to 192.168.123.51 via tailscale'* ]]
  [[ "$output" == *'ok    ssh agentvm@192.168.123.51 (agentvm-thinkrepos): tmux'* ]]
}

@test "ssh: guests get accept-new, hosts don't; no -i by default" {
  "$FLEET" doctor
  grep -q 'StrictHostKeyChecking=accept-new agentvm@192.168.122.51 command -v tmux' "$FLEET_FIXTURES/ssh.log"
  ! grep -q 'accept-new theo@' "$FLEET_FIXTURES/ssh.log" || false
  ! grep -q -- ' -i ' "$FLEET_FIXTURES/ssh.log"
}

@test "ssh: discovery shares a connection; the attach doesn't" {
  "$FLEET" up
  wait_log 'agentvm@192.168.122.51 .*tmux -u attach'
  grep -q "ControlMaster=auto -o ControlPath=$FLEET_STATE/ssh/%C -o ControlPersist=10m .* theo@nixos cat /etc/agentvm/projects.json" "$FLEET_FIXTURES/ssh.log"
  ! grep 'tmux -u attach' "$FLEET_FIXTURES/ssh.log" | grep -q ControlMaster || false
  [ "$(stat -c %a "$FLEET_STATE/ssh")" = 700 ]
}

@test "ssh: no shared connection with FLEET_SSH_MUX=0, or a socket path past 108 bytes" {
  FLEET_SSH_MUX=0 "$FLEET" ls
  ! grep -q ControlMaster "$FLEET_FIXTURES/ssh.log" || false
  FLEET_STATE=$BATS_TEST_TMPDIR/$(printf 'x%.0s' $(seq 80)) "$FLEET" ls
  ! grep -q ControlMaster "$FLEET_FIXTURES/ssh.log"
}

@test "discovery: reads the hosts at once, in the hosts file's order" {
  touch "$FLEET_FIXTURES/slow-nixos" "$FLEET_FIXTURES/slow-thinkcentre"
  start=$(date +%s)
  run "$FLEET" ls
  [ $(( $(date +%s) - start )) -lt 4 ]
  [ "$output" = $'nixos agentvm-repos 192.168.122.51\nthinkcentre agentvm-thinkrepos 192.168.123.51' ]
}

@test "ssh: AGENTVM_KEY is the guests' identity, in the guests' windows too" {
  export AGENTVM_KEY=/keys/agentvm
  "$FLEET" up
  wait_log 'agentvm@192.168.123.51 .*tmux -u attach'
  grep -q 'accept-new -i /keys/agentvm agentvm@192.168.123.51 .*tmux -u attach' "$FLEET_FIXTURES/ssh.log"
  ! grep -q -- '-i /keys/agentvm theo@' "$FLEET_FIXTURES/ssh.log"
}

@test "ssh --local: the host's agentvm key when it exists, in the guest's window too" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  "$FLEET" --local doctor
  ! grep -q -- ' -i ' "$FLEET_FIXTURES/ssh.log" || false
  mkdir -p "$HOME/.agentvm/keys" && touch "$HOME/.agentvm/keys/id_ed25519"
  "$FLEET" --local up
  wait_log 'agentvm@192.168.122.51 .*tmux -u attach'
  grep -q -- "-i $HOME/.agentvm/keys/id_ed25519 agentvm@192.168.122.51 .*tmux -u attach" "$FLEET_FIXTURES/ssh.log"
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

@test "guest.conf: loads clean on tmux's own keys, the mouse on, windows from 0, the tabs ending in workmux's anchor" {
  run tmux -L "$FLEET_TMUX_SOCKET" -f "$ROOT/tmux/dot-config/tmux/guest.conf" new-session -d -s agents 'sleep 600'
  [ "$status" -eq 0 ] && [ -z "$output" ]
  [ "$(t show -gv prefix)" = C-b ]
  [ "$(t show -gv mouse)" = on ]
  [ "$(t show -gv base-index)" = 0 ]
  [[ "$(t show -gv window-status-format)" == *'#{?window_flags,,} ' ]]
  [[ "$(t show -gv window-status-current-format)" == *'#{?window_flags,,} ' ]]
}

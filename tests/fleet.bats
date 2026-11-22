#!/usr/bin/env bats
# fleet against a private tmux server and stub ssh/ip/workmux (tests/stub), answering from a copy of tests/fixtures.
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
  export FLEET_NO_LOOP=1 FLEET_OVERVIEW_INTERVAL=3600
  export HOME=$BATS_TEST_TMPDIR/home   # no real ~/.agentvm key leaks in
  mkdir -p "$HOME"
  unset AGENTVM_KEY
  unset TMUX TMUX_PANE
}

teardown() {
  tmux -L "$FLEET_TMUX_SOCKET" kill-server 2>/dev/null || true
  # a probe test's own default server, under its TMUX_TMPDIR
  [ -z "${PROBE_TMUX:-}" ] || TMUX_TMPDIR=$PROBE_TMUX tmux kill-server 2>/dev/null || true
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

# A tmux server of the probe test's own, as the guest's default one: TMUX_TMPDIR is a fresh directory.
probe_tmux() {
  export PROBE_TMUX=$BATS_TEST_TMPDIR/tt TMUX_TMPDIR=$BATS_TEST_TMPDIR/tt
  mkdir -p "$TMUX_TMPDIR"
}

# Run the probe script as a guest's ssh does, in mode $1, under PATH $2 (default: the tests' PATH).
probe() { "$FLEET" _probe-script | PATH=${2:-$PATH} "$(command -v bash)" -s -- "$1"; }

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

# --- the probe: workmux on the guest (D5) ------------------------------------

@test "probe script: workmux's JSON under a UTF-8 locale, then each pane's mode; its table" {
  probe_tmux
  tmux new-session -d -s agents -n a 'sleep 600'
  tmux new-window -d -t =agents: -n b 'sleep 600'
  tmux set -w -t =agents:a @am_mode unattended
  a=$(tmux display -p -t =agents:a '#{pane_id}') b=$(tmux display -p -t =agents:b '#{pane_id}')
  run env LC_ALL=C bash -c "$(declare -f probe); FLEET='$FLEET' probe json"
  [ "$status" -eq 0 ]
  [ "$(sed '/^fleet:modes$/,$d' <<<"$output")" = "$(cat "$FLEET_FIXTURES/guest-192.168.122.51.json")" ]
  [ "$(sed -n '/^fleet:modes$/,$p' <<<"$output" | sort)" = "$(printf '%s\n' fleet:modes "$a"$'\tunattended' "$b"$'\t' | sort)" ]
  # tmux needs a UTF-8 client for workmux's pane format, whatever the ssh session brings
  grep -qx 'LC_ALL=C.UTF-8 status --all --json' "$FLEET_FIXTURES/workmux.log"
  # a warning of workmux's on stderr stays out of the JSON
  touch "$FLEET_FIXTURES/workmux-warns"
  run probe json
  [ "$(sed '/^fleet:modes$/,$d' <<<"$output")" = "$(cat "$FLEET_FIXTURES/guest-192.168.122.51.json")" ]
  run probe table
  [ "$status" -eq 0 ]
  [ "$output" = "workmux table" ]
}

@test "probe script: no tmux server is no agents, without asking workmux" {
  probe_tmux
  run probe json
  [ "$status" -eq 0 ]
  [ "$output" = '{"agents": []}' ]
  run probe table
  [ "$output" = "no agents (no tmux server)" ]
  [ ! -e "$FLEET_FIXTURES/workmux.log" ]
}

@test "probe script: workmux off PATH is found in ~/.local/bin, else fleet:no-workmux; a failure is fleet:error" {
  probe_tmux
  tmux new-session -d -s agents 'sleep 600'
  # a PATH with tmux and no workmux, as a non-login ssh's (bash and cat for the stub workmux)
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  for c in tmux bash cat; do ln -s "$(command -v "$c")" "$BATS_TEST_TMPDIR/bin/$c"; done
  run probe json "$BATS_TEST_TMPDIR/bin"
  [ "$status" -eq 0 ]
  [ "$output" = fleet:no-workmux ]
  mkdir -p "$HOME/.local/bin" && cp "$ROOT/tests/stub/workmux" "$HOME/.local/bin/"
  run probe json "$BATS_TEST_TMPDIR/bin"
  [ "${lines[0]}" = "{" ]
  touch "$FLEET_FIXTURES/workmux-fails"
  run probe json "$BATS_TEST_TMPDIR/bin"
  [ "$status" -eq 0 ]
  [ "$output" = "fleet:error Error: tmux returned malformed pane information" ]
}

@test "status: a guest's workmux table; no workmux, workmux failing (D5)" {
  run "$FLEET" status agentvm-repos
  [ "$status" -eq 0 ]
  [ "$output" = "table of 192.168.122.51" ]
  touch "$FLEET_FIXTURES/nowm-192.168.123.51" "$FLEET_FIXTURES/wmfail-192.168.122.51"
  run "$FLEET" status agentvm-thinkrepos
  [ "$status" -eq 0 ]
  [ "$output" = "no workmux" ]
  run "$FLEET" status agentvm-repos
  [ "$output" = "workmux failed: Error: tmux returned malformed pane information" ]
}

@test "status: a hung probe times out as unreachable" {
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

# --- the session (layout D) --------------------------------------------------

@test "fleet start makes the overview, then a window per guest" {
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet -F '#W|#{window_panes}|#{@fleet-guest}'
  [ "$output" = $'overview|2|\nagentvm-repos|1|agentvm-repos\nagentvm-thinkrepos|1|agentvm-thinkrepos' ]
  [ "$(t show -gv @fleet-booted-fleet)" = d ]
  [ "$(t show -t =fleet: -v @fleet-mode)" = remote ]
}

@test "up: a guest's window attaches its agents session over the guest's ssh, unshared" {
  "$FLEET" up
  [[ "$(t display -p -t =fleet:agentvm-thinkrepos '#{pane_start_command}')" == *fleet*_attach*fleet*agentvm-thinkrepos* ]]
  wait_log 'agentvm@192.168.123.51 tmux -u attach -t =agents'
  grep 'tmux -u attach' "$FLEET_FIXTURES/ssh.log" | grep -q 'ssh -t -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new agentvm@192.168.123.51'
  ! grep 'tmux -u attach' "$FLEET_FIXTURES/ssh.log" | grep -q ControlMaster
}

@test "attach: after the attach ends, it says so and attaches again at Enter" {
  "$FLEET" up
  "$FLEET" _round fleet >/dev/null   # fleet.json for the pane below
  # the stub's attach holds; a failing one returns at once
  touch "$FLEET_FIXTURES/fail-192.168.122.51"
  t new-window -d -t =fleet: -n try "$FLEET _attach fleet agentvm-repos"
  for _ in $(seq 50); do t capture-pane -p -t =fleet:try | grep -q "not attached" && break; sleep 0.1; done
  t capture-pane -p -t =fleet:try | grep -qx "\[fleet\] agentvm-repos's agents: not attached; Enter or 15 s attaches again"
  n=$(grep -c 'agentvm@192.168.122.51 tmux -u attach' "$FLEET_FIXTURES/ssh.log")
  t send-keys -t =fleet:try Enter
  for _ in $(seq 50); do [ "$(grep -c 'agentvm@192.168.122.51 tmux -u attach' "$FLEET_FIXTURES/ssh.log")" -gt "$n" ] && break; sleep 0.1; done
  [ "$(grep -c 'agentvm@192.168.122.51 tmux -u attach' "$FLEET_FIXTURES/ssh.log")" -gt "$n" ]
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

@test "up: keeps its own session; rebuilds one an older fleet built or resurrect restored (D13)" {
  "$FLEET" up
  t new-window -d -t =fleet: -n mine 'sleep 600'
  "$FLEET" up
  t list-windows -t =fleet -F '#W' | grep -qx mine
  # an older fleet's session (layout c, its deck window)
  t set -g @fleet-booted-fleet c
  "$FLEET" up
  ! t list-windows -t =fleet -F '#W' | grep -qx mine || false
  [ "$(t show -gv @fleet-booted-fleet)" = d ]
  # resurrect's (no marker)
  t new-window -d -t =fleet: -n mine 'sleep 600'
  t set -gu @fleet-booted-fleet
  "$FLEET" up
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'overview\nagentvm-repos\nagentvm-thinkrepos' ]
}

@test "up: a host down at the start gets its guests' windows at a later fleet, once; a closed one comes back" {
  touch "$FLEET_FIXTURES/fail-thinkcentre"
  run "$FLEET" up
  [ "$status" -eq 0 ]
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'overview\nagentvm-repos' ]
  rm "$FLEET_FIXTURES/fail-thinkcentre"
  t new-window -d -t =fleet: -n mine 'sleep 600'
  # no ssh at an up of a running session: the new guest waits for the overview's round to find it
  "$FLEET" up
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'overview\nagentvm-repos\nmine' ]
  "$FLEET" _round fleet >/dev/null
  "$FLEET" up
  "$FLEET" up
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'overview\nagentvm-repos\nmine\nagentvm-thinkrepos' ]
  t kill-window -t =fleet:agentvm-repos
  "$FLEET" up
  run t list-windows -t =fleet -F '#W'
  [ "$output" = $'overview\nmine\nagentvm-thinkrepos\nagentvm-repos' ]
}

@test "up: an older fleet's session isn't rebuilt from inside it, which would end the pane fleet runs in" {
  "$FLEET" up
  t set -g @fleet-booted-fleet c
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
  [ "$output" = $'overview\nagentvm-repos' ]
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

OV_REPOS=$'agentvm-repos · nixos
  nixed (main)  claude  working  attended  2m
  nixed/impl-x (impl/x)  claude  waiting  unattended  30s
  nixed/fix-y  codex  done  2h
  agentvm (main)  opencode  working  1d'
OV_THINK=$'agentvm-thinkrepos · thinkcentre\n  agent-methodology (main)  claude  working  attended  59s'

@test "overview lists both guests' agents, from workmux's status" {
  run "$FLEET" _overview fleet --once
  [ "$status" -eq 0 ]
  [ "$output" = "$OV_REPOS"$'\n\n'"$OV_THINK" ]
  # one ssh per guest, over the shared connection
  [ "$(grep -c 'agentvm@192.168.123.51 bash -s -- json' "$FLEET_FIXTURES/ssh.log")" -eq 1 ]
  grep 'agentvm@192.168.123.51 bash -s -- json' "$FLEET_FIXTURES/ssh.log" | grep -q ControlMaster=auto
  # the round also writes the hint
  [ "$(plain < "$FLEET_STATE/fleet/hint")" = "nixos ●4 ◆1  thinkcentre ●1" ]
}

@test "overview: an agent missing fields shows ?, and one with no mode line leaves it out" {
  echo '{"agents": [{"status": "working"}]}' > "$FLEET_FIXTURES/guest-192.168.123.51.json"
  rm "$FLEET_FIXTURES/modes-192.168.122.51"
  run "$FLEET" _overview fleet --once
  [ "$status" -eq 0 ]
  [[ "$output" == *$'agentvm-repos · nixos\n  nixed (main)  claude  working  2m\n'* ]]
  [[ "$output" == *$'agentvm-thinkrepos · thinkcentre\n  ?  ?  working' ]]
}

@test "overview marks no agents, no workmux, workmux's error, output that isn't workmux's, and an unreachable guest or host" {
  echo '{"agents": []}' > "$FLEET_FIXTURES/guest-192.168.123.51.json"
  run "$FLEET" _overview fleet --once
  [ "$output" = "$OV_REPOS"$'\n\nagentvm-thinkrepos · thinkcentre\n  (no agents)' ]
  touch "$FLEET_FIXTURES/nowm-192.168.123.51" "$FLEET_FIXTURES/wmfail-192.168.122.51"
  run "$FLEET" _overview fleet --once
  [ "$output" = $'agentvm-repos · nixos\n  ✗ workmux: Error: tmux returned malformed pane information\n\nagentvm-thinkrepos · thinkcentre\n  no workmux' ]
  rm "$FLEET_FIXTURES/wmfail-192.168.122.51"
  echo 'not json' > "$FLEET_FIXTURES/guest-192.168.122.51.json"
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" _overview fleet --once
  [ "$output" = $'agentvm-repos · nixos\n  ✗ workmux: no agents in workmux\'s output\n\nagentvm-thinkrepos · thinkcentre\n  ✗ unreachable' ]
  touch "$FLEET_FIXTURES/fail-thinkcentre"
  run "$FLEET" _overview fleet --once
  [[ "$output" == *$'\n\nthinkcentre\n  ✗ unreachable' ]]
}

# --- the hint ----------------------------------------------------------------

@test "hint: per host its agents and the waiting ones, in its colour; --refresh rediscovers (D10)" {
  "$FLEET" up
  run "$FLEET" hint -t fleet
  [ "$output" = "#[fg=#8ec07c]nixos#[default] #[fg=#b8bb26]●4#[default] #[fg=#d3869b]◆1#[default]  #[fg=#fe8019]thinkcentre#[default] #[fg=#b8bb26]●1#[default]" ]
  jq '.agents += [.agents[0] + {worktree: "z", status: "waiting"}]' "$FLEET_FIXTURES/guest-192.168.123.51.json" > "$FLEET_FIXTURES/x"
  mv "$FLEET_FIXTURES/x" "$FLEET_FIXTURES/guest-192.168.123.51.json"
  run "$FLEET" hint -t fleet --refresh
  [ "$status" -eq 0 ]
  [ "$(plain <<<"$output")" = "nixos ●4 ◆1  thinkcentre ●2 ◆1" ]
}

@test "hint: an unreachable host shows ✗; no cache prints nothing (D10)" {
  run "$FLEET" hint -t fleet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  "$FLEET" up
  run "$FLEET" hint -t fleet
  [ "$(plain <<<"$output")" = "nixos ●4 ◆1  thinkcentre ✗" ]
}

@test "hint from a session fleet did not make shows fleet's" {
  "$FLEET" up
  t new-session -d -s mine 'sleep 600'
  run "$FLEET" hint -t mine --refresh
  [ "$status" -eq 0 ]
  [ "$(plain <<<"$output")" = "nixos ●4 ◆1  thinkcentre ●1" ]
}

@test "hint: a foreign session under --local falls back to fleet-<host>, not fleet (D6, D10)" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  "$FLEET" --local up
  t new-session -d -s mine 'sleep 600'
  run "$FLEET" hint -t mine
  [ "$status" -eq 0 ]
  [ "$(plain <<<"$output")" = "nixos ●4 ◆1" ]
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

@test "doctor: names the guest whose ssh fails, with ssh's own reason, and one without workmux; exits 1 (D14)" {
  touch "$FLEET_FIXTURES/fail-192.168.123.51"
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *$'FAIL  ssh agentvm@192.168.123.51 (agentvm-thinkrepos): no ssh, or no workmux there (agent-methodology\'s methodology place installs it)\n      ssh: connect to host 192.168.123.51 port 22: Connection timed out'* ]]
  [[ "$output" == *'ok    ssh agentvm@192.168.122.51 (agentvm-repos): workmux'* ]]
  rm "$FLEET_FIXTURES/fail-192.168.123.51"; touch "$FLEET_FIXTURES/nowm-192.168.122.51"
  run "$FLEET" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL  ssh agentvm@192.168.122.51 (agentvm-repos): no ssh, or no workmux there'* ]]
}

@test "doctor: all good exits 0 (D14)" {
  run "$FLEET" doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *FAIL* ]]
  [[ "$output" == *'ok    ssh theo@nixos'* ]]
  [[ "$output" == *'ok    route to 192.168.123.51 via tailscale'* ]]
  [[ "$output" == *'ok    ssh agentvm@192.168.123.51 (agentvm-thinkrepos): workmux'* ]]
}

@test "ssh: guests get accept-new, hosts don't; no -i by default" {
  "$FLEET" status agentvm-repos
  grep -q 'StrictHostKeyChecking=accept-new agentvm@192.168.122.51 bash -s -- table' "$FLEET_FIXTURES/ssh.log"
  ! grep -q 'accept-new theo@' "$FLEET_FIXTURES/ssh.log" || false
  ! grep -q -- ' -i ' "$FLEET_FIXTURES/ssh.log"
}

@test "ssh: probes and discovery share a connection; the btop pane doesn't" {
  "$FLEET" up
  wait_log 'agentvm@192.168.122.51 .*btop'
  grep -q "ControlPath=$FLEET_STATE/ssh/%C -o ControlPersist=10m -o BatchMode=yes .* agentvm@192.168.122.51 bash -s -- json" "$FLEET_FIXTURES/ssh.log"
  grep -q "ControlMaster=auto .* theo@nixos cat /etc/agentvm/projects.json" "$FLEET_FIXTURES/ssh.log"
  ! grep 'btop' "$FLEET_FIXTURES/ssh.log" | grep -q ControlMaster || false
  [ "$(stat -c %a "$FLEET_STATE/ssh")" = 700 ]
}

@test "ssh: no shared connection with FLEET_SSH_MUX=0, or a socket path past 108 bytes" {
  FLEET_SSH_MUX=0 "$FLEET" status agentvm-repos
  ! grep -q ControlMaster "$FLEET_FIXTURES/ssh.log" || false
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

@test "ssh: AGENTVM_KEY is the guests' identity, in the btop pane and the guests' windows too" {
  export AGENTVM_KEY=/keys/agentvm
  "$FLEET" up
  wait_log 'agentvm@192.168.122.51 .*btop'
  wait_log 'agentvm@192.168.123.51 tmux -u attach'
  grep -q 'accept-new -i /keys/agentvm agentvm@192.168.122.51 bash -s -- json' "$FLEET_FIXTURES/ssh.log"
  grep -q 'accept-new -i /keys/agentvm agentvm@192.168.122.51 .*btop' "$FLEET_FIXTURES/ssh.log"
  grep -q 'accept-new -i /keys/agentvm agentvm@192.168.123.51 tmux -u attach' "$FLEET_FIXTURES/ssh.log"
  ! grep -q -- '-i /keys/agentvm theo@' "$FLEET_FIXTURES/ssh.log"
}

@test "ssh --local: the host's agentvm key when it exists, in the btop pane too" {
  export AGENTVM_PROJECTS=$FLEET_FIXTURES/projects-nixos.json FLEET_HOSTNAME=nixos
  "$FLEET" --local status agentvm-repos
  ! grep -q -- ' -i ' "$FLEET_FIXTURES/ssh.log" || false
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

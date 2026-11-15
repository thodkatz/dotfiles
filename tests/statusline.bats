#!/usr/bin/env bats
# The status-line renderer (claude/dot-config/agent-methodology/statusline-render) against a stub claude-powerline
# (tests/stub), with the environment agent-methodology's statusline.sh gives it. Run from the repo root: bats tests/

setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  RENDER=$ROOT/claude/dot-config/agent-methodology/statusline-render
  NO_PL_PATH=$(tr ':' '\n' <<<"$PATH" | while read -r d; do [ -x "$d/claude-powerline" ] || printf '%s:' "$d"; done)
  export PATH="$ROOT/tests/stub:$PATH"
  export HOME=$BATS_TEST_TMPDIR/home   # no real ~/.local/bin/claude-powerline
  mkdir -p "$HOME"
  export AGENT_SL_PLAIN="[Fable 5.2] ctx 42k/150k (28%)"
  unset AGENT_SL_CTX AGENT_SL_BUDGET AGENT_SL_INBOX STATUSLINE_POWERLINE_CONFIG
  ARROW=$'\xee\x82\xb0'
}

render() { "$RENDER" <<<'{"model":{"display_name":"Fable 5.2"}}'; }
plain_text() { sed 's/\x1b\[[0-9;]*m//g' <<<"$1"; }

@test "the budget box joins claude-powerline's last box" {
  AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 run render
  [ "$status" -eq 0 ]
  [ "$(plain_text "$output")" = " weekly $ARROW ctx ██░░░░░░░░ 42k/150k $ARROW" ]
  # the arrow between them: the last box's colour on the budget box's, with no reset before it
  [[ $output == *" weekly "$'\e[48;2;80;73;69m\e[38;2;60;56;54m'"$ARROW"$'\e[38;2;184;187;38m'" ctx "* ]]
  # and the line closes with an arrow in the budget box's colour
  [[ $output == *$'\e[0m\e[38;2;80;73;69m'"$ARROW"$'\e[0m' ]]
}

@test "the budget box turns yellow from 80% and red with HAND OFF from 100%" {
  AGENT_SL_CTX=119999 AGENT_SL_BUDGET=150000 run render
  [[ $output == *$'\e[48;2;80;73;69m'* && $output != *"HAND OFF"* ]]
  AGENT_SL_CTX=120000 AGENT_SL_BUDGET=150000 run render
  [[ $output == *$'\e[48;2;250;189;47m'*"ctx ████████░░ 120k/150k "* && $output != *"HAND OFF"* ]]
  AGENT_SL_CTX=156000 AGENT_SL_BUDGET=150000 run render
  [[ $output == *$'\e[48;2;251;73;52m'*"ctx ██████████ 156k/150k HAND OFF "* ]]
}

@test "the inbox box shows only over 0, after the budget box" {
  AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 AGENT_SL_INBOX=0 run render
  [[ $output != *inbox* ]]
  AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 AGENT_SL_INBOX=2 run render
  [ "$(plain_text "$output")" = " weekly $ARROW ctx ██░░░░░░░░ 42k/150k $ARROW inbox 2 $ARROW" ]
  AGENT_SL_INBOX=3 run render   # no budget given: the inbox box alone
  [ "$(plain_text "$output")" = " weekly $ARROW inbox 3 $ARROW" ]
}

@test "with nothing of ours to show, claude-powerline's line is printed as it came" {
  expected=$("$ROOT/tests/stub/claude-powerline" </dev/null)
  run render
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "claude-powerline is run with the package's config" {
  STUB_PL_ARGS=$BATS_TEST_TMPDIR/args run render
  [ "$(cat "$BATS_TEST_TMPDIR/args")" = "--config=$ROOT/claude/dot-config/agent-methodology/../claude-powerline/config.json" ]
  jq -e '.display.lines[0].segments | has("directory") and has("git") and has("thinking")' \
    "$ROOT/claude/dot-config/claude-powerline/config.json"
}

@test "a line that ends another way gets our boxes after a space" {
  STUB_PL_OUT="dir | model" AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 run render
  [ "$(plain_text "$output")" = "dir | model $ARROW ctx ██░░░░░░░░ 42k/150k $ARROW" ]
}

@test "a multi-line powerline keeps its lines, ours joined onto the last" {
  two=$'first line\n'$("$ROOT/tests/stub/claude-powerline" </dev/null)
  STUB_PL_OUT=$two AGENT_SL_INBOX=1 run render
  [ "${lines[0]}" = "first line" ]
  [ "$(plain_text "${lines[1]}")" = " weekly $ARROW inbox 1 $ARROW" ]
}

@test "without claude-powerline: the plain line, or a failure when there is none" {
  PATH=$NO_PL_PATH run render
  [ "$status" -eq 0 ]
  [ "$output" = "$AGENT_SL_PLAIN" ]
  AGENT_SL_PLAIN="" PATH=$NO_PL_PATH run render
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "claude-powerline failing or printing nothing: the plain line" {
  STUB_PL_FAIL=1 AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 run render
  [ "$output" = "$AGENT_SL_PLAIN" ]
  STUB_PL_OUT="" run render
  [ "$output" = "$AGENT_SL_PLAIN" ]
}

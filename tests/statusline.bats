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
  unset AGENT_SL_CTX AGENT_SL_BUDGET
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
  AGENT_SL_CTX=149999 AGENT_SL_BUDGET=150000 run render
  [[ $output == *$'\e[48;2;250;189;47m'*"ctx █████████░ 149k/150k "* && $output != *"HAND OFF"* ]]
  AGENT_SL_CTX=150000 AGENT_SL_BUDGET=150000 run render   # at the budget, as statusline.sh's own line
  [[ $output == *$'\e[48;2;251;73;52m'*"ctx ██████████ 150k/150k HAND OFF "* ]]
  AGENT_SL_CTX=156000 AGENT_SL_BUDGET=150000 run render
  [[ $output == *$'\e[48;2;251;73;52m'*"ctx ██████████ 156k/150k HAND OFF "* ]]
}

@test "a count with a leading zero is read as decimal" {
  AGENT_SL_CTX=042000 AGENT_SL_BUDGET=150000 run render
  [ "$(plain_text "$output")" = " weekly $ARROW ctx ██░░░░░░░░ 42k/150k $ARROW" ]
}

@test "with nothing of ours to show, claude-powerline's line is printed as it came" {
  expected=$("$ROOT/tests/stub/claude-powerline" </dev/null)
  run render
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "claude-powerline is run with the package's config and Claude Code's input" {
  STUB_PL_ARGS=$BATS_TEST_TMPDIR/args STUB_PL_STDIN=$BATS_TEST_TMPDIR/stdin run render
  # two arguments: claude-powerline cuts --config=<path> at an = in the path
  [ "$(cat "$BATS_TEST_TMPDIR/args")" = "--config $ROOT/claude/dot-config/agent-methodology/../claude-powerline/config.json" ]
  [ "$(cat "$BATS_TEST_TMPDIR/stdin")" = '{"model":{"display_name":"Fable 5.2"}}' ]
}

@test "the config: our six boxes, gruvbox at every usage level, truecolor whatever the terminal says" {
  conf=$ROOT/claude/dot-config/claude-powerline/config.json
  jq -e '.display.lines[0].segments | keys_unsorted == ["directory", "git", "model", "thinking", "block", "weekly"]' "$conf"
  # claude-powerline recolours the usage boxes from 50% and 80%: without these two, in its dark theme's colours
  jq -e '.colors.custom | has("contextWarning") and has("contextCritical")' "$conf"
  # the join needs 38;2 codes: without this, a terminal that doesn't say truecolor gets 38;5 and our boxes a gap
  jq -e '.display.colorCompatibility == "truecolor"' "$conf"
}

@test "a config that can't be read: the plain line, not claude-powerline's defaults" {
  mkdir -p "$BATS_TEST_TMPDIR/pkg/agent-methodology"
  cp "$RENDER" "$BATS_TEST_TMPDIR/pkg/agent-methodology/"
  RENDER=$BATS_TEST_TMPDIR/pkg/agent-methodology/statusline-render
  AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 run render
  [ "$output" = "$AGENT_SL_PLAIN" ]
}

@test "a line that ends another way gets our boxes after a space" {
  STUB_PL_OUT="dir | model" AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 run render
  # no arrow into our first box: there is no box before it
  [ "$(plain_text "$output")" = "dir | model  ctx ██░░░░░░░░ 42k/150k $ARROW" ]
}

@test "a multi-line powerline keeps its lines, ours joined onto the last" {
  two=$'first line\n'$("$ROOT/tests/stub/claude-powerline" </dev/null)
  STUB_PL_OUT=$two AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 run render
  [ "${lines[0]}" = "first line" ]
  [ "$(plain_text "${lines[1]}")" = " weekly $ARROW ctx ██░░░░░░░░ 42k/150k $ARROW" ]
}

@test "without claude-powerline: the plain line, or a failure when there is none" {
  PATH=$NO_PL_PATH run render
  [ "$status" -eq 0 ]
  [ "$output" = "$AGENT_SL_PLAIN" ]
  AGENT_SL_PLAIN="" PATH=$NO_PL_PATH run render
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "claude-powerline off the PATH is found in ~/.local/bin, where README's npm line puts it" {
  mkdir -p "$HOME/.local/bin"
  ln -s "$ROOT/tests/stub/claude-powerline" "$HOME/.local/bin/claude-powerline"
  PATH=$NO_PL_PATH AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 run render
  [ "$(plain_text "$output")" = " weekly $ARROW ctx ██░░░░░░░░ 42k/150k $ARROW" ]
}

@test "claude-powerline failing or printing nothing: the plain line" {
  STUB_PL_FAIL=1 AGENT_SL_CTX=42000 AGENT_SL_BUDGET=150000 run render
  [ "$output" = "$AGENT_SL_PLAIN" ]
  STUB_PL_OUT="" run render
  [ "$output" = "$AGENT_SL_PLAIN" ]
}

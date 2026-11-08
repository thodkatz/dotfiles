#!/usr/bin/env bash
# Fake status.sh: shows what the probe script ran it with, or prints $FLEET_FIXTURES/status-json when it exists.
[ ! -e "$FLEET_FIXTURES/status-json" ] || exec cat "$FLEET_FIXTURES/status-json"
echo "repos=$AGENT_SUPERVISE_REPOS tmpdir=$TMPDIR args=$*"

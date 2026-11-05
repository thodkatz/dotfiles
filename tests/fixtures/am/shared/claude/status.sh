#!/usr/bin/env bash
# Fake status.sh: shows what the probe script ran it with.
echo "repos=$AGENT_SUPERVISE_REPOS tmpdir=$TMPDIR args=$*"

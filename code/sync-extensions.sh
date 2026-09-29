#!/usr/bin/env bash
set -euo pipefail

# Exports the currently installed extensions to extensions.txt, the source
# of truth for `code --install-extension` (see README.md). Extensions are
# never auto-installed on remote hosts; run the README command manually
# when you want them.

cd "$(dirname "$0")"

code --list-extensions > extensions.txt

echo "sync-default-extensions.sh: exported extensions.txt ($(wc -l < extensions.txt | tr -d ' ') extensions)" >&2

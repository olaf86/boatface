#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: run-with-node22.sh <command> [args...]" >&2
  exit 1
fi

export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "nvm not found at $NVM_DIR/nvm.sh" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "$NVM_DIR/nvm.sh"

if ! nvm version 22 >/dev/null 2>&1; then
  echo "Node 22 is not installed in nvm. Run: nvm install 22" >&2
  exit 1
fi

nvm exec 22 "$@"

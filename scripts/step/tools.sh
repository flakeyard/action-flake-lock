#!/usr/bin/env bash
# Builds the tools of the action from its own flake with the nix of the job,
# and records their store paths for the next steps. Starts the files that the
# steps share afresh.
#
# Inputs (environment): none.
set -euo pipefail
# Builtins only until lib/env.sh replaces PATH, which is the job's.
lib=${BASH_SOURCE[0]%/*}/../lib
# shellcheck source-path=SCRIPTDIR source=../lib/env.sh
source "$lib/env.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/tools.sh
source "$lib/tools.sh"

readonly TOOLS=(jq gh)

main() {
  local nix name
  nix=$(job_nix) || fail "No nix on PATH: install Nix with flakes enabled before this action, such as with flakeyard/action-setup-nix."
  rm -rf -- "$STATE_DIR"
  for name in "${TOOLS[@]}"; do
    build_tool "$nix" "$name"
  done
}

main "$@"

#!/usr/bin/env bash
# Substitutes the tools of the action with the nix of the job, from the store
# paths that tools.nix records for its system, and records them for the next
# steps. Starts the files that the steps share afresh.
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
  local nix system name
  nix=$(job_tool nix) || fail "No nix on PATH: install Nix with flakes enabled before this action, such as with flakeyard/action-setup-nix."
  system=$(job_system "$nix") || fail "Cannot read the system of $nix."
  rm -rf -- "$STATE_DIR"
  for name in "${TOOLS[@]}"; do
    realise_tool "$nix" "$system" "$name"
  done
}

main "$@"

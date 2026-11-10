# shellcheck shell=bash
# The environment of every step: that of the shell library, with strict mode
# and the tools of the runner, and the files that the steps share. Sourced
# first, not run.

# shellcheck source=/dev/null
source "${SHELL_LIB:?}/env.sh"
step_environment

# shellcheck disable=SC2034 # used by the steps
ACTION_DIR=$(cd -- "${BASH_SOURCE[0]%/*}/../.." && pwd)
# The modules of jq that the steps run.
# shellcheck disable=SC2034 # used by the steps
LOCK_MODULES=$ACTION_DIR/scripts/lock
# What a step leaves for the next steps of the same run of the action: the
# parsed lock, and the findings of each rule in a file named after it.
# shellcheck disable=SC2034 # used by the steps
STATE_DIR=${RUNNER_TEMP:?}/action-flake-lock
# shellcheck disable=SC2034 # used by the steps
PARSED_LOCK=$STATE_DIR/lock.json
# shellcheck disable=SC2034 # used by the steps
FINDINGS_DIR=$STATE_DIR/findings

# shellcheck shell=bash
# The environment of every step: strict mode, the tools of the runner and the
# files that the steps share. Sourced first, not run.

# set -e also in command substitutions.
shopt -s inherit_errexit

# The tools of the runner. Only the tests change it, in their own copy of the
# action; nothing at run time can.
SYSTEM_PATH=/usr/sbin:/usr/bin:/sbin:/bin

# PATH of the job, where nix is, and the runner's own for everything else.
# shellcheck disable=SC2034 # used by lib/tools.sh
JOB_PATH=${PATH-}
export PATH=$SYSTEM_PATH LC_ALL=C

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

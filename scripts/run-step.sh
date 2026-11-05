#!/usr/bin/env bash
# Usage: /usr/bin/bash -p scripts/run-step.sh STEP
#
# Runs step/STEP.sh, the script of one step of the action, with only the
# variables the scripts read. Earlier steps can set any variable for the rest
# of the job, such as exported functions (BASH_FUNC_name%%) that replace
# commands, or SHELLOPTS and PS4 that run code. bash -p imports no functions,
# SHELLOPTS or BASHOPTS and reads no BASH_ENV, here and in the step. Variables
# of the dynamic loader, such as LD_PRELOAD, are not covered: the loader reads
# them when the first bash of the step starts, before this script.
set -euo pipefail

# The inputs of the steps, the runner's variables and the user's. PATH is the
# job's, where nix is; lib/env.sh replaces it, and the steps run only builtins
# before. The variables of Nix, such as NIX_CONFIG, do not reach it.
ALLOWED_VARS=(
  LOCK_PATH ALLOW_DUPLICATES PIN_FORM TOKEN
  RUNNER_OS RUNNER_ARCH RUNNER_ENVIRONMENT RUNNER_TEMP
  GITHUB_WORKSPACE GITHUB_SERVER_URL GITHUB_STEP_SUMMARY
  HOME XDG_CONFIG_HOME XDG_CACHE_HOME PATH
)

# A name only, so that no path leaves step/.
STEP_RE='^[a-z-]+$'

step=${1:?usage: run-step.sh STEP}
[[ $step =~ $STEP_RE ]] || {
  echo "::error::run-step.sh: invalid step name '$step'."
  exit 2
}

vars=()
for name in "${ALLOWED_VARS[@]}"; do
  if [[ -v $name ]]; then
    vars+=("$name=${!name}")
  fi
done
# Only absolute paths and builtins until then: PATH is the job's.
exec /usr/bin/env -i "${vars[@]}" /usr/bin/bash -p "${BASH_SOURCE[0]%/*}/step/$step.sh"

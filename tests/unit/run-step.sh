# shellcheck shell=bash
# Tests of scripts/run-step.sh.
# shellcheck disable=SC2154 # work and action come from setup.
# shellcheck disable=SC2016 # code for the scripts, not expanded here

# Variables that earlier steps of a job can set to run code in the action.
readonly HOSTILE_VARS=(
  'BASH_FUNC_printf%%=() { builtin echo INJECTED; }'
  'BASH_FUNC_realpath%%=() { builtin echo INJECTED; }'
  SHELLOPTS=xtrace 'PS4=$(builtin echo PS4-RAN >&2)' BASHOPTS=extdebug
  BASH_ENV=/dev/null NIX_CONFIG="sandbox = false" GH_HOST=ghes.example.com
)

# step_setup: as-action.sh, which runs run-step.sh like the steps of
# action.yml.
step_setup() {
  setup
  printf '#!%s -p\n%s\n' "$sysbin/bash" \
    "$sysbin/bash"' -p "${BASH_SOURCE[0]%/*}/run-step.sh" "$@"' >"$action/scripts/as-action.sh"
  chmod +x "$action/scripts/as-action.sh"
}

# probe_setup: also the step probe, which prints what it got: its functions,
# its shell options, a child's functions and its environment.
probe_setup() {
  step_setup
  cat >"$action/scripts/step/probe.sh" <<'PROBE'
printf 'functions: %s\n' "$(declare -F | wc -l)"
printf 'xtrace: %s\n' "$([[ -o xtrace ]] && echo on || echo off)"
printf 'child functions: %s\n' "$(bash -c 'declare -F | wc -l')"
env
PROBE
}

probe_setup
run "run-step: no functions or options of the job" ok as-action.sh \
  "${HOSTILE_VARS[@]}" -- probe
expect message "functions: 0"
expect message "xtrace: off"
expect message "child functions: 0"
expect no-message "INJECTED"
expect no-message "PS4-RAN"
expect no-message "BASH_FUNC_"
expect no-message "NIX_CONFIG"
expect no-message "GH_HOST"
finish

probe_setup
run "run-step: the variables of the scripts" ok as-action.sh \
  ALLOW_DUPLICATES=a TOKEN=t XDG_CONFIG_HOME=/x XDG_CACHE_HOME=/y -- probe
for var in LOCK_PATH=flake.lock ALLOW_DUPLICATES=a PIN_FORM=true TOKEN=t \
  RUNNER_OS=Linux RUNNER_ARCH=X64 RUNNER_ENVIRONMENT=github-hosted \
  RUNNER_TEMP="$work/temp" GITHUB_WORKSPACE="$work/workspace" \
  GITHUB_SERVER_URL=https://github.com GITHUB_STEP_SUMMARY="$work/summary" \
  HOME="$work/home" XDG_CONFIG_HOME=/x XDG_CACHE_HOME=/y \
  PATH="$root/tests/bin:$sysbin"; do
  expect message "$var"
done
expect no-message "CALLS="
finish

step_setup
run "run-step: functions do not replace commands of step/check.sh" fail as-action.sh \
  "${HOSTILE_VARS[@]}" RUNNER_ARCH=X86 -- check
expect message "::error::Unsupported runner Linux/X86"
expect no-message "INJECTED"
finish

step_setup
run "run-step: only steps of the action" fail as-action.sh -- ../run-step
expect message "invalid step name '../run-step'"
finish

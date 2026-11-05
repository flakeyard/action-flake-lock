# shellcheck shell=bash
# The life of one test: its name, its directory with a copy of the action and
# a fake runner, and the counts of passed and failed tests. Source this file;
# it expects root, the repository's directory.
# shellcheck disable=SC2034 # work, action, state and env_vars are used by checks.sh

: "${root:?}"
failed=0 passed=0 current="" work=""

# The tools of the runner that the scripts may run, without the nix, gh and
# jq of the host: the scripts must use the tools of the action.
readonly RUNNER_TOOLS=(bash env cat grep mkdir mktemp rm realpath sleep wc)
# The jq of the host, for the tests and for the store of the nix stub.
HOST_JQ=$(command -v jq)
readonly HOST_JQ

# Files shared by all tests, removed at the end.
shared=$(mktemp -d)
trap 'rm -rf -- "$shared"' EXIT
sysbin=$shared/bin
mkdir "$sysbin"
for tool in "${RUNNER_TOOLS[@]}"; do
  ln -s "$(command -v "$tool")" "$sysbin/$tool"
done

# start NAME: start test NAME.
start() {
  current=$1
}

# report MESSAGE: fail the current test.
report() {
  [[ -n $current ]] || return 0
  echo "FAIL $current: $1"
  failed=$((failed + 1))
  current=""
}

# finish: count the current test as passed unless it failed, and remove its
# directory.
finish() {
  if [[ -n $current ]]; then passed=$((passed + 1)); fi
  current=""
  if [[ -n $work ]]; then rm -rf -- "$work"; fi
  work=""
}

# redirect FILE FROM TO: replace FROM with TO in FILE of the copy of the
# action; exits when FILE no longer has FROM, since the scripts would then use
# the host.
redirect() {
  local file=$action/$1 from=$2 to=$3
  grep -qF -- "$from" "$file" || {
    echo "tests: no '$from' in $1 to redirect" >&2
    exit 2
  }
  sed -i -e "s|$from|$to|g" "$file"
}

# copy_action: the scripts and the flake in $action, with the tools of the
# runner in $sysbin.
copy_action() {
  mkdir -p "$action"
  cp -R "$root/scripts" "$root/action.yml" "$root/flake.nix" "$root/flake.lock" "$action/"
  redirect scripts/lib/env.sh "SYSTEM_PATH=/usr/sbin:/usr/bin:/sbin:/bin" "SYSTEM_PATH=$sysbin"
  redirect scripts/run-step.sh /usr/bin/env "$sysbin/env"
  redirect scripts/run-step.sh /usr/bin/bash "$sysbin/bash"
}

# setup: a fresh copy of the action, a workspace and the variables of a
# GitHub-hosted x86_64 Linux runner. The job PATH has the stubs of tests/bin.
setup() {
  work=$(mktemp -d)
  action=$work/action
  # STATE_DIR of lib/env.sh: the files that the steps share.
  state=$work/temp/action-flake-lock
  copy_action
  mkdir -p "$work/workspace" "$work/temp" "$work/home" "$work/fixtures"
  : >"$work/calls"
  : >"$work/summary"
  env_vars=(
    PATH="$root/tests/bin:$sysbin" HOME="$work/home"
    FIXTURES="$work/fixtures" CALLS="$work/calls"
    RUNNER_OS=Linux RUNNER_ARCH=X64 RUNNER_ENVIRONMENT=github-hosted
    RUNNER_TEMP="$work/temp" GITHUB_WORKSPACE="$work/workspace"
    GITHUB_SERVER_URL=https://github.com GITHUB_STEP_SUMMARY="$work/summary"
    LOCK_PATH=flake.lock PIN_FORM=true ALLOW_DUPLICATES=
    API_RETRY_DELAY="${API_RETRY_DELAY-}"
  )
}

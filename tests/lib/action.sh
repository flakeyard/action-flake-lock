# shellcheck shell=bash
# A test of a script of the action: a workspace, a fake GitHub-hosted runner
# and a copy of the shell library whose steps run only the tools of that
# runner. Source this file after the harness of the library, consumer/library.sh
# included; it expects root, the repository's directory.
# shellcheck disable=SC2034 # state is used by the suites.
# shellcheck disable=SC2154 # work comes from setup of the library.

: "${root:?}"

# The tools of the runner that the scripts may run, without the nix, gh and
# jq of the host: the scripts must use the tools of the action. The stub of
# date runs the date of the runner at the time that the test fixed.
readonly RUNNER_TOOLS=(bash env cat date grep mkdir mktemp rm realpath wc)
# The time of a test unless it fixes another: no branch of the fixtures is
# near its end of life.
readonly DEFAULT_TIME=2026-06-01T12:00:00Z
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

# The shell library, whose steps get the tools of the runner in $sysbin after
# the stubs of the library, TESTING_BIN.
shell_lib=$shared/shell-lib
copy_library "$shell_lib" "$TESTING_BIN:$sysbin"
readonly shell_lib

# action_setup: setup of the library, with a workspace, the variables of a
# GitHub-hosted runner in a run of a pull request and DEFAULT_TIME. The job
# PATH has the stubs of tests/bin.
action_setup() {
  setup
  # STATE_DIR of lib/env.sh: the files that the steps share.
  state=$work/temp/action-flake-lock
  mkdir -p "$work/workspace" "$work/temp" "$work/home"
  apply PATH="$root/tests/bin:$sysbin" HOME="$work/home" SHELL_LIB="$shell_lib" \
    RUNNER_TEMP="$work/temp" GITHUB_WORKSPACE="$work/workspace" \
    GITHUB_SERVER_URL=https://github.com GITHUB_EVENT_NAME=pull_request \
    LOCK_PATH=flake.lock PIN_FORM=true NIXPKGS_EOL=true NEWER_MAJOR=true ALLOW_DUPLICATES=
  fixed_time "$DEFAULT_TIME"
}

# prepared: the last run only prepared the test that follows; it is not
# counted, but its failure is reported.
prepared() {
  current=""
}

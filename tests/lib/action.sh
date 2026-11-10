# shellcheck shell=bash
# A test of a script of the action: a workspace, a fake GitHub-hosted runner
# and a copy of the shell library whose steps run only the tools of that
# runner. Source this file after the harness of the library; it expects root,
# the repository's directory, and SHELL_LIB, the directory of the library.
# shellcheck disable=SC2034 # state is used by the suites.
# shellcheck disable=SC2154 # work comes from setup of the library.

: "${root:?}"

# The tools of the runner that the scripts may run, without the nix, gh and
# jq of the host: the scripts must use the tools of the action.
readonly RUNNER_TOOLS=(bash env cat grep mkdir mktemp rm realpath wc)
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

# redirect FILE FROM TO: replace FROM with TO in FILE; exits when FILE no
# longer has FROM, since the scripts would then use the host.
redirect() {
  local file=$1 from=$2 to=$3
  grep -qF -- "$from" "$file" || {
    echo "tests: no '$from' in $file to redirect" >&2
    exit 2
  }
  sed -i -e "s|$from|$to|g" "$file"
}

# The shell library of SHELL_LIB, whose steps get the tools of the runner in
# $sysbin after the stubs of the library, TESTING_BIN.
shell_lib=$shared/shell-lib
cp -R -- "${SHELL_LIB:?the tests need SHELL_LIB, the directory of the shell library}" "$shell_lib"
chmod -R u+w -- "$shell_lib"
redirect "$shell_lib/env.sh" "SYSTEM_PATH=/usr/sbin:/usr/bin:/sbin:/bin" \
  "SYSTEM_PATH=$TESTING_BIN:$sysbin"
readonly shell_lib

# action_setup: setup of the library, with a workspace and the variables of a
# GitHub-hosted runner. The job PATH has the stubs of tests/bin.
action_setup() {
  setup
  # STATE_DIR of lib/env.sh: the files that the steps share.
  state=$work/temp/action-flake-lock
  mkdir -p "$work/workspace" "$work/temp" "$work/home"
  apply PATH="$root/tests/bin:$sysbin" HOME="$work/home" SHELL_LIB="$shell_lib" \
    RUNNER_TEMP="$work/temp" GITHUB_WORKSPACE="$work/workspace" \
    GITHUB_SERVER_URL=https://github.com \
    LOCK_PATH=flake.lock PIN_FORM=true ALLOW_DUPLICATES=
}

# prepared: the last run only prepared the test that follows; it is not
# counted, but its failure is reported.
prepared() {
  current=""
}

# shellcheck shell=bash
# The life of one test: its name, its directory with a workspace and a fake
# runner, and the counts of passed and failed tests. Source this file; it
# expects root, the repository's directory, and SHELL_LIB, the directory of
# the shell library.
# shellcheck disable=SC2034 # work, state and env_vars are used by checks.sh

: "${root:?}"
failed=0 passed=0 current="" work=""

# The tools of the runner that the scripts may run, without the nix, gh and
# jq of the host: the scripts must use the tools of the action. sleep is the
# stub of the shell library.
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
# $sysbin after the stubs of the library, which run at once where the scripts
# would wait.
shell_lib=$shared/shell-lib
cp -R -- "${SHELL_LIB:?the tests need SHELL_LIB, the directory of the shell library}" "$shell_lib"
chmod -R u+w -- "$shell_lib"
redirect "$shell_lib/env.sh" "SYSTEM_PATH=/usr/sbin:/usr/bin:/sbin:/bin" \
  "SYSTEM_PATH=$shell_lib/internal/testing/bin:$sysbin"
readonly shell_lib

# setup: a workspace and the variables of a GitHub-hosted runner. The job PATH
# has the stubs of tests/bin.
setup() {
  work=$(mktemp -d)
  # STATE_DIR of lib/env.sh: the files that the steps share.
  state=$work/temp/action-flake-lock
  mkdir -p "$work/workspace" "$work/temp" "$work/home" "$work/fixtures"
  : >"$work/calls"
  : >"$work/sleeps"
  : >"$work/summary"
  env_vars=(
    PATH="$root/tests/bin:$sysbin" HOME="$work/home" SHELL_LIB="$shell_lib"
    FIXTURES="$work/fixtures" CALLS="$work/calls" SLEEPS="$work/sleeps"
    RUNNER_TEMP="$work/temp" GITHUB_WORKSPACE="$work/workspace"
    GITHUB_SERVER_URL=https://github.com GITHUB_STEP_SUMMARY="$work/summary"
    LOCK_PATH=flake.lock PIN_FORM=true ALLOW_DUPLICATES=
  )
}

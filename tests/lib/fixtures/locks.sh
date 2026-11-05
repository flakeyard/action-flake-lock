# shellcheck shell=bash
# Lock files and tools for the steps after step/tools.sh. Source this file
# after case.sh.
# shellcheck disable=SC2154 # work comes from setup.

readonly LOCK_FIXTURES=$root/tests/fixtures/locks

# given_lock CASE [PATH]: the lock file of tests/fixtures/locks/CASE at PATH of
# the workspace, flake.lock by default.
given_lock() {
  local case=$1 path=$work/workspace/${2:-flake.lock}
  mkdir -p "${path%/*}"
  cp "$LOCK_FIXTURES/$case/flake.lock" "$path"
}

# given_tool NAME EXECUTABLE: the step tools recorded a store path whose
# bin/NAME is EXECUTABLE.
given_tool() {
  local name=$1 executable=$2 store=$work/store/$1
  mkdir -p "$store/bin" "$work/temp/action-flake-lock/tools"
  ln -s "$executable" "$store/bin/$name"
  printf '%s\n' "$store" >"$work/temp/action-flake-lock/tools/$name"
}

# given_tools: the step tools built the jq of the host and the gh stub.
given_tools() {
  given_tool jq "$HOST_JQ"
  given_tool gh "$root/tests/bin/gh"
}

# parsed FILTER: prints FILTER of what step/parse.sh wrote, as text.
parsed() {
  local filter=$1
  jq -r "$filter" "$work/temp/action-flake-lock/lock.json"
}

# expect_parsed NAME FILTER EXPECTED: FILTER of what step/parse.sh wrote is
# EXPECTED, as text.
expect_parsed() {
  local actual
  [[ -n $current ]] || return 0
  actual=$(parsed "$2")
  [[ $actual == "$3" ]] || report "$1: '$actual', expected '$3'"
}

# findings RULE: prints the messages of the findings of RULE, one per line.
findings() {
  local rule=$1
  jq -r '.[].message' "$work/temp/action-flake-lock/findings/$rule.json"
}

# expect_finding RULE MESSAGE: RULE found a violation whose message is MESSAGE.
expect_finding() {
  local rule=$1 message=$2
  [[ -z $current ]] || findings "$rule" | grep -qxF -- "$message" \
    || report "no $rule finding '$message' in: $(findings "$rule")"
}

# expect_findings RULE COUNT: RULE found COUNT violations.
expect_findings() {
  local rule=$1 count=$2 actual
  [[ -n $current ]] || return 0
  actual=$(findings "$rule" | wc -l)
  ((actual == count)) || report "$actual $rule findings, expected $count: $(findings "$rule")"
}

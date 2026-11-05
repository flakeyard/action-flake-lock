# shellcheck shell=bash
# The life of one test: its name and the counts of passed and failed tests.
# Source this file.

failed=0 passed=0 current=""

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

# finish: count the current test as passed unless it failed.
finish() {
  if [[ -n $current ]]; then passed=$((passed + 1)); fi
  current=""
}

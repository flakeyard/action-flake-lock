# shellcheck shell=bash
# Runs of a script of the action, and checks of what it did. Source this file
# after case.sh.
# shellcheck disable=SC2154 # work and env_vars come from setup.

# outcome NAME EXPECTED STATUS: start test NAME, which exited with STATUS;
# EXPECTED is ok or fail.
outcome() {
  local name=$1 expected=$2 status=$3
  current=$name
  if [[ $expected == fail && $status -eq 0 ]] || [[ $expected == ok && $status -ne 0 ]]; then
    report "expected $expected, exit status $status: $(cat "$work/stdout" "$work/stderr")"
  fi
}

# run NAME EXPECTED SCRIPT [VAR=VALUE...] [-- ARG...]: run a script of the
# action, such as step/check.sh, with only the variables of the test runner
# and VAR; EXPECTED is ok or fail.
run() {
  local name=$1 expected=$2 script=$3 status=0 vars=() args=()
  shift 3
  while (($#)) && [[ $1 != -- ]]; do
    vars+=("$1")
    shift
  done
  (($#)) && shift && args=("$@")
  env -i "${env_vars[@]}" "${vars[@]}" "$root/scripts/$script" "${args[@]}" \
    >"$work/stdout" 2>"$work/stderr" || status=$?
  outcome "$name" "$expected" "$status"
}

# run_lib NAME EXPECTED LIBS FUNCTION [ARG...]: run a function of the helpers
# LIBS of the action, such as "env.sh tools.sh", in a subshell with the
# variables of the test runner; EXPECTED is ok or fail.
run_lib() {
  local name=$1 expected=$2 libs=$3 status=0 lib
  shift 3
  (
    export "${env_vars[@]}"
    for lib in $libs; do
      # shellcheck source=/dev/null
      source "$root/scripts/lib/$lib"
    done
    "$@"
  ) >"$work/stdout" 2>"$work/stderr" || status=$?
  outcome "$name" "$expected" "$status"
}

# prepared: the last run only prepared the test that follows; it is not
# counted, but its failure is reported.
prepared() {
  current=""
}

# expect KIND [VALUE...]: check the last run.
expect() {
  [[ -n $current ]] || return 0
  case $1 in
    message) grep -qF -- "$2" "$work/stdout" "$work/stderr" || report "no message '$2' in: $(cat "$work/stdout" "$work/stderr")" ;;
    no-message) ! grep -qF -- "$2" "$work/stdout" "$work/stderr" || report "unexpected message '$2'" ;;
    stdout) [[ $(<"$work/stdout") == "$2" ]] || report "stdout is '$(<"$work/stdout")', expected '$2'" ;;
    errors)
      local count
      count=$(grep -c '^::error' "$work/stdout")
      [[ $count == "$2" ]] || report "$count errors, expected $2: $(cat "$work/stdout")"
      ;;
    call) grep -qF -- "$2" "$work/calls" || report "no call '$2' in: $(paste -sd';' "$work/calls")" ;;
    no-calls) [[ ! -s $work/calls ]] || report "unexpected calls: $(paste -sd';' "$work/calls")" ;;
    summary) grep -qF -- "$2" "$work/summary" || report "no '$2' in the summary: $(cat "$work/summary")" ;;
  esac
}

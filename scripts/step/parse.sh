#!/usr/bin/env bash
# Parses the lock file with the jq of the action into what the rules read: the
# inputs of the root and every node it reaches, with their sources, in
# $STATE_DIR/lock.json. Fails on a lock file that is missing, is not JSON or
# has a version other than 5, 6 and 7. The text of the lock reaches jq only as
# data, never as a program.
#
# Inputs (environment): LOCK_PATH.
set -euo pipefail
# Builtins only until lib/env.sh replaces PATH, which is the job's.
lib=${BASH_SOURCE[0]%/*}/../lib
# shellcheck source-path=SCRIPTDIR source=../lib/env.sh
source "$lib/env.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/report.sh
source "$lib/report.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/forms.sh
source "$lib/forms.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/tools.sh
source "$lib/tools.sh"

readonly LOCK_MODULES=$ACTION_DIR/scripts/lock
readonly PARSED=$STATE_DIR/lock.json
# The programs of jq, over the documents of the lock file as $lock.
# shellcheck disable=SC2016 # variables of jq
readonly PROBLEM_PROGRAM='include "nodes"; problem($lock)'
# shellcheck disable=SC2016 # variables of jq
readonly PARSE_PROGRAM='include "nodes"; include "sources"; parsed($lock[0]) | with_sources'

# lock_jq LOCK PROGRAM: runs PROGRAM with the jq of the action and the modules
# of scripts/lock, on the documents of the file LOCK as $lock; strings are
# printed as text.
lock_jq() {
  local lock=$1 program=$2
  "$jq" -rn -L "$LOCK_MODULES" --slurpfile lock "$lock" "$program"
}

# check_lock LOCK: fails unless LOCK is one lock file of a supported version.
check_lock() {
  local lock=$1 problem
  problem=$(lock_jq "$lock" "$PROBLEM_PROGRAM" 2>/dev/null) \
    || fail "The lock file $LOCK_PATH is not valid JSON."
  [[ -z $problem ]] || fail "The lock file $LOCK_PATH $problem."
}

main() {
  local reason lock
  # The jq of the action, for lock_jq.
  jq=$(tool jq) || fail "The tools step did not build jq."
  reason=$(lock_problem "$LOCK_PATH")
  [[ -z $reason ]] || fail "$reason"
  lock=$(lock_file "$LOCK_PATH")
  check_lock "$lock"
  lock_jq "$lock" "$PARSE_PROGRAM" >"$PARSED"
}

main "$@"

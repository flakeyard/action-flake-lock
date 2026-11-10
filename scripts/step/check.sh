#!/usr/bin/env bash
# Checks the server and the inputs before anything is built, and reports every
# problem at once. The step of the shell library before it rejects runners
# other than GitHub-hosted Linux on X64 and ARM64.
#
# Inputs (environment): LOCK_PATH, ALLOW_DUPLICATES, PIN_FORM, NIXPKGS_EOL.
set -euo pipefail
# Builtins only until lib/env.sh replaces PATH, which is the job's.
lib=${BASH_SOURCE[0]%/*}/../lib
# shellcheck source-path=SCRIPTDIR source=../lib/env.sh
source "$lib/env.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/forms.sh
source "$lib/forms.sh"

# The only server: GitHub Enterprise Server is not supported (ADR-0001).
readonly GITHUB_COM=https://github.com

check_server() {
  [[ ${GITHUB_SERVER_URL-} == "$GITHUB_COM" ]] \
    || problem "Only $GITHUB_COM is supported, not '${GITHUB_SERVER_URL-}'."
}

check_path() {
  local reason
  reason=$(lock_problem "${LOCK_PATH-}")
  [[ -z $reason ]] || problem "$reason"
}

check_allow_duplicates() {
  local source
  while IFS= read -r source; do
    [[ $source =~ $SOURCE_FORM ]] \
      || problem "Invalid source '$source' in allow-duplicates: expected github.com/<owner>/<repo> in lower case, with an optional ?dir=<dir>."
  done < <(items "${ALLOW_DUPLICATES-}")
}

# check_boolean INPUT VALUE: VALUE of the input INPUT is true or false.
check_boolean() {
  local input=$1 value=$2
  [[ $value =~ $BOOLEAN_FORM ]] || problem "$input must be true or false, not '$value'."
}

main() {
  check_server
  check_path
  check_allow_duplicates
  check_boolean pin-form "${PIN_FORM-}"
  check_boolean nixpkgs-eol "${NIXPKGS_EOL-}"
  if has_problems; then
    flush
    exit 1
  fi
}

main "$@"

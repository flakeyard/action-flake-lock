#!/usr/bin/env bash
# Checks the runner and the inputs before anything is built, and reports every
# problem at once.
#
# Inputs (environment): LOCK_PATH, ALLOW_DUPLICATES, PIN_FORM.
set -euo pipefail
# Builtins only until lib/env.sh replaces PATH, which is the job's.
lib=${BASH_SOURCE[0]%/*}/../lib
# shellcheck source-path=SCRIPTDIR source=../lib/env.sh
source "$lib/env.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/report.sh
source "$lib/report.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/forms.sh
source "$lib/forms.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/runner.sh
source "$lib/runner.sh"

# The architectures of the GitHub-hosted Linux runners that the action
# supports, as RUNNER_ARCH names them.
readonly ARCH_FORM='^(X64|ARM64)$'
# The only server: GitHub Enterprise Server is not supported (ADR-0001).
readonly GITHUB_COM=https://github.com

failed=false
problem() {
  error "$1"
  failed=true
}

# is_supported_runner: a Linux runner on X64 or ARM64.
is_supported_runner() {
  [[ ${RUNNER_OS-} == Linux && ${RUNNER_ARCH-} =~ $ARCH_FORM ]]
}

check_runner() {
  is_supported_runner \
    || problem "$(unsupported_runner "${RUNNER_OS-?}/${RUNNER_ARCH-?}")"
  [[ ${RUNNER_ENVIRONMENT-} == github-hosted ]] \
    || problem "Only GitHub-hosted runners are supported, not '${RUNNER_ENVIRONMENT-}'."
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

check_pin_form() {
  [[ ${PIN_FORM-} =~ $BOOLEAN_FORM ]] \
    || problem "pin-form must be true or false, not '${PIN_FORM-}'."
}

main() {
  check_runner
  check_path
  check_allow_duplicates
  check_pin_form
  if $failed; then
    flush_errors
    exit 1
  fi
}

main "$@"

#!/usr/bin/env bash
# Unit tests of the scripts of this repository, with the harness and the stubs
# of gh, date and sleep of the shell library in SHELL_LIB, and stubs of nix and
# of the gh of the action in tests/bin. tests/unit mirrors scripts/: one suite
# per script or helper, and static tests of action.yml, which need yq.
# Usage: SHELL_LIB=<shell library> tests/run.sh
# shellcheck source-path=SCRIPTDIR
set -uo pipefail
shopt -s globstar
export LC_ALL=C

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC2034 # read by the checks of the library
code_root=$root
testing=${SHELL_LIB:?the tests need SHELL_LIB, the directory of the shell library}/internal/testing
# shellcheck source=/dev/null
source "$testing/case.sh"
# shellcheck source=/dev/null
source "$testing/checks.sh"
# shellcheck source=/dev/null
source "$testing/fixtures.sh"
# shellcheck source=/dev/null
source "$testing/yaml.sh"
# shellcheck source=/dev/null
source "$testing/consumer/library.sh"
# shellcheck source=/dev/null
source "$testing/consumer/action.sh"
# shellcheck source=lib/action.sh
source "$root/tests/lib/action.sh"
# shellcheck source=lib/fixtures/locks.sh
source "$root/tests/lib/fixtures/locks.sh"
# shellcheck source=lib/fixtures/responses.sh
source "$root/tests/lib/fixtures/responses.sh"

for suite in "$root"/tests/unit/**/*.sh; do
  # shellcheck source=/dev/null
  source "$suite"
done

conclude

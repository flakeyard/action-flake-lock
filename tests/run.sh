#!/usr/bin/env bash
# Unit tests of the scripts of this repository, with stubs of nix and gh in
# tests/bin. tests/unit mirrors scripts/: one suite per script or helper.
# Usage: tests/run.sh
# shellcheck source-path=SCRIPTDIR
set -uo pipefail
shopt -s globstar
export LC_ALL=C

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/case.sh
source "$root/tests/lib/case.sh"
# shellcheck source=lib/checks.sh
source "$root/tests/lib/checks.sh"
# shellcheck source=lib/fixtures/locks.sh
source "$root/tests/lib/fixtures/locks.sh"
# shellcheck source=lib/fixtures/responses.sh
source "$root/tests/lib/fixtures/responses.sh"

for suite in "$root"/tests/unit/**/*.sh; do
  # shellcheck source=/dev/null
  source "$suite"
done

echo "passed: $passed, failed: $failed"
((failed == 0))

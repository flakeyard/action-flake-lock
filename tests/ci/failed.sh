#!/usr/bin/env bash
# Fails unless the step before, the action on a lock that breaks every rule,
# failed.
# Usage: OUTCOME=<outcome of the step> tests/ci/failed.sh
set -euo pipefail

if [[ ${OUTCOME:?} != failure ]]; then
  echo "::error::The action passed a lock that breaks every rule: outcome $OUTCOME."
  exit 1
fi

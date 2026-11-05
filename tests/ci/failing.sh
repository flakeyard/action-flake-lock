#!/usr/bin/env bash
# Runs the steps of the action as action.yml does, on a real runner with the
# API, on a lock that breaks every rule: the report fails with one annotation
# per rule, and the release rule names the newest release.
# Usage: TOKEN=<token> tests/ci/failing.sh (from the root of the repository)
set -euo pipefail
shopt -s inherit_errexit

readonly LOCK=tests/fixtures/locks/ci-fail/flake.lock
readonly UNRELEASED=2b7fe64766cbe87f2cd3e614b16c1c3766d3d934
readonly EXPECTED=(
  "title=Duplicated source%3A github.com/nixos/nixpkgs::github.com/nixos/nixpkgs is locked 2 times"
  "title=Pin form%3A inputs.utils::inputs.utils is not pinned"
  "title=Release%3A inputs.setup::inputs.setup of flakeyard/action-setup-nix: its rev $UNRELEASED is not the commit of an immutable release v0.Y.Z. The newest release of v0 is v0."
)

# step NAME: runs the step NAME of the action on LOCK.
step() {
  local name=$1
  LOCK_PATH=$LOCK ALLOW_DUPLICATES="" PIN_FORM=true \
    /usr/bin/bash -p scripts/run-step.sh "$name"
}

# run_steps: prints what the steps printed; fails unless only the report
# failed.
run_steps() {
  local name
  for name in check tools parse releases; do
    step "$name"
  done
  ! step report
}

# shown OUTPUT: OUTPUT without workflow commands, for the log.
shown() {
  local output=$1
  grep -v '^::add-mask::' <<<"$output" | sed 's/^::/: :/'
}

output=$(run_steps) || {
  echo "::error::The steps did not fail in the report only."
  shown "$output"
  exit 1
}
status=0
for annotation in "${EXPECTED[@]}"; do
  if ! grep -qF -- "$annotation" <<<"$output"; then
    echo "::error::No annotation '$annotation'."
    status=1
  fi
done
shown "$output"
exit "$status"

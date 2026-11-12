#!/usr/bin/env bash
# Runs the steps of the action with the run lines of action.yml, on a real
# runner with the API, on a lock that breaks every rule: the report fails with
# one annotation per rule, and the release rule names the newest release.
# Needs mikefarah yq, which GitHub-hosted runners have.
# Usage: SHELL_LIB=<shell library> TOKEN=<token> tests/ci/failing.sh (from the
# root of the repository)
set -euo pipefail
shopt -s inherit_errexit

readonly LOCK=tests/fixtures/locks/ci-fail/flake.lock
readonly UNRELEASED=2b7fe64766cbe87f2cd3e614b16c1c3766d3d934
readonly EXPECTED=(
  "title=Duplicated source%3A github.com/nixos/nixpkgs::github.com/nixos/nixpkgs is locked 2 times"
  "title=Pin form%3A inputs.utils::inputs.utils is not pinned"
  "title=Release%3A inputs.setup::inputs.setup of flakeyard/action-setup-nix: its rev $UNRELEASED is not the commit of an immutable release v0.Y.Z. The newest release of v0 is v0."
)

# The inputs of the steps, as action.yml gives them, and its directory.
export SHELL_LIB=${SHELL_LIB:?} TOKEN=${TOKEN:?} LOCK_PATH=$LOCK ALLOW_DUPLICATES="" PIN_FORM=true \
  NIXPKGS_EOL=true NEWER_MAJOR=true GITHUB_ACTION_PATH=$PWD

# run_lines: prints the run line of each step of action.yml that has one.
run_lines() {
  yq -r '.runs.steps[] | select(has("run")) | .run' action.yml
}

# run_steps: prints what the steps printed; fails unless only the last one,
# the report, failed. It runs in a condition, where set -e is off.
run_steps() {
  local lines line
  mapfile -t lines < <(run_lines)
  ((${#lines[@]} > 1)) || return 1
  for line in "${lines[@]:0:${#lines[@]}-1}"; do
    eval "$line" || return 1
  done
  ! eval "${lines[-1]}"
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

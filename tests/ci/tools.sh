#!/usr/bin/env bash
# Builds every package of the root flake as the action does, on a real
# runner: each must yield exactly one store path whose tool runs. Prints how
# long each build took, which ADR-0001 left to measure.
# Usage: tests/ci/tools.sh (from the root of the repository)
set -euo pipefail
shopt -s inherit_errexit

readonly PACKAGES=(jq gh)

# build PACKAGE: prints the store paths of PACKAGE of the root flake.
build() {
  local package=$1
  nix build --no-link --print-out-paths --no-update-lock-file "path:.#$package"
}

# check_package PACKAGE: PACKAGE builds to one path, and its tool runs.
check_package() {
  local package=$1 paths started=$SECONDS
  paths=$(build "$package")
  if [[ -z $paths || $paths == *$'\n'* ]]; then
    echo "::error::$package built to $(wc -l <<<"$paths") paths, expected one: ${paths//$'\n'/ }"
    return 1
  fi
  "$paths/bin/$package" --version
  echo "::notice::$package: $paths, built in $((SECONDS - started)) s"
}

for package in "${PACKAGES[@]}"; do
  check_package "$package"
done

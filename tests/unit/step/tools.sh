# shellcheck shell=bash
# Tests of scripts/step/tools.sh and scripts/lib/tools.sh, with the nix stub.
# shellcheck disable=SC2154 # work and state come from setup.

# fake_package NAME [PATH...]: the nix stub builds the package NAME to PATH,
# by default one store path with an executable bin/NAME.
fake_package() {
  local name=$1 path
  shift
  (($#)) || set -- "$work/store/$name"
  for path; do
    mkdir -p "$path/bin"
    printf '#!/bin/sh\n' >"$path/bin/$name"
    chmod +x "$path/bin/$name"
    printf '%s\n' "$path" >>"$work/fixtures/nix-$name"
  done
}

# expect_recorded NAME PATH: the step recorded PATH as the store path of NAME.
expect_recorded() {
  local name=$1 path=$2 file=$state/tools/$1
  [[ -z $current ]] || [[ -f $file && $(<"$file") == "$path" ]] \
    || report "recorded for $name: '$(cat "$file" 2>/dev/null)', expected '$path'"
}

action_setup
fake_package jq
fake_package gh
run "tools: builds jq and gh from the flake of the action" ok scripts/step/tools.sh
expect call "nix build --no-link --print-out-paths --no-update-lock-file path:$root#jq"
expect call "nix build --no-link --print-out-paths --no-update-lock-file path:$root#gh"
expect_recorded jq "$work/store/jq"
expect_recorded gh "$work/store/gh"
finish

action_setup
fake_package jq "$work/store/jq-bin" "$work/store/jq-man"
fake_package gh
run "tools: a package with two outputs fails" fail scripts/step/tools.sh
expect message "nix build of jq printed '$work/store/jq-bin $work/store/jq-man', expected one store path."
finish

action_setup
fake_package gh
run "tools: a failed build fails" fail scripts/step/tools.sh
expect message "Cannot build jq from the flake of the action."
finish

action_setup
run "tools: no nix on the PATH of the job" fail scripts/step/tools.sh PATH="$sysbin"
expect message "No nix on PATH"
expect no-calls
finish

action_setup
mkdir -p "$state"
touch "$state/lock.json"
fake_package jq
fake_package gh
run "tools: starts the files of the steps afresh" ok scripts/step/tools.sh
[[ -z $current || ! -e $state/lock.json ]] || report "lock.json of an earlier run is left"
finish

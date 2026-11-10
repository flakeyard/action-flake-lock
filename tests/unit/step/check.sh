# shellcheck shell=bash
# Tests of scripts/step/check.sh.
# shellcheck disable=SC2154 # work comes from setup.

# lock_fixture [PATH]: an empty lock file at PATH of the workspace, flake.lock
# by default.
lock_fixture() {
  local path=$work/workspace/${1:-flake.lock}
  mkdir -p "${path%/*}"
  echo '{}' >"$path"
}

# --- server -------------------------------------------------------

action_setup
lock_fixture
run "check: github.com" ok scripts/step/check.sh
expect errors 0
finish

action_setup
lock_fixture
run "check: rejects GitHub Enterprise Server" fail scripts/step/check.sh GITHUB_SERVER_URL=https://ghes.example.com
expect message "Only https://github.com is supported, not 'https://ghes.example.com'"
finish

# --- path ---------------------------------------------------------

action_setup
lock_fixture sub/dir/flake.lock
run "check: a lock file below the workspace" ok scripts/step/check.sh LOCK_PATH=sub/dir/flake.lock
finish

action_setup
run "check: a missing lock file" fail scripts/step/check.sh
expect message "No lock file at flake.lock."
finish

action_setup
lock_fixture
run "check: an absolute path" fail scripts/step/check.sh LOCK_PATH="$work/workspace/flake.lock"
expect message "path must be relative to the workspace"
finish

action_setup
lock_fixture
run "check: an empty path" fail scripts/step/check.sh LOCK_PATH=
expect message "path must be relative to the workspace, not ''"
finish

action_setup
echo '{}' >"$work/outside.lock"
run "check: a path out of the workspace" fail scripts/step/check.sh LOCK_PATH=../outside.lock
expect message "The lock file ../outside.lock is outside the workspace."
finish

action_setup
echo '{}' >"$work/outside.lock"
ln -s ../outside.lock "$work/workspace/flake.lock"
run "check: a link out of the workspace" fail scripts/step/check.sh
expect message "The lock file flake.lock is outside the workspace."
finish

action_setup
lock_fixture real.lock
ln -s real.lock "$work/workspace/flake.lock"
run "check: a link inside the workspace" ok scripts/step/check.sh
finish

action_setup
mkdir "$work/workspace/flake.lock"
run "check: a directory" fail scripts/step/check.sh
expect message "The lock file flake.lock is not a regular file."
finish

action_setup
mkfifo "$work/workspace/flake.lock"
run "check: a named pipe" fail scripts/step/check.sh
expect message "The lock file flake.lock is not a regular file."
finish

# --- allow-duplicates and pin-form --------------------------------

action_setup
lock_fixture
run "check: sources of allow-duplicates, one per line" ok scripts/step/check.sh \
  ALLOW_DUPLICATES=$'\n  github.com/nixos/nixpkgs\n\ngithub.com/o/r.s?dir=a/b-c_d \n'
expect errors 0
finish

for source in github.com/NixOS/nixpkgs gitlab.com/o/r github.com/o "github.com/o/r x" \
  "github.com/o/r?ref=main" "https://github.com/o/r" "github.com/o/r?dir=a b"; do
  action_setup
  lock_fixture
  run "check: rejects '$source' in allow-duplicates" fail scripts/step/check.sh ALLOW_DUPLICATES="$source"
  expect message "Invalid source"
  finish
done

for value in false true; do
  action_setup
  lock_fixture
  run "check: pin-form $value" ok scripts/step/check.sh PIN_FORM="$value"
  finish
done

for value in "" yes True; do
  action_setup
  lock_fixture
  run "check: rejects pin-form '$value'" fail scripts/step/check.sh PIN_FORM="$value"
  expect message "pin-form must be true or false, not '$value'."
  finish
done

# --- untrusted text and every problem -----------------------------

action_setup
lock_fixture
run "check: an input cannot start a workflow command" fail scripts/step/check.sh \
  PIN_FORM=$'x\n::warning::forged\r'
expect message "not 'x%0A::warning::forged%0D'"
[[ -z $current ]] || ! grep -q '^::warning::' "$work/stdout" || report "a workflow command was started"
finish

action_setup
run "check: reports every problem at once" fail scripts/step/check.sh \
  GITHUB_SERVER_URL=https://ghes.example.com ALLOW_DUPLICATES=x PIN_FORM=no
expect errors 4
finish

# twelve_sources: twelve sources of allow-duplicates that are not normalized.
twelve_sources() {
  local i
  for i in {1..12}; do printf 'github.com/O/r%s\n' "$i"; done
}

action_setup
lock_fixture
run "check: at most 10 errors, the last says how many more" fail scripts/step/check.sh \
  ALLOW_DUPLICATES="$(twelve_sources)"
expect errors 10
expect message "Invalid source 'github.com/O/r9'"
expect no-message "'github.com/O/r10'"
expect message "::error::3 more errors are not shown here."
finish

action_setup
lock_fixture
run "check: ten errors are all shown" fail scripts/step/check.sh \
  ALLOW_DUPLICATES="$(twelve_sources | head -10)"
expect errors 10
expect message "Invalid source 'github.com/O/r10'"
expect no-message "more errors"
finish

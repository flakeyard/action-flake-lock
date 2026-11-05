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

# --- runner -------------------------------------------------------

setup
lock_fixture
run "check: a GitHub-hosted x86_64 Linux runner" ok step/check.sh
expect errors 0
finish

setup
lock_fixture
run "check: arm64" ok step/check.sh RUNNER_ARCH=ARM64
finish

for runner in macOS/ARM64 Windows/X64 Linux/X86 Linux/ARM; do
  setup
  lock_fixture
  run "check: rejects $runner" fail step/check.sh RUNNER_OS="${runner%/*}" RUNNER_ARCH="${runner#*/}"
  expect message "::error::Unsupported runner $runner"
  finish
done

setup
lock_fixture
run "check: rejects a self-hosted runner" fail step/check.sh RUNNER_ENVIRONMENT=self-hosted
expect message "Only GitHub-hosted runners are supported, not 'self-hosted'"
finish

setup
lock_fixture
run "check: rejects GitHub Enterprise Server" fail step/check.sh GITHUB_SERVER_URL=https://ghes.example.com
expect message "Only https://github.com is supported, not 'https://ghes.example.com'"
finish

# --- path ---------------------------------------------------------

setup
lock_fixture sub/dir/flake.lock
run "check: a lock file below the workspace" ok step/check.sh LOCK_PATH=sub/dir/flake.lock
finish

setup
run "check: a missing lock file" fail step/check.sh
expect message "No lock file at flake.lock."
finish

setup
lock_fixture
run "check: an absolute path" fail step/check.sh LOCK_PATH="$work/workspace/flake.lock"
expect message "path must be relative to the workspace"
finish

setup
lock_fixture
run "check: an empty path" fail step/check.sh LOCK_PATH=
expect message "path must be relative to the workspace, not ''"
finish

setup
echo '{}' >"$work/outside.lock"
run "check: a path out of the workspace" fail step/check.sh LOCK_PATH=../outside.lock
expect message "The lock file ../outside.lock is outside the workspace."
finish

setup
echo '{}' >"$work/outside.lock"
ln -s ../outside.lock "$work/workspace/flake.lock"
run "check: a link out of the workspace" fail step/check.sh
expect message "The lock file flake.lock is outside the workspace."
finish

setup
lock_fixture real.lock
ln -s real.lock "$work/workspace/flake.lock"
run "check: a link inside the workspace" ok step/check.sh
finish

setup
mkdir "$work/workspace/flake.lock"
run "check: a directory" fail step/check.sh
expect message "The lock file flake.lock is not a regular file."
finish

setup
mkfifo "$work/workspace/flake.lock"
run "check: a named pipe" fail step/check.sh
expect message "The lock file flake.lock is not a regular file."
finish

# --- allow-duplicates and pin-form --------------------------------

setup
lock_fixture
run "check: sources of allow-duplicates, one per line" ok step/check.sh \
  ALLOW_DUPLICATES=$'\n  github.com/nixos/nixpkgs\n\ngithub.com/o/r.s?dir=a/b-c_d \n'
expect errors 0
finish

for source in github.com/NixOS/nixpkgs gitlab.com/o/r github.com/o "github.com/o/r x" \
  "github.com/o/r?ref=main" "https://github.com/o/r" "github.com/o/r?dir=a b"; do
  setup
  lock_fixture
  run "check: rejects '$source' in allow-duplicates" fail step/check.sh ALLOW_DUPLICATES="$source"
  expect message "Invalid source"
  finish
done

for value in false true; do
  setup
  lock_fixture
  run "check: pin-form $value" ok step/check.sh PIN_FORM="$value"
  finish
done

for value in "" yes True; do
  setup
  lock_fixture
  run "check: rejects pin-form '$value'" fail step/check.sh PIN_FORM="$value"
  expect message "pin-form must be true or false, not '$value'."
  finish
done

# --- untrusted text and every problem -----------------------------

setup
lock_fixture
run "check: an input cannot start a workflow command" fail step/check.sh \
  PIN_FORM=$'x\n::warning::forged\r'
expect message "not 'x%0A::warning::forged%0D'"
[[ -z $current ]] || ! grep -q '^::warning::' "$work/stdout" || report "a workflow command was started"
finish

setup
run "check: reports every problem at once" fail step/check.sh \
  RUNNER_ENVIRONMENT=self-hosted ALLOW_DUPLICATES=x PIN_FORM=no
expect errors 4
finish

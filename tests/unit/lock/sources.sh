# shellcheck shell=bash
# Tests of scripts/lock/sources.jq, through step/parse.sh.

action_setup
given_tools
given_lock sources
run "sources: parse the sources fixture" ok scripts/step/parse.sh
while read -r name source; do
  expect_parsed "source of $name" ".nodes[] | select(.name == \"$name\") | .source.id // \"skipped\"" "$source"
done <<'CASES'
github github.com/nixos/nixpkgs
git-https github.com/nixos/nixpkgs
git-ssh github.com/flakeyard/atom-shell
tarball github.com/numtide/flake-utils
dir github.com/o/r?dir=sub/dir
gitlab skipped
sourcehut skipped
codeload skipped
enterprise skipped
path skipped
file skipped
CASES
finish

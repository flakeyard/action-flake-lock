# shellcheck shell=bash
# Tests of scripts/step/parse.sh and scripts/lock/nodes.jq.
# shellcheck disable=SC2154 # work comes from setup.

# Each node with its path, and the root inputs with their nodes.
readonly NODE_PATHS='[.nodes[] | "\(.name)=\(.path | join("."))"] | join(" ")'
readonly ROOT_INPUTS='[.inputs[] | "\(.name)=\(.target)"] | join(" ")'

for version in 5 6 7; do
  setup
  given_tools
  given_lock "version-$version"
  run "parse: reads a lock of version $version" ok step/parse.sh
  expect_parsed "nodes" "$NODE_PATHS" "nixpkgs=nixpkgs"
  expect_parsed "version" .version "$version"
  finish
done

for version in 4 8; do
  setup
  given_tools
  given_lock "version-$version"
  run "parse: fails on a lock of version $version" fail step/parse.sh
  expect message "The lock file flake.lock has version $version; the action reads versions 5, 6, 7."
  finish
done

while IFS='|' read -r case message; do
  setup
  given_tools
  given_lock "$case"
  run "parse: fails on $case" fail step/parse.sh
  expect message "$message"
  finish
done <<'CASES'
not-json|The lock file flake.lock is not valid JSON.
two-documents|The lock file flake.lock is not one JSON document.
not-a-lock|The lock file flake.lock is not a lock file of Nix.
CASES

setup
given_tools
run "parse: fails on a missing lock file" fail step/parse.sh
expect message "No lock file at flake.lock."
finish

setup
given_tools
given_lock version-7 ../outside.lock
run "parse: reads no lock out of the workspace" fail step/parse.sh LOCK_PATH=../outside.lock
expect message "is outside the workspace"
finish

setup
given_lock version-7
run "parse: needs the jq of the action" fail step/parse.sh
expect message "The tools step did not build jq."
finish

# --- follows ------------------------------------------------------

setup
given_tools
given_lock follows
run "parse: a cyclic follows ends" ok step/parse.sh
expect_parsed "nodes" "$NODE_PATHS" "a=a b=b x=a.x"
expect_parsed "root inputs" "$ROOT_INPUTS" "a=a b=b c=x d=null e=null"
expect_parsed "parents" '[.nodes[] | .parent] | map(. // "root") | join(" ")' "root root a"
finish

# --- the text of the lock is data --------------------------------

setup
given_tools
given_lock version-7
sed -i 's/"nixpkgs"/"a\\") | halt_error(\\"x"/g' "$work/workspace/flake.lock"
run "parse: names of the lock are not code" ok step/parse.sh
expect_parsed "nodes" '.nodes[].name' 'a") | halt_error("x'
finish

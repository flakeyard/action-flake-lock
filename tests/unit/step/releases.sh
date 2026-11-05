# shellcheck shell=bash
# Tests of scripts/step/releases.sh and scripts/lock/releases.jq.
# shellcheck disable=SC2154 # work comes from setup.

readonly TOKEN=ghs_abcDEF123
c() { printf "$1%.0s" {1..40}; }

# releases_setup: the parsed releases fixture and the releases of the API:
# atom-a on two pages with a mutable and a draft release, atom-b after one
# gateway timeout, atom-c with a mutable release only; atom-gone does not
# exist.
releases_setup() {
  setup
  given_tools
  given_lock releases
  run "releases: parse the fixture" ok step/parse.sh
  prepared
  releases_of atom-a "v1.0.0=$(c 0)" "v1.1.0=$(c 1)" "v2.0.0=$(c 2)" \
    "v1.2.0=$(c 3):mutable" "v1.3.0=$(c 4):draft" "v1=$(c 5)" "nightly=$(c 6)"
  release_page atom-a 2 "v0.9.0=$(c 9)"
  releases_of atom-b "v1.0.0=$(c b)"
  transient_failures atom-b 1
  releases_of atom-c "v1.0.0=$(c c):mutable"
}

releases_setup
run "releases: every flakeyard input" ok step/releases.sh TOKEN="$TOKEN"
expect message "::add-mask::$TOKEN"
expect_findings release 8
while IFS='|' read -r input message; do
  expect_finding release "inputs.$input of flakeyard/$message"
done <<CASES
wrong-exact|atom-a: its ref v1.0.0 is not the tag of a release of its rev, v1.1.0. The newest release of v1 is v1.1.0 at $(c 1).
unreleased|atom-a: its rev $(c d) is not the commit of an immutable release v1.Y.Z. The newest release of v1 is v1.1.0 at $(c 1).
mutable|atom-a: its rev $(c 3) is not the commit of an immutable release v1.Y.Z. The newest release of v1 is v1.1.0 at $(c 1).
draft|atom-a: its rev $(c 4) is not the commit of an immutable release v1.Y.Z. The newest release of v1 is v1.1.0 at $(c 1).
other-major|atom-a: its rev $(c 1) is not the commit of an immutable release v2.Y.Z. The newest release of v2 is v2.0.0 at $(c 2).
bad-ref|atom-a: its ref main is neither vX nor vX.Y.Z. The newest release is v2.0.0 at $(c 2).
only-mutable|atom-c: its rev $(c c) is not the commit of an immutable release v1.Y.Z. There is no immutable release v1.Y.Z.
CASES
expect_finding release "Could not verify inputs.gone, flakeyard/atom-gone: the GitHub API failed, see the log."
finish

releases_setup
run "releases: one lookup per repository, for github.com only" ok step/releases.sh \
  TOKEN="$TOKEN" GH_REPO=o/r GH_ENTERPRISE_TOKEN=x GH_CONFIG_DIR=/x
for repo in atom-a atom-c atom-gone; do
  [[ -z $current ]] || (($(grep -c "name=$repo " "$work/calls") == 1)) || report "not one lookup of $repo"
done
# atom-b once more, after its gateway timeout.
[[ -z $current ]] || (($(grep -c "name=atom-b " "$work/calls") == 2)) || report "not two lookups of atom-b"
expect call "GH_HOST=github.com GH_TOKEN=$TOKEN GH_REPO= GH_ENTERPRISE_TOKEN= GH_CONFIG_DIR="
[[ -z $current ]] || ! grep -q "name=utils" "$work/calls" || report "a third-party repository was looked up"
finish

for token in "" "ghs abc" $'ghs_abc\n::warning::x'; do
  releases_setup
  run "releases: rejects the token '$token'" fail step/releases.sh TOKEN="$token"
  expect message "Invalid github-token"
  expect no-message "::add-mask::"
  expect no-calls
  finish
done

releases_setup
printf 'HTTP 500\n' >"$(release_file atom-a)"
run "releases: a server error is an input that could not be verified" ok step/releases.sh TOKEN="$TOKEN"
expect_finding release "Could not verify inputs.good, flakeyard/atom-a: the GitHub API failed, see the log."
[[ -z $current ]] || (($(grep -c "name=atom-a " "$work/calls") == 3)) || report "not three attempts for atom-a"
finish

# --- the bound of lookups ----------------------------------------

# many_repositories COUNT: a lock with a flakeyard input of COUNT repositories.
many_repositories() {
  local count=$1
  jq -n --argjson count "$count" --arg rev "$(c 1)" '
    [range($count) | "atom-\(.)"] as $names
    | {version: 7, root: "root", nodes: ({root: {inputs: ($names | map({(.): .}) | add)}}
      + ($names | map({(.): {locked: {type: "git", url: "https://github.com/flakeyard/\(.)", rev: $rev}}}) | add))}' \
    >"$work/workspace/flake.lock"
}

setup
given_tools
many_repositories 51
run "releases: parse many repositories" ok step/parse.sh
prepared
run "releases: at most 50 repositories are looked up" ok step/releases.sh TOKEN="$TOKEN"
[[ -z $current ]] || (($(grep -c '^graphql' "$work/calls") == 50)) || report "not 50 lookups"
expect_finding release "Could not verify inputs.atom-9, flakeyard/atom-9: the lock has more than 50 flakeyard repositories."
finish

setup
given_tools
given_lock version-7
run "releases: parse a lock without flakeyard inputs" ok step/parse.sh
prepared
run "releases: no flakeyard input, no lookup" ok step/releases.sh TOKEN="$TOKEN"
expect no-calls
expect_findings release 0
finish

# --- several releases of one commit -------------------------------

# refs_lock REF...: a lock with an input refN of flakeyard/atom-s at the
# commit $(c a) for each REF.
refs_lock() {
  jq -n --arg rev "$(c a)" '
    [$ARGS.positional | to_entries[] | {name: "ref\(.key)", ref: .value}] as $inputs
    | {version: 7, root: "root", nodes: ({root: {inputs: ($inputs | map({(.name): .name}) | add)}}
      + ($inputs | map({(.name): {
          locked: {type: "git", url: "https://github.com/flakeyard/atom-s", ref: .ref, rev: $rev},
          original: {type: "git", url: "https://github.com/flakeyard/atom-s", ref: .ref, rev: $rev}}}) | add))}' \
    --args "$@" >"$work/workspace/flake.lock"
}

setup
given_tools
refs_lock v1.2.4 v1.2.3 v1.2.5
run "releases: parse refs of one commit" ok step/parse.sh
prepared
releases_of atom-s "v1.2.3=$(c a)" "v1.2.4=$(c a)"
run "releases: a ref may be any release tag of its commit" ok step/releases.sh TOKEN="$TOKEN"
expect_findings release 1
expect_finding release "inputs.ref2 of flakeyard/atom-s: its ref v1.2.5 is not the tag of a release of its rev, v1.2.3, v1.2.4. The newest release of v1 is v1.2.4 at $(c a)."
finish

# shellcheck shell=bash
# Tests of scripts/step/releases.sh and scripts/lock/releases.jq.
# shellcheck disable=SC2154 # work comes from setup.

readonly TOKEN=ghs_abcDEF123
# The revisions of the tests: rev[X] is X 40 times.
declare -A rev
for x in {0..9} {a..d}; do printf -v "rev[${x}]" "${x}%.0s" {1..40}; done

# lookups REPO: prints how many times the releases of flakeyard/REPO were
# looked up.
lookups() {
  local repo=$1
  grep -cxF "graphql owner=flakeyard name=${repo}" "${work}/calls"
}

# expect_lookups REPO COUNT: the releases of flakeyard/REPO were looked up
# COUNT times.
expect_lookups() {
  local repo=$1 count=$2 actual
  [[ -n ${current} ]] || return 0
  actual=$(lookups "${repo}")
  ((actual == count)) || report "${actual} lookups of ${repo}, expected ${count}"
}

# releases_setup: the parsed releases fixture and the releases of the API:
# atom-a on two pages with a mutable and a draft release, atom-b after one
# gateway timeout, atom-c with a mutable release only; atom-gone does not
# exist.
releases_setup() {
  action_setup
  given_tools
  given_lock releases
  run "releases: parse the fixture" ok scripts/step/parse.sh
  prepared
  releases_of atom-a "v1.0.0=${rev[0]}" "v1.1.0=${rev[1]}" "v2.0.0=${rev[2]}" \
    "v1.2.0=${rev[3]}:mutable" "v1.3.0=${rev[4]}:draft" "v1=${rev[5]}" "nightly=${rev[6]}"
  release_page atom-a 2 "v0.9.0=${rev[9]}"
  releases_of atom-b "v1.0.0=${rev[b]}"
  request=$(releases_request atom-b)
  transient_failures "${request}" 1
  releases_of atom-c "v1.0.0=${rev[c]}:mutable"
}

releases_setup
run "releases: every flakeyard input" ok scripts/step/releases.sh TOKEN="${TOKEN}"
expect message "::add-mask::${TOKEN}"
expect_findings release 8
while IFS='|' read -r input message; do
  expect_finding release "inputs.${input} of flakeyard/${message}"
done <<CASES
wrong-exact|atom-a: its ref v1.0.0 is not the tag of a release of its rev, v1.1.0. The newest release of v1 is v1.1.0 at ${rev[1]}.
unreleased|atom-a: its rev ${rev[d]} is not the commit of an immutable release v1.Y.Z. The newest release of v1 is v1.1.0 at ${rev[1]}.
mutable|atom-a: its rev ${rev[3]} is not the commit of an immutable release v1.Y.Z. The newest release of v1 is v1.1.0 at ${rev[1]}.
draft|atom-a: its rev ${rev[4]} is not the commit of an immutable release v1.Y.Z. The newest release of v1 is v1.1.0 at ${rev[1]}.
other-major|atom-a: its rev ${rev[1]} is not the commit of an immutable release v2.Y.Z. The newest release of v2 is v2.0.0 at ${rev[2]}.
bad-ref|atom-a: its ref main is neither vX nor vX.Y.Z. The newest release is v2.0.0 at ${rev[2]}.
only-mutable|atom-c: its rev ${rev[c]} is not the commit of an immutable release v1.Y.Z. There is no immutable release v1.Y.Z.
CASES
expect_finding release "Could not verify inputs.gone, flakeyard/atom-gone: the GitHub API failed, see the log."
finish

releases_setup
run "releases: one lookup per repository, for github.com only" ok scripts/step/releases.sh \
  TOKEN="${TOKEN}" GH_REPO=o/r GH_ENTERPRISE_TOKEN=x GH_CONFIG_DIR=/x
for repo in atom-a atom-c atom-gone; do
  expect_lookups "${repo}" 1
done
# atom-b once more, after its gateway timeout.
expect_lookups atom-b 2
expect sleeps 5
expect call "GH_HOST=github.com GH_TOKEN=${TOKEN} GH_REPO= GH_ENTERPRISE_TOKEN= GH_CONFIG_DIR="
[[ -z ${current} ]] || ! grep -q "name=utils" "${work}/calls" || report "a third-party repository was looked up"
finish

for token in "" "ghs abc" $'ghs_abc\n::warning::x'; do
  releases_setup
  run "releases: rejects the token '${token}'" fail scripts/step/releases.sh TOKEN="${token}"
  expect message "Invalid github-token"
  expect no-message "::add-mask::"
  expect no-calls
  finish
done

releases_setup
request=$(releases_request atom-a)
transient_failures "${request}" 3
run "releases: a lasting server error is an input that could not be verified" ok scripts/step/releases.sh TOKEN="${TOKEN}"
expect_finding release "Could not verify inputs.good, flakeyard/atom-a: the GitHub API failed, see the log."
expect_lookups atom-a 3
expect sleeps "5 10 5"
finish

# --- the bound of lookups ----------------------------------------

# many_repositories COUNT: a lock with a flakeyard input of COUNT repositories.
many_repositories() {
  local count=$1
  jq -n --argjson count "${count}" --arg rev "${rev[1]}" '
    [range($count) | "atom-\(.)"] as $names
    | {version: 7, root: "root", nodes: ({root: {inputs: ($names | map({(.): .}) | add)}}
      + ($names | map({(.): {locked: {type: "git", url: "https://github.com/flakeyard/\(.)", rev: $rev}}}) | add))}' \
    >"${work}/workspace/flake.lock"
}

action_setup
given_tools
many_repositories 51
run "releases: parse many repositories" ok scripts/step/parse.sh
prepared
run "releases: at most 50 repositories are looked up" ok scripts/step/releases.sh TOKEN="${TOKEN}"
graphql_calls=$(grep -c '^graphql' "${work}/calls")
[[ -z ${current} ]] || ((graphql_calls == 50)) || report "not 50 lookups"
expect_finding release "Could not verify inputs.atom-9, flakeyard/atom-9: the lock has more than 50 flakeyard repositories."
finish

action_setup
given_tools
given_lock version-7
run "releases: parse a lock without flakeyard inputs" ok scripts/step/parse.sh
prepared
run "releases: no flakeyard input, no lookup" ok scripts/step/releases.sh TOKEN="${TOKEN}"
expect no-calls
expect_findings release 0
finish

# --- several releases of one commit -------------------------------

# refs_lock REF...: a lock with an input refN of flakeyard/atom-s at the
# commit ${rev[a]} for each REF.
refs_lock() {
  jq -n --arg rev "${rev[a]}" '
    [$ARGS.positional | to_entries[] | {name: "ref\(.key)", ref: .value}] as $inputs
    | {version: 7, root: "root", nodes: ({root: {inputs: ($inputs | map({(.name): .name}) | add)}}
      + ($inputs | map({(.name): {
          locked: {type: "git", url: "https://github.com/flakeyard/atom-s", ref: .ref, rev: $rev},
          original: {type: "git", url: "https://github.com/flakeyard/atom-s", ref: .ref, rev: $rev}}}) | add))}' \
    --args "$@" >"${work}/workspace/flake.lock"
}

action_setup
given_tools
refs_lock v1.2.4 v1.2.3 v1.2.5
run "releases: parse refs of one commit" ok scripts/step/parse.sh
prepared
releases_of atom-s "v1.2.3=${rev[a]}" "v1.2.4=${rev[a]}"
run "releases: a ref may be any release tag of its commit" ok scripts/step/releases.sh TOKEN="${TOKEN}"
expect_findings release 1
expect_finding release "inputs.ref2 of flakeyard/atom-s: its ref v1.2.5 is not the tag of a release of its rev, v1.2.3, v1.2.4. The newest release of v1 is v1.2.4 at ${rev[a]}."
finish

# shellcheck shell=bash
# Tests of scripts/lock/newer-major.jq, through step/releases.sh, at the times
# that the date stub of the shell library gives.
# shellcheck disable=SC2154 # work and state come from action_setup.

d() { printf "$1%.0s" {1..40}; }

# majors_lock INPUT...: a lock with a flakeyard input inN for each INPUT,
# REPO|REF|REV, which has no ref when REF is "-".
majors_lock() {
  jq -n '
    [$ARGS.positional | to_entries[] | (.value | split("|")) as [$repo, $ref, $rev]
      | {name: "in\(.key)", repo: $repo, ref: $ref, rev: $rev}] as $inputs
    | {version: 7, root: "root", nodes: ({root: {inputs: ($inputs | map({(.name): .name}) | add)}}
      + ($inputs | map(
          {type: "git", url: "https://github.com/flakeyard/\(.repo)", rev: .rev, shallow: true}
          + if .ref == "-" then {} else {ref: .ref} end
          | {locked: ., original: .}) as $nodes
        | [$inputs, $nodes] | transpose | map({(.[0].name): .[1]}) | add))}' \
    --args "$@" >"$work/workspace/flake.lock"
}

# major_findings: prints the message of each warning of the rule, one per
# line.
major_findings() {
  jq -r '.[] | select(.level == "warning") | .message' "$state/findings/newer-major.json"
}

# expect_major MESSAGE: the rule warned with MESSAGE.
expect_major() {
  local message=$1
  [[ -z $current ]] || major_findings | grep -qxF -- "$message" \
    || report "no warning '$message' in: $(major_findings)"
}

# expect_majors COUNT: the rule wrote COUNT findings, all of them warnings.
expect_majors() {
  local count=$1 actual warnings
  [[ -n $current ]] || return 0
  actual=$(jq length "$state/findings/newer-major.json")
  warnings=$(major_findings | wc -l)
  ((actual == count && warnings == count)) \
    || report "$actual findings, expected $count warnings: $(major_findings)"
}

# major_case NAME TIME INPUT...: parse a lock of INPUT, as majors_lock takes
# them, and fix TIME; the test then gives the releases and runs the step.
major_case() {
  local name=$1 time=$2
  shift 2
  action_setup
  given_tools
  majors_lock "$@"
  run "newer-major: parse for $name" ok scripts/step/parse.sh
  prepared
  fixed_time "$time"
}

# look_up_releases NAME [VAR=VALUE...]: run the step that looks up the releases.
look_up_releases() {
  local name=$1
  shift
  run "newer-major: $name" ok scripts/step/releases.sh TOKEN=ghs_x "$@"
}

readonly NOW=2026-11-12T12:00:00Z
readonly URL=https://github.com/flakeyard/atom-m/releases/tag

# --- the support of the major version of the input -----------------

major_case "no newer major version" "$NOW" "atom-m|v1|$(d 1)"
releases_of atom-m "v1.0.0=$(d 0)" "v1.1.0=$(d 1)" "v0.1.0=$(d 9):prerelease"
look_up_releases "no newer major version"
expect_majors 0
finish

# next_major_releases: v1 and the next major version v2, first released on
# 2026-11-03.
next_major_releases() {
  releases_of atom-m "v1.0.0=$(d 0)" "v1.1.0=$(d 1)" "v2.0.0=$(d 2)@2026-11-03T08:00:00Z" \
    "v2.1.0=$(d 3)@2026-11-10T08:00:00Z"
}

while IFS='|' read -r time fixes; do
  major_case "the next major version at $time" "$time" "atom-m|v1|$(d 1)"
  next_major_releases
  look_up_releases "the next major version at $time"
  expect_majors 1
  expect_major "inputs.in0 of flakeyard/atom-m follows v1, and v2 is released: v2.0.0 on 2026-11-03, newest v2.1.0. v1 $fixes security fixes until 2027-05-03. The migration guide is in the release notes of v2.0.0, $URL/v2.0.0."
  finish
done <<'CASES'
2026-11-12T12:00:00Z|receives
2027-05-03T23:59:59Z|receives
2027-05-04T00:00:00Z|received
CASES

major_case "two newer major versions" "$NOW" "atom-m|v1.1.0|$(d 1)"
releases_of atom-m "v1.1.0=$(d 1)" "v2.0.0=$(d 2)@2026-03-10T08:00:00Z" "v3.1.0=$(d 4)" \
  "v3.0.0=$(d 3)@2026-11-03T08:00:00Z"
look_up_releases "two newer major versions"
expect_major "inputs.in0 of flakeyard/atom-m follows v1, and v3 is released: v3.0.0 on 2026-11-03, newest v3.1.0. v1 receives no fixes; only v2 receives security fixes until 2027-05-03. The migration guides are in the release notes of v2.0.0, $URL/v2.0.0; v3.0.0, $URL/v3.0.0."
finish

major_case "a v0 input without v1.0.0" "$NOW" "atom-m|v0|$(d 1)"
releases_of atom-m "v0.1.0=$(d 1):prerelease" "v0.2.0=$(d 2):prerelease" "v1.0.0=$(d 3):prerelease"
look_up_releases "a v0 input without v1.0.0"
expect_majors 0
finish

major_case "a v0 input with v1.0.0" "$NOW" "atom-m|v0|$(d 1)"
releases_of atom-m "v0.1.0=$(d 1):prerelease" "v1.0.0=$(d 3)@2026-08-31T23:30:00Z"
look_up_releases "a v0 input with v1.0.0"
expect_major "inputs.in0 of flakeyard/atom-m follows v0, and v1 is released: v1.0.0 on 2026-08-31, newest v1.0.0. 0.y.z releases are previews without support. The migration guide is in the release notes of v1.0.0, $URL/v1.0.0."
finish

# --- which releases count -----------------------------------------

major_case "releases that do not count" "$NOW" "atom-m|v1|$(d 1)"
releases_of atom-m "v1.1.0=$(d 1)" "v2.0.0=$(d 2):prerelease" "v3.0.0=$(d 3):draft" \
  "v4.0.0=$(d 4):mutable" "v5.0.0-rc.1=$(d 5)" "v6=$(d 6)" "7.0.0=$(d 7)"
look_up_releases "pre-releases, drafts, mutable releases and other tags do not count"
expect_majors 0
finish

major_case "a first release other than vK.0.0" "$NOW" "atom-m|v1|$(d 1)"
releases_of atom-m "v1.1.0=$(d 1)" "v2.0.0=$(d 2):mutable" "v2.0.1=$(d 3)@2026-08-31T08:00:00Z" \
  "v2.2.0=$(d 5)" "v2.0.0-rc.1=$(d 4)" "v3.0.0=$(d 6):prerelease"
look_up_releases "the first release of a major version is its lowest release that counts"
expect_major "inputs.in0 of flakeyard/atom-m follows v1, and v2 is released: v2.0.1 on 2026-08-31, newest v2.2.0. v1 receives security fixes until 2027-02-28. The migration guide is in the release notes of v2.0.1, $URL/v2.0.1."
finish

while IFS='|' read -r published end; do
  major_case "a first release on $published" "$NOW" "atom-m|v1|$(d 1)"
  releases_of atom-m "v1.1.0=$(d 1)" "v2.0.0=$(d 2)@${published}T08:00:00Z"
  look_up_releases "6 months after $published is $end"
  expect_major "inputs.in0 of flakeyard/atom-m follows v1, and v2 is released: v2.0.0 on $published, newest v2.0.0. v1 $([[ $end > 2026-11-12 ]] && echo receives || echo received) security fixes until $end. The migration guide is in the release notes of v2.0.0, $URL/v2.0.0."
  finish
done <<'CASES'
2026-12-31|2027-06-30
2027-08-31|2028-02-29
2026-03-31|2026-09-30
2026-07-15|2027-01-15
CASES

# --- which inputs ---------------------------------------------------

major_case "inputs without ref" "$NOW" "atom-m|-|$(d 1)" "atom-m|-|$(d 8)"
next_major_releases
look_up_releases "an input without ref is of the major version of its rev"
expect_majors 1
expect_major "inputs.in0 of flakeyard/atom-m is at v1, and v2 is released: v2.0.0 on 2026-11-03, newest v2.1.0. v1 receives security fixes until 2027-05-03. The migration guide is in the release notes of v2.0.0, $URL/v2.0.0."
finish

major_case "two nodes and refs" "$NOW" "atom-m|v1|$(d 1)" "atom-m|v1|$(d 0)" "atom-m|main|$(d 1)" "atom-m|v2|$(d 2)"
next_major_releases
look_up_releases "two nodes of one major version warn each; a ref that is no major version, none"
expect_majors 2
expect_major "inputs.in1 of flakeyard/atom-m follows v1, and v2 is released: v2.0.0 on 2026-11-03, newest v2.1.0. v1 receives security fixes until 2027-05-03. The migration guide is in the release notes of v2.0.0, $URL/v2.0.0."
finish

major_case "a repository that was not looked up" "$NOW" "atom-m|v1|$(d 1)" "atom-gone|v1|$(d 1)"
next_major_releases
look_up_releases "a repository that was not looked up has no warning"
expect_majors 1
expect_finding release "Could not verify inputs.in1, flakeyard/atom-gone: the GitHub API failed, see the log."
finish

major_case "the rule off" "$NOW" "atom-m|v1|$(d 1)"
next_major_releases
look_up_releases "off" NEWER_MAJOR=false
[[ -z $current || ! -e $state/findings/newer-major.json ]] || report "the rule ran: $(major_findings)"
finish

major_case "no time" "$NOW" "atom-m|v1|$(d 1)"
next_major_releases
rm -- "$work/fixtures/now"
run "newer-major: takes the date from date" fail scripts/step/releases.sh TOKEN=ghs_x
expect message "the test fixed no time"
finish

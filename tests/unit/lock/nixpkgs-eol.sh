# shellcheck shell=bash
# Tests of scripts/lock/nixpkgs-eol.jq, through step/parse.sh, at the times
# that the date stub of the shell library gives.
# shellcheck disable=SC2154 # work and state come from action_setup.

# The end of every message, restated as an independent oracle.
readonly ADVICE='switch to the next stable branch (FY-0036).'

# nixpkgs_lock REF...: a lock with a root input nixpkgsN of NixOS/nixpkgs on
# github for each REF, which has no ref when REF is "-".
nixpkgs_lock() {
  jq -n '
    [$ARGS.positional | to_entries[] | {name: "nixpkgs\(.key)", ref: .value}] as $inputs
    | {type: "github", owner: "NixOS", repo: "nixpkgs"} as $source
    | {version: 7, root: "root", nodes: ({root: {inputs: ($inputs | map({(.name): .name}) | add)}}
      + ($inputs | map({(.name): {
          locked: ($source + {rev: "0000000000000000000000000000000000000000"}),
          original: ($source + if .ref == "-" then {} else {ref: .ref} end)}}) | add))}' \
    --args "$@" >"$work/workspace/flake.lock"
}

# eol_findings: prints the level and the message of each finding of the rule,
# a violation without a level, one per line.
eol_findings() {
  jq -r '.[] | "\(.level // "violation") \(.message)"' "$state/findings/nixpkgs-eol.json"
}

# expect_eol LEVEL MESSAGE: the rule found MESSAGE as LEVEL: violation,
# warning or notice.
expect_eol() {
  local level=$1 message=$2
  [[ -z $current ]] || eol_findings | grep -qxF -- "$level $message" \
    || report "no $level '$message' in: $(eol_findings)"
}

# expect_no_eol: the rule found nothing.
expect_no_eol() {
  [[ -z $current ]] || [[ -z $(eol_findings) ]] || report "unexpected findings: $(eol_findings)"
}

# eol_case NAME REF TIME EVENT: parse a lock with REF at TIME in a run of
# EVENT.
eol_case() {
  local name=$1 ref=$2 time=$3 event=$4
  action_setup
  given_tools
  nixpkgs_lock "$ref"
  fixed_time "$time"
  run "nixpkgs-eol: $name" ok scripts/step/parse.sh GITHUB_EVENT_NAME="$event"
}

# --- the dates of the branches ------------------------------------

# The last day of each kind of branch, and how its warning reads 30 days
# before. These dates restate the table of ADR-0002 as an independent oracle.
while IFS='|' read -r ref time eol; do
  eol_case "$ref warns 30 days before $eol" "$ref" "$time" pull_request
  expect_eol warning "inputs.nixpkgs0 follows $ref, which reaches its end of life on $eol, in 30 days; $ADVICE"
  finish
done <<'CASES'
nixos-26.05|2026-12-01T00:00:00Z|2026-12-31
nixos-26.05-small|2026-12-01T00:00:00Z|2026-12-31
nixos-26.11|2027-05-31T00:00:00Z|2027-06-30
nixos-26.11-small|2027-05-31T00:00:00Z|2027-06-30
nixos-99.11|2100-05-31T00:00:00Z|2100-06-30
CASES

# --- the days around the warning and the end of life ---------------

eol_case "nothing 31 days before" nixos-26.05 2026-11-30T23:59:59Z pull_request
expect_no_eol
finish

eol_case "a warning on the last day" nixos-26.05 2026-12-31T23:59:59Z schedule
expect_eol warning "inputs.nixpkgs0 follows nixos-26.05, which reaches its end of life on 2026-12-31, today; $ADVICE"
finish

eol_case "a warning the day before" nixos-26.05 2026-12-30T12:00:00Z schedule
expect_eol warning "inputs.nixpkgs0 follows nixos-26.05, which reaches its end of life on 2026-12-31, in 1 day; $ADVICE"
finish

readonly REACHED="inputs.nixpkgs0 follows nixos-26.05, which reached its end of life on 2026-12-31; $ADVICE"

eol_case "a violation after the end of life in a scheduled run" nixos-26.05 2027-01-01T00:00:00Z schedule
expect_eol violation "$REACHED"
finish

for event in pull_request push workflow_dispatch merge_group ""; do
  eol_case "a warning after the end of life in a run of '$event'" nixos-26.05 2027-01-01T00:00:00Z "$event"
  expect_eol warning "$REACHED"
  finish
done

# --- branches without a known end of life ---------------------------

for ref in nixos-unstable nixpkgs-unstable nixos-26.04 release-26.05 nixos-26.05-x; do
  eol_case "a notice for $ref" "$ref" 2027-01-01T00:00:00Z schedule
  expect_eol notice "inputs.nixpkgs0 follows $ref, whose end of life is not known; $ADVICE"
  finish
done

eol_case "a notice for an input without ref" - 2027-01-01T00:00:00Z schedule
expect_eol notice "inputs.nixpkgs0 has no ref, so its end of life is not known; $ADVICE"
finish

# --- which inputs ---------------------------------------------------

action_setup
given_tools
nixpkgs_lock nixos-26.05 nixos-25.11
fixed_time 2026-06-15T00:00:00Z
run "nixpkgs-eol: two root nixpkgs inputs" ok scripts/step/parse.sh GITHUB_EVENT_NAME=schedule
expect_eol warning "inputs.nixpkgs1 follows nixos-25.11, which reaches its end of life on 2026-06-30, in 15 days; $ADVICE"
[[ -z $current ]] || (($(eol_findings | wc -l) == 1)) || report "not one finding: $(eol_findings)"
finish

action_setup
given_tools
given_lock duplicates
fixed_time 2027-01-01T00:00:00Z
run "nixpkgs-eol: only inputs of the root" ok scripts/step/parse.sh GITHUB_EVENT_NAME=schedule
expect_eol violation "inputs.nixpkgs follows nixos-26.05, which reached its end of life on 2026-12-31; $ADVICE"
[[ -z $current ]] || (($(eol_findings | wc -l) == 1)) || report "not one finding: $(eol_findings)"
finish

action_setup
given_tools
nixpkgs_lock nixos-26.05
run "nixpkgs-eol: off" ok scripts/step/parse.sh NIXPKGS_EOL=false
[[ -z $current || ! -e $state/findings/nixpkgs-eol.json ]] \
  || report "the end of life was checked: $(eol_findings)"
finish

action_setup
given_tools
nixpkgs_lock nixos-26.05
rm -- "$work/fixtures/now"
run "nixpkgs-eol: takes the date from date" fail scripts/step/parse.sh
expect message "the test fixed no time"
finish

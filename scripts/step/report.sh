#!/usr/bin/env bash
# Reports every finding of the rules: all of them in a table of the job
# summary, and as annotations of the lock file within the ANNOTATIONS_PER_KIND
# of each kind of a step, the last of them saying how many more the summary
# has. Fails when there is any violation: the action has no warn-only mode.
# Only the end of life of nixpkgs and the newer major version have findings
# that are warnings or notices, which do not fail the run (ADR-0002,
# ADR-0004).
#
# Inputs (environment): LOCK_PATH, PIN_FORM, NIXPKGS_EOL, NEWER_MAJOR.
set -euo pipefail
# Builtins only until lib/env.sh replaces PATH, which is the job's.
lib=${BASH_SOURCE[0]%/*}/../lib
# shellcheck source-path=SCRIPTDIR source=../lib/env.sh
source "$lib/env.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/tools.sh
source "$lib/tools.sh"

# The kind of the annotation of each finding: error for a violation, else its
# level; and the title of each rule, and of an input that could not be
# verified, which the release rule finds.
# shellcheck disable=SC2016 # variables of jq
readonly TITLES_PROGRAM='{"duplicates": "Duplicated source", "pin-form": "Pin form", "release": "Release",
    "nixpkgs-eol": "End of life of nixpkgs", "newer-major": "Newer major version"} as $titles
  | .[] | (.level // "error"), (if .unverified then "Could not verify" else $titles[.rule] end), .input, .message
  | gsub("\u0000"; "?")'
# The findings of the rules as one array: violations first, the inputs that
# could not be verified last of them, then warnings and notices.
# shellcheck disable=SC2016 # variables of jq
readonly ORDER_PROGRAM='{"error": 0, "warning": 1, "notice": 2} as $ranks
  | add | sort_by($ranks[.level // "error"], .unverified // false)'
readonly VIOLATIONS_PROGRAM='map(select(.level == null)) | length'
readonly KIND_FORM='^(error|warning|notice)$'

# The rules whose findings the steps before wrote, in the order of the report.
RULES=(duplicates)
[[ ${PIN_FORM-} == false ]] || RULES+=(pin-form)
RULES+=(release)
[[ ${NIXPKGS_EOL-} == false ]] || RULES+=(nixpkgs-eol)
[[ ${NEWER_MAJOR-} == false ]] || RULES+=(newer-major)
readonly RULES

# require_findings: fails unless every rule of RULES wrote its findings.
require_findings() {
  local rule
  for rule in "${RULES[@]}"; do
    [[ -f $FINDINGS_DIR/$rule.json ]] || fail "The findings of $rule are missing: an earlier step did not run."
  done
}

# all_findings: prints every finding of RULES as one JSON array, in the order
# of the report.
all_findings() {
  local rule files=()
  for rule in "${RULES[@]}"; do
    files+=("$FINDINGS_DIR/$rule.json")
  done
  "$jq" -s "$ORDER_PROGRAM" "${files[@]}"
}

# report_finding KIND TITLE INPUT MESSAGE: one row of the summary, one
# annotation of KIND: error, warning or notice.
report_finding() {
  local kind=$1 title=$2 input=$3 message=$4 check=$2
  [[ $kind =~ $KIND_FORM ]] || fail "Unknown kind of finding '$kind'."
  [[ $kind == error ]] || check+=" ($kind)"
  summary "| $check | $(code_span "$input") | $(code_span "$message") |"
  "$kind" "$message" "$LOCK_PATH" "$title: $input"
}

# report_all FINDINGS: the summary and the annotations of the JSON array
# FINDINGS.
report_all() {
  local findings=$1 kind title input message
  summary "### $(code_span "$LOCK_PATH")"
  summary ""
  summary "| Check | Input | Problem |"
  summary "| --- | --- | --- |"
  while IFS= read -r -d '' kind && IFS= read -r -d '' title \
    && IFS= read -r -d '' input && IFS= read -r -d '' message; do
    report_finding "$kind" "$title" "$input" "$message"
  done < <("$jq" --raw-output0 "$TITLES_PROGRAM" <<<"$findings")
  flush "the job summary lists all of them"
}

# report_pass: the lock has no violation.
report_pass() {
  notice "$LOCK_PATH passes every check of action-flake-lock."
  summary "$(code_span "$LOCK_PATH") passes every check of action-flake-lock."
}

main() {
  local findings count
  # The jq of the action, for all_findings and report_all.
  jq=$(tool jq) || fail "The tools step did not build jq."
  require_findings
  findings=$(all_findings)
  count=$("$jq" "$VIOLATIONS_PROGRAM" <<<"$findings")
  ((count > 0)) || report_pass
  [[ $findings == "[]" ]] || report_all "$findings"
  ((count > 0)) || return 0
  # A plain line: the annotations are spent on the findings.
  echo "$LOCK_PATH has $count problems; the job summary lists them."
  exit 1
}

main "$@"

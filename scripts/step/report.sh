#!/usr/bin/env bash
# Reports every finding of the rules: all of them in a table of the job
# summary, and as annotations of the lock file within the MAX_ERRORS of a
# step, the last of them saying how many more the summary has. Fails when
# there is any: the action has no warn-only mode.
#
# Inputs (environment): LOCK_PATH, PIN_FORM.
set -euo pipefail
# Builtins only until lib/env.sh replaces PATH, which is the job's.
lib=${BASH_SOURCE[0]%/*}/../lib
# shellcheck source-path=SCRIPTDIR source=../lib/env.sh
source "$lib/env.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/report.sh
source "$lib/report.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/tools.sh
source "$lib/tools.sh"

# The title of the annotations of each rule, and of an input that could not
# be verified, which the release rule finds.
# shellcheck disable=SC2016 # variables of jq
readonly TITLES_PROGRAM='{"duplicates": "Duplicated source", "pin-form": "Pin form", "release": "Release"}
  as $titles | .[] | (if .unverified then "Could not verify" else $titles[.rule] end), .input, .message
  | gsub("\u0000"; "?")'

# The rules whose findings the steps before wrote, in the order of the report.
RULES=(duplicates)
[[ ${PIN_FORM-} == false ]] || RULES+=(pin-form)
RULES+=(release)
readonly RULES

# require_findings: fails unless every rule of RULES wrote its findings.
require_findings() {
  local rule
  for rule in "${RULES[@]}"; do
    [[ -f $FINDINGS_DIR/$rule.json ]] || fail "The findings of $rule are missing: an earlier step did not run."
  done
}

# all_findings: prints every finding of RULES as one JSON array, the inputs
# that could not be verified last.
all_findings() {
  local rule files=()
  for rule in "${RULES[@]}"; do
    files+=("$FINDINGS_DIR/$rule.json")
  done
  "$jq" -s 'add | sort_by(.unverified // false)' "${files[@]}"
}

# report_finding TITLE INPUT MESSAGE: one row of the summary, one annotation.
report_finding() {
  local title=$1 input=$2 message=$3
  summary "| $title | $(code_span "$input") | $(code_span "$message") |"
  annotate "$LOCK_PATH" "$title: $input" "$message"
}

# report_all FINDINGS: the summary and the annotations of the JSON array
# FINDINGS.
report_all() {
  local findings=$1 title input message
  summary "### $(code_span "$LOCK_PATH")"
  summary ""
  summary "| Check | Input | Problem |"
  summary "| --- | --- | --- |"
  while IFS= read -r -d '' title && IFS= read -r -d '' input && IFS= read -r -d '' message; do
    report_finding "$title" "$input" "$message"
  done < <("$jq" --raw-output0 "$TITLES_PROGRAM" <<<"$findings")
  flush_errors "the job summary lists all of them"
}

main() {
  local findings count
  # The jq of the action, for all_findings and report_all.
  jq=$(tool jq) || fail "The tools step did not build jq."
  require_findings
  findings=$(all_findings)
  count=$("$jq" length <<<"$findings")
  if ((count == 0)); then
    notice "$LOCK_PATH passes every check of action-flake-lock."
    summary "$(code_span "$LOCK_PATH") passes every check of action-flake-lock."
    return 0
  fi
  report_all "$findings"
  # A plain line: the annotations are spent on the findings.
  echo "$LOCK_PATH has $count problems; the job summary lists them."
  exit 1
}

main "$@"

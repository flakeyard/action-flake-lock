# shellcheck shell=bash
# Tests of scripts/step/report.sh.
# shellcheck disable=SC2154 # work comes from setup.
# shellcheck disable=SC2016 # Markdown of the summary, not expansions

# given_findings RULE JSON: the step of RULE found the findings JSON.
given_findings() {
  local rule=$1 json=$2 dir=$work/temp/action-flake-lock/findings
  mkdir -p "$dir"
  printf '%s\n' "$json" >"$dir/$rule.json"
}

# no_findings: no rule found anything.
no_findings() {
  local rule
  for rule in duplicates pin-form release; do given_findings "$rule" '[]'; done
}

# findings_of COUNT: COUNT findings of pin-form as JSON.
findings_of() {
  jq -cn --argjson count "$1" '[range(1; $count + 1) | {rule: "pin-form", input: "inputs.i\(.)", message: "problem \(.)"}]'
}

# a_finding RULE INPUT MESSAGE: one finding as JSON.
a_finding() {
  jq -cn --arg rule "$1" --arg input "$2" --arg message "$3" '{rule: $rule, input: $input, message: $message}'
}

setup
given_tools
no_findings
run "report: a lock without problems passes" ok step/report.sh
expect message "::notice::flake.lock passes every check of action-flake-lock."
expect summary '`flake.lock` passes every check'
finish

setup
given_tools
no_findings
given_findings duplicates "[$(a_finding duplicates github.com/o/r 'r is locked 2 times')]"
given_findings release '[{"rule":"release","input":"inputs.b","message":"Could not verify inputs.b","unverified":true},
  {"rule":"release","input":"inputs.a","message":"inputs.a of flakeyard/a: bad rev"}]'
run "report: every finding, in the summary and as annotations" fail step/report.sh
expect message "::error file=flake.lock,title=Duplicated source%3A github.com/o/r::r is locked 2 times"
expect message "::error file=flake.lock,title=Release%3A inputs.a::inputs.a of flakeyard/a: bad rev"
expect message "::error file=flake.lock,title=Could not verify%3A inputs.b::Could not verify inputs.b"
expect message "flake.lock has 3 problems; the job summary lists them."
expect errors 3
expect summary '| Duplicated source | `github.com/o/r` | `r is locked 2 times` |'
expect summary '| Release | `inputs.a` | `inputs.a of flakeyard/a: bad rev` |'
[[ -z $current ]] || [[ $(grep -c '^| ' "$work/summary") == 5 ]] || report "not a table of 3 rows: $(cat "$work/summary")"
[[ -z $current ]] || [[ $(tail -1 "$work/summary") == *"Could not verify"* ]] || report "an input that could not be verified is not last"
finish

setup
given_tools
no_findings
given_findings pin-form "$(findings_of 12)"
run "report: at most 10 annotations, the last says how many more" fail step/report.sh
expect errors 10
expect message "title=Pin form%3A inputs.i9::problem 9"
expect no-message "inputs.i10::"
expect message "::error::3 more errors are not shown here; the job summary lists all of them."
expect message "flake.lock has 12 problems; the job summary lists them."
expect summary '`inputs.i12`'
finish

setup
given_tools
no_findings
given_findings pin-form "$(findings_of 10)"
run "report: ten findings are all annotations" fail step/report.sh
expect errors 10
expect message "title=Pin form%3A inputs.i10::problem 10"
expect no-message "more errors"
finish

setup
given_tools
given_findings duplicates '[]'
given_findings release '[]'
run "report: pin-form off has no findings" ok step/report.sh PIN_FORM=false
finish

setup
given_tools
given_findings duplicates '[]'
run "report: fails when a step did not run" fail step/report.sh
expect message "The findings of pin-form are missing: an earlier step did not run."
finish

# --- names of the lock -------------------------------------------

setup
given_tools
given_lock hostile-names
run "report: parse a lock with a hostile name" ok step/parse.sh
prepared
releases_of none
run "report: look up no releases" ok step/releases.sh TOKEN=ghs_x
prepared
run "report: names of the lock cannot leave their annotation" fail step/report.sh
expect message '::error file=flake.lock,title=Pin form%3A inputs."a%2Cb%3Ac%2525\r\n%3A%3Awarning%3A%3Ax"::inputs."a,b:c%2525\r\n::warning::x" is not pinned'
[[ -z $current ]] || ! grep -q '^::warning' "$work/stdout" || report "a name started a workflow command"
finish

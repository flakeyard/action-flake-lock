# shellcheck shell=bash
# Tests of scripts/lock/pin-form.jq, through step/parse.sh.
# shellcheck disable=SC2154 # state comes from setup.

readonly PIN_FORM='git+https://github.com/<owner>/<repo>?ref=<ref>&rev=<commit>&shallow=1'
readonly NOT_GITHUB_GIT='it is not a git+https URL of a repository on github.com'
readonly NOT_A_PIN="it has no ref; it has no rev of 40 hex digits; it is not shallow"

setup
given_tools
given_lock pin-form
run "pin-form: every root input not in the form" ok step/parse.sh
expect_findings pin-form 10
while IFS='|' read -r input problems; do
  expect_finding pin-form "inputs.$input is not pinned as $PIN_FORM: $problems."
done <<CASES
github-type|$NOT_GITHUB_GIT; it has no ref; it is not shallow
no-ref|it has no ref
no-rev|it has no rev of 40 hex digits; its rev is not the locked rev
rev-mismatch|its rev is not the locked rev
not-shallow|it is not shallow
submodules|it has submodules
flakeyard-exact|its ref is not the major tag vX of a flakeyard repository
outside|$NOT_GITHUB_GIT; $NOT_A_PIN
absolute|$NOT_GITHUB_GIT; $NOT_A_PIN
git-file|$NOT_GITHUB_GIT
CASES
# good, flakeyard-major, the relative path local and the follows pass.
finish

setup
given_tools
given_lock pin-form
run "pin-form: off" ok step/parse.sh PIN_FORM=false
[[ -z $current || ! -e $state/findings/pin-form.json ]] \
  || report "pin form was checked: $(findings pin-form)"
finish

setup
given_tools
given_lock version-7
run "pin-form: a lock in the form" ok step/parse.sh
expect_findings pin-form 0
expect_findings duplicates 0
finish

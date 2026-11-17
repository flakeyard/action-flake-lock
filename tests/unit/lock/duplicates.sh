# shellcheck shell=bash
# Tests of scripts/lock/duplicates.jq, through step/parse.sh.

readonly DUPLICATED_NIXPKGS='github.com/nixos/nixpkgs is locked 2 times: inputs.nixpkgs, inputs."my.atom".inputs.nixpkgs. Add to flake.nix: inputs."my.atom".inputs.nixpkgs.follows = "nixpkgs";'
readonly DUPLICATED_ATOM='github.com/flakeyard/atom-text is locked 2 times: inputs.utils-a.inputs.atom-text, inputs.utils-b.inputs.atom-text. The fix is a follows: let the flakes that bring it follow one input of this flake.'
readonly DUPLICATED_INPUTS='github.com/o/p is locked 2 times: inputs.p1, inputs.p2. Make them one node with follows, or list github.com/o/p in allow-duplicates.'

action_setup
given_tools
given_lock duplicates
run "duplicates: every duplicated source" ok scripts/step/parse.sh
expect_findings duplicates 3
# One root input: the line that fixes it, with a quoted attribute.
expect_finding duplicates "${DUPLICATED_NIXPKGS}"
# A flakeyard input of two third-party flakes, at two revs and in two forms.
expect_finding duplicates "${DUPLICATED_ATOM}"
# Two root inputs, whose repositories differ only in case: no follows line.
expect_finding duplicates "${DUPLICATED_INPUTS}"
finish

action_setup
given_tools
given_lock duplicates
run "duplicates: allowed sources are not reported" ok scripts/step/parse.sh \
  ALLOW_DUPLICATES=$'github.com/o/p\n github.com/nixos/nixpkgs '
expect_findings duplicates 1
expect_finding duplicates "${DUPLICATED_ATOM}"
finish

action_setup
given_tools
given_lock duplicates
run "duplicates: two dirs of one repository are two sources" ok scripts/step/parse.sh
found=$(findings duplicates)
[[ -z ${current} ]] || ! grep -qF github.com/o/r <<<"${found}" \
  || report "dir-a and dir-b are reported: ${found}"
finish

action_setup
given_tools
given_lock sources
run "duplicates: skipped sources are not duplicates" ok scripts/step/parse.sh
expect_findings duplicates 1
expect_finding duplicates "github.com/nixos/nixpkgs is locked 2 times: inputs.github, inputs.git-https. Make them one node with follows, or list github.com/nixos/nixpkgs in allow-duplicates."
finish

# --- lib- repositories of flakeyard (FY-0040) --------------------------

readonly DUPLICATED_LIBRARY_INPUTS='github.com/flakeyard/lib-x is locked 2 times: inputs.lib-x, inputs.lib-x-copy. Make them one node with follows, or list github.com/flakeyard/lib-x in allow-duplicates.'
readonly DUPLICATED_NESTED_ATOM='github.com/flakeyard/atom-text is locked 2 times: inputs.atom-a.inputs.atom-text, inputs.atom-b.inputs.atom-text. Make them one node with follows, or list github.com/flakeyard/atom-text in allow-duplicates.'
readonly DUPLICATED_OTHER_LIBRARY='github.com/o/lib-foo is locked 2 times: inputs.atom-a.inputs.lib-foo, inputs.atom-b.inputs.lib-foo. Make them one node with follows, or list github.com/o/lib-foo in allow-duplicates.'

action_setup
given_tools
given_lock libraries
run "duplicates: nested nodes of lib- repositories are not counted" ok scripts/step/parse.sh
expect_findings duplicates 3
# lib-atom of three atoms, at two revs and in two forms and cases: no finding.
found=$(findings duplicates)
[[ -z ${current} ]] || ! grep -qF lib-atom <<<"${found}" || report "lib-atom is reported: ${found}"
# A root input of lib-actions and the lib-actions of an atom: no finding.
[[ -z ${current} ]] || ! grep -qF lib-actions <<<"${found}" || report "lib-actions is reported: ${found}"
# Two root inputs of lib-x: a finding without the lib-x of atom-b.
expect_finding duplicates "${DUPLICATED_LIBRARY_INPUTS}"
# Nested nodes of other repositories of flakeyard, and of lib- repositories of
# other owners, still count.
expect_finding duplicates "${DUPLICATED_NESTED_ATOM}"
expect_finding duplicates "${DUPLICATED_OTHER_LIBRARY}"
finish

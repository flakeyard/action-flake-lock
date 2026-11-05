# shellcheck shell=bash
# Tests of scripts/lock/duplicates.jq, through step/parse.sh.

readonly DUPLICATED_NIXPKGS='github.com/nixos/nixpkgs is locked 2 times: inputs.nixpkgs, inputs."my.atom".inputs.nixpkgs. Add to flake.nix: inputs."my.atom".inputs.nixpkgs.follows = "nixpkgs";'
readonly DUPLICATED_ATOM='github.com/flakeyard/atom-text is locked 2 times: inputs.utils-a.inputs.atom-text, inputs.utils-b.inputs.atom-text. The fix is a follows: let the flakes that bring it follow one input of this flake.'
readonly DUPLICATED_INPUTS='github.com/o/p is locked 2 times: inputs.p1, inputs.p2. Make them one node with follows, or list github.com/o/p in allow-duplicates.'

setup
given_tools
given_lock duplicates
run "duplicates: every duplicated source" ok step/parse.sh
expect_findings duplicates 3
# One root input: the line that fixes it, with a quoted attribute.
expect_finding duplicates "$DUPLICATED_NIXPKGS"
# A flakeyard input of two third-party flakes, at two revs and in two forms.
expect_finding duplicates "$DUPLICATED_ATOM"
# Two root inputs, whose repositories differ only in case: no follows line.
expect_finding duplicates "$DUPLICATED_INPUTS"
finish

setup
given_tools
given_lock duplicates
run "duplicates: allowed sources are not reported" ok step/parse.sh \
  ALLOW_DUPLICATES=$'github.com/o/p\n github.com/nixos/nixpkgs '
expect_findings duplicates 1
expect_finding duplicates "$DUPLICATED_ATOM"
finish

setup
given_tools
given_lock duplicates
run "duplicates: two dirs of one repository are two sources" ok step/parse.sh
[[ -z $current ]] || ! findings duplicates | grep -qF github.com/o/r \
  || report "dir-a and dir-b are reported: $(findings duplicates)"
finish

setup
given_tools
given_lock sources
run "duplicates: skipped sources are not duplicates" ok step/parse.sh
expect_findings duplicates 1
expect_finding duplicates "github.com/nixos/nixpkgs is locked 2 times: inputs.github, inputs.git-https. Make them one node with follows, or list github.com/nixos/nixpkgs in allow-duplicates."
finish

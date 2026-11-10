# shellcheck shell=bash
# Static tests of action.yml: its interface (ADR-0001) and its steps: the
# shell library first, then the scripts, each through run-step.sh of the
# library.
# shellcheck disable=SC2016 # code of action.yml and jq, not expanded here
# shellcheck disable=SC2034 # current is the test that report and finish count

: "${root:?}"

readonly LIB_USES_FORM='^flakeyard/action-shell-lib@[0-9a-f]{40}$'
readonly STEP_SHELL='/usr/bin/bash --noprofile --norc -p -e -o pipefail {0}'
readonly STEP_RUN_FORM='^/usr/bin/bash -p "\$SHELL_LIB/run-step\.sh" "\$GITHUB_ACTION_PATH/scripts/step" (?<step>[a-z-]+)( [A-Z_]+)*$'
readonly STEP_LIB='${{ steps.lib.outputs.path }}'
# The steps of the action after the shell library, in their order.
readonly SCRIPT_STEPS='["check", "tools", "parse", "releases", "report"]'
readonly INPUTS='["path", "allow-duplicates", "pin-form", "github-token"]'

if require_yq action.yml; then
  action=$(load_yaml action.yml)

  yaml_check "$action" "action: the shell library is the first step, pinned by commit" \
    '.runs.steps[0] | .id == "lib" and (.uses | test($form))' --arg form "$LIB_USES_FORM"

  yaml_check "$action" "action: every other step runs its script through run-step.sh, in order" \
    '[.runs.steps[1:][] | select(.shell == $shell and .env.SHELL_LIB == $lib) | .run | capture($form).step]
    == $steps' --arg shell "$STEP_SHELL" --arg lib "$STEP_LIB" --arg form "$STEP_RUN_FORM" \
    --argjson steps "$SCRIPT_STEPS"

  yaml_check "$action" "action: a script gets every variable of its step" \
    'all(.runs.steps[1:][]; (.run | split(" ")) as $words
      | all(.env | keys[] | select(. != "SHELL_LIB"); IN($words[])))'

  yaml_check "$action" "action: exactly the inputs of ADR-0001 and no outputs" \
    '(.inputs | keys_unsorted) == $inputs and (has("outputs") | not)' --argjson inputs "$INPUTS"

  yaml_check "$action" "action: only the step releases gets the token" \
    '[.runs.steps[] | select(tostring | contains("inputs.github-token"))]
    == [.runs.steps[] | select(.run // "" | test(" releases "))]'
fi

setup
current="action: no file writes GITHUB_PATH"
! grep -q 'GITHUB_PATH' "$root/action.yml" "$root"/scripts/*/*.sh || report "the action writes GITHUB_PATH"
finish

# shell_lib_pins: the commits of the shell library that the files of this
# repository pin, each once.
shell_lib_pins() {
  grep -ohE 'flakeyard/action-shell-lib@[0-9a-f]{40}' "$root/action.yml" "$root"/.github/workflows/*.yaml | sort -u
}

setup
current="action: one commit of the shell library in every file"
[[ $(shell_lib_pins | wc -l) == 1 ]] || report "pins: $(shell_lib_pins | paste -sd' ')"
finish

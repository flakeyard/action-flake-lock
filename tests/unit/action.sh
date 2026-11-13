# shellcheck shell=bash
# Static tests of action.yml: its interface (ADR-0001) and its steps, which
# consumer/action.sh of the shell library checks, in the order of this action.
# shellcheck disable=SC2016 # code of action.yml and jq, not expanded here
# shellcheck disable=SC2034 # current is the test that report and finish count

: "${root:?}"

# The steps of the action after the shell library, in their order.
readonly SCRIPT_STEPS='["check", "tools", "parse", "releases", "report"]'
readonly INPUTS='["path", "allow-duplicates", "pin-form", "nixpkgs-eol", "newer-major", "github-token"]'

if require_yq action.yml; then
  action=$(load_yaml action.yml)
  check_action_steps action.yml
  check_library_pins

  yaml_check "$action" "action: the scripts of the steps, in order" \
    '[.runs.steps[1:][] | .run | match($run).captures[0].string] == $steps' \
    --arg run "$STEP_RUN_FORM" --argjson steps "$SCRIPT_STEPS"

  # Without it, a branch past its end of life only warns in scheduled runs
  # too (ADR-0002).
  yaml_check "$action" "action: the step parse gets GITHUB_EVENT_NAME" \
    '[.runs.steps[] | .run // "" | match($run) | .captures | select(.[0].string == "parse")
    | .[1].string | split(" ") | any(. == "GITHUB_EVENT_NAME")] == [true]' --arg run "$STEP_RUN_FORM"

  yaml_check "$action" "action: exactly the inputs of ADR-0004 and no outputs" \
    '(.inputs | keys_unsorted) == $inputs and (has("outputs") | not)' --argjson inputs "$INPUTS"

  yaml_check "$action" "action: only the step releases gets the token" \
    '[.runs.steps[] | select(tostring | contains("inputs.github-token"))]
    == [.runs.steps[] | select(.run // "" | test(" releases "))]'
fi

setup
current="action: no file writes GITHUB_PATH"
! grep -q 'GITHUB_PATH' "$root/action.yml" "$root"/scripts/*/*.sh || report "the action writes GITHUB_PATH"
finish

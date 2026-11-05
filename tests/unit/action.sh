# shellcheck shell=bash
# Static tests of action.yml: its interface (ADR-0001) and its steps, which
# all run through scripts/run-step.sh.
# shellcheck disable=SC2016 # code of action.yml and awk, not expanded here

: "${root:?}"

# action_steps: prints the shell and the run of each step of action.yml,
# separated by a tab, with a run folded over several lines joined.
action_steps() {
  awk '
    function flush() { if (in_step) print shell "\t" run }
    /^    - / { flush(); in_step = 1; shell = run = key = ""; sub(/^    - /, "      ") }
    in_step && /^      [a-z-]+:/ {
      key = $1; value = $0; sub(/^      [a-z-]+: */, "", value)
      if (key == "shell:") shell = value
      if (key == "run:") run = value
      next
    }
    in_step && key == "run:" && /^        / {
      line = $0; sub(/^ +/, "", line); run = run (run == "" ? "" : " ") line
    }
    END { flush() }
  ' "$root/action.yml"
}

readonly STEP_SHELL='/usr/bin/bash --noprofile --norc -p -e -o pipefail {0}'
readonly STEP_RUN_RE='^/usr/bin/bash -p "\$GITHUB_ACTION_PATH/scripts/run-step.sh" ([a-z-]+)$'
readonly UNSUPPORTED_OS_RUN='bash "$GITHUB_ACTION_PATH/scripts/step/unsupported-os.sh"'
# The steps of the action on Linux, in their order.
readonly LINUX_STEPS='check tools parse releases report'

start "action: every Linux step runs through run-step.sh, in order"
linux_steps=()
while IFS=$'\t' read -r shell command; do
  if [[ $shell == bash && $command == "$UNSUPPORTED_OS_RUN" ]]; then
    continue
  elif [[ $shell == "$STEP_SHELL" && $command =~ $STEP_RUN_RE ]]; then
    linux_steps+=("${BASH_REMATCH[1]}")
  else
    report "a step does not use run-step.sh: shell '$shell', run '$command'"
  fi
done < <(action_steps)
[[ "${linux_steps[*]}" == "$LINUX_STEPS" ]] || report "steps '${linux_steps[*]}', expected '$LINUX_STEPS'"
finish

# action_inputs: the names of the inputs of action.yml, one per line.
action_inputs() {
  awk '/^inputs:/ { on = 1; next } /^[a-z]/ { on = 0 } on && /^  [a-z-]+:$/ { sub(/:$/, ""); print $1 }' "$root/action.yml"
}

start "action: exactly the inputs of ADR-0001 and no outputs"
[[ $(action_inputs | paste -sd' ') == "path allow-duplicates pin-form github-token" ]] \
  || report "inputs: $(action_inputs | paste -sd' ')"
! grep -q '^outputs:' "$root/action.yml" || report "action.yml has outputs"
finish

start "action: only the step releases gets the token"
[[ $(grep -c 'TOKEN: \${{ inputs.github-token }}' "$root/action.yml") == 1 ]] \
  && [[ $(grep -c 'github-token' "$root/action.yml") == 2 ]] \
  || report "the token reaches more than one step"
! grep -q 'GITHUB_PATH' "$root/action.yml" "$root"/scripts/*/*.sh || report "the action writes GITHUB_PATH"
finish

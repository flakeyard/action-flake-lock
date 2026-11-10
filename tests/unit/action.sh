# shellcheck shell=bash
# Static tests of action.yml: its interface (ADR-0001) and its steps: the
# shell library first, then the scripts, each through run-step.sh of the
# library.
# shellcheck disable=SC2016 # code of action.yml and awk, not expanded here

: "${root:?}"

# action_steps: prints the uses, the shell and the run of each step of
# action.yml, separated by the unit separator, which unlike a tab keeps empty
# fields in read, with a run folded over several lines joined.
action_steps() {
  awk '
    function flush() { if (in_step) print uses "\037" shell "\037" run }
    /^    - / { flush(); in_step = 1; uses = shell = run = key = ""; sub(/^    - /, "      ") }
    in_step && /^      [a-z-]+:/ {
      key = $1; value = $0; sub(/^      [a-z-]+: */, "", value)
      if (key == "uses:") uses = value
      if (key == "shell:") shell = value
      if (key == "run:") run = (value == ">-" ? "" : value)
      next
    }
    in_step && key == "run:" && /^        / {
      line = $0; sub(/^ +/, "", line); run = run (run == "" ? "" : " ") line
    }
    END { flush() }
  ' "$root/action.yml"
}

readonly LIB_USES_RE='^flakeyard/action-shell-lib@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$'
readonly STEP_SHELL='/usr/bin/bash --noprofile --norc -p -e -o pipefail {0}'
readonly STEP_RUN_RE='^/usr/bin/bash -p "\$SHELL_LIB/run-step\.sh" "\$GITHUB_ACTION_PATH/scripts/step" ([a-z-]+)( [A-Z_]+)*$'
# The steps of the action after the shell library, in their order.
readonly SCRIPT_STEPS='check tools parse releases report'

start "action: the shell library first, then every script through its run-step.sh, in order"
script_steps=()
while IFS=$'\037' read -r uses shell command; do
  if [[ -n $uses ]]; then
    [[ $uses =~ $LIB_USES_RE && ${#script_steps[@]} == 0 ]] || report "a step uses '$uses'"
  elif [[ $shell == "$STEP_SHELL" && $command =~ $STEP_RUN_RE ]]; then
    script_steps+=("${BASH_REMATCH[1]}")
  else
    report "a step does not use run-step.sh: shell '$shell', run '$command'"
  fi
done < <(action_steps)
[[ "${script_steps[*]}" == "$SCRIPT_STEPS" ]] || report "steps '${script_steps[*]}', expected '$SCRIPT_STEPS'"
[[ $(grep -c 'SHELL_LIB: \${{ steps.lib.outputs.path }}' "$root/action.yml") == 5 ]] \
  || report "not every script step gets SHELL_LIB from the step lib"
finish

# shell_lib_pins: the commits of the shell library that the files of this
# repository pin, each once.
shell_lib_pins() {
  grep -ohE 'flakeyard/action-shell-lib@[0-9a-f]{40}' "$root/action.yml" "$root"/.github/workflows/*.yaml | sort -u
}

start "action: one commit of the shell library in every file"
[[ $(shell_lib_pins | wc -l) == 1 ]] || report "pins: $(shell_lib_pins | paste -sd' ')"
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

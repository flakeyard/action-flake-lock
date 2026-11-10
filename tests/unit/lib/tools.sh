# shellcheck shell=bash
# Tests of scripts/lib/tools.sh; the builds are tested with step/tools.sh.
# shellcheck disable=SC2154 # work and state come from setup.

action_setup
mkdir -p "$work/store/jq/bin" "$state/tools"
printf '#!/bin/sh\n' >"$work/store/jq/bin/jq"
chmod +x "$work/store/jq/bin/jq"
printf '%s\n' "$work/store/jq" >"$state/tools/jq"
run_lib "tools: tool prints the executable" ok "scripts/lib/env.sh scripts/lib/tools.sh" tool jq
expect stdout "$work/store/jq/bin/jq"
finish

action_setup
run_lib "tools: tool fails for a tool that was not built" fail "scripts/lib/env.sh scripts/lib/tools.sh" tool gh
expect stdout ""
finish

action_setup
mkdir -p "$state/tools"
printf '%s\n' "$work/store/jq" >"$state/tools/jq"
run_lib "tools: tool fails when the executable is missing" fail "scripts/lib/env.sh scripts/lib/tools.sh" tool jq
finish

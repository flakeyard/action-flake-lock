# shellcheck shell=bash
# Tests of scripts/lib/tools.sh; the builds are tested with step/tools.sh.
# shellcheck disable=SC2154 # work comes from setup.

readonly RECORDED_TOOLS=action-flake-lock/tools

setup
mkdir -p "$work/store/jq/bin" "$work/temp/$RECORDED_TOOLS"
printf '#!/bin/sh\n' >"$work/store/jq/bin/jq"
chmod +x "$work/store/jq/bin/jq"
printf '%s\n' "$work/store/jq" >"$work/temp/$RECORDED_TOOLS/jq"
run_lib "tools: tool prints the executable" ok "env.sh tools.sh" tool jq
expect stdout "$work/store/jq/bin/jq"
finish

setup
run_lib "tools: tool fails for a tool that was not built" fail "env.sh tools.sh" tool gh
expect stdout ""
finish

setup
mkdir -p "$work/temp/$RECORDED_TOOLS"
printf '%s\n' "$work/store/jq" >"$work/temp/$RECORDED_TOOLS/jq"
run_lib "tools: tool fails when the executable is missing" fail "env.sh tools.sh" tool jq
finish

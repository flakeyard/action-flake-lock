# shellcheck shell=bash
# Tests of scripts/step/unsupported-os.sh.

setup
run "unsupported-os: names the runner" fail step/unsupported-os.sh RUNNER_OS=Windows
expect message "::error::Unsupported runner Windows: use a GitHub-hosted Linux runner"
finish

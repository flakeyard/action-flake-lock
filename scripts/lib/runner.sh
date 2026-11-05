# shellcheck shell=bash
# The runners that the action supports (ADR-0001). Sourced, not run, also by
# step/unsupported-os.sh on runners other than Linux, so it needs only the
# bash of any runner, 3.2 on macOS.

# unsupported_runner RUNNER: prints the message for the unsupported RUNNER,
# such as Windows or Linux/X86.
unsupported_runner() {
  local runner=$1
  printf '%s\n' "Unsupported runner $runner: use a GitHub-hosted Linux runner on X64 or ARM64, such as ubuntu-24.04 or ubuntu-24.04-arm."
}
